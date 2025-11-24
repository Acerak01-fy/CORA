#!/usr/bin/env bash
set -euo pipefail
# ok!S
IMAGE_BASE=xfusion5:5000/redis:7.2.3 
IMAGE_OBD=xfusion5:5000/redis:7.2.3_obd 
CTR_BIN=/home/wfy/DADI_OverlayBD_demo/Accelerated_Container_Image/bin/ctr 
HOSTS_DIR=/etc/containerd/certs.d 
RPULL_HTTPS_PROXY=10.26.42.239:7890 
# System-level benchmark: overlaybd remote snapshotter vs standard snapshotter
# Requires containerd + nerdctl (preferred) or ctr. You must provide image refs.
# Metrics: pull time, trivial run time (echo), first I/O time reading a file inside container.

# Config (overridable via env)
SNAP_BASELINE=${SNAP_BASELINE:-overlayfs}
SNAP_OBD=${SNAP_OBD:-overlaybd}
N_RUNS=${N_RUNS:-5}
PROBE_SIZE=${PROBE_SIZE:-10485760}  # bytes to read for first-IO (10MB)
PROBE_PATHS_DEFAULT="/usr/bin/python3 /bin/bash /lib/x86_64-linux-gnu/libc.so.6 /bin/sh /usr/bin/busybox"
PROBE_PATHS=${PROBE_PATHS:-$PROBE_PATHS_DEFAULT}
DROP_CACHES=${DROP_CACHES:-1}  # 1 to drop host caches (requires sudo)
# Network mode for container runs (to avoid CNI dependency). host|none|default
# host: --net=host (nerdctl) / --net-host (ctr); none: --net=none (nerdctl); default: no extra flag
RUN_NET_MODE=${RUN_NET_MODE:-host}
# Optional: override commands (avoid shell inside image)
# e.g. RUN_CMD="/usr/local/bin/redis-server --version"
#      IO_CMD="dd if=/usr/local/bin/redis-server of=/dev/null bs=1M count=10"
RUN_CMD=${RUN_CMD:-}
IO_CMD=${IO_CMD:-}

# Concurrency testing config
# CONCURRENCY: number of containers to start concurrently for cold start test
# HOLD_SECONDS: how long each container should stay alive (to observe memory)
CONCURRENCY=${CONCURRENCY:-1000}
HOLD_SECONDS=${HOLD_SECONDS:-30}

# Images (must be provided)
IMAGE_BASE=${IMAGE_BASE:-}
IMAGE_OBD=${IMAGE_OBD:-}

# overlaybd pull via custom ctr (user-provided)
# You can override these to match your environment.
# Example from user:
#   CTR_BIN=/home/wfy/DADI_OverlayBD_demo/Accelerated_Container_Image/bin/ctr \
#   HOSTS_DIR=/etc/containerd/certs.d \
#   RPULL_HTTPS_PROXY=10.26.42.239:7890
CTR_BIN=${CTR_BIN:-/home/wfy/DADI_OverlayBD_demo/Accelerated_Container_Image/bin/ctr}
HOSTS_DIR=${HOSTS_DIR:-/etc/containerd/certs.d}
RPULL_HTTPS_PROXY=${RPULL_HTTPS_PROXY:-}

# Tool detection
HAVE_NERDCTL=0
HAVE_CTR=0
if command -v nerdctl >/dev/null 2>&1; then HAVE_NERDCTL=1; fi
if command -v ctr      >/dev/null 2>&1; then HAVE_CTR=1; fi
if [[ $HAVE_NERDCTL -eq 0 && $HAVE_CTR -eq 0 ]]; then
  echo "[ERROR] Need nerdctl or ctr in PATH" >&2
  exit 1
fi

OUT_ROOT=$(cd "$(dirname "$0")" && pwd)/out
STAMP=$(date +%Y%m%d-%H%M%S)
OUT_DIR="$OUT_ROOT/$STAMP"
mkdir -p "$OUT_DIR"
RESULT_CSV="$OUT_DIR/sys_results.csv"
echo "mode,snapshotter,image,pull_ms,run_echo_ms,first_io_ms,bytes_rx,bytes_tx,notes" > "$RESULT_CSV"

# Extra result files for extended tests
COLD_FULL_CSV="$OUT_DIR/cold_full.csv"
echo "mode,snapshotter,image,cold_full_ms,pull_ms,run_ms,bytes_rx,bytes_tx,notes" > "$COLD_FULL_CSV"
CONCUR_CSV="$OUT_DIR/concurrent_results.csv"
echo "mode,snapshotter,image,concurrency,avg_start_ms,min_start_ms,max_start_ms,mem_increase_bytes,per_container_bytes,notes" > "$CONCUR_CSV"
HOT_CSV="$OUT_DIR/hot_results.csv"
echo "mode,snapshotter,image,run_ms,notes" > "$HOT_CSV"

echo "# Output dir: $OUT_DIR" >&2

require_images() {
  if [[ -z "${IMAGE_BASE}" || -z "${IMAGE_OBD}" ]]; then
    cat >&2 <<EOF
[ERROR] Please set IMAGE_BASE and IMAGE_OBD, e.g.:
  IMAGE_BASE=docker.io/acerak01/overlaybd-image:redis-8.2.1 \
  IMAGE_OBD=docker.io/acerak01/overlaybd-image:latest_obd_new \
  CTR_BIN=/home/wfy/DADI_OverlayBD_demo/Accelerated_Container_Image/bin/ctr \
  HOSTS_DIR=/etc/containerd/certs.d \
  RPULL_HTTPS_PROXY=10.26.42.239:7890 \
  bash experiments/sys_bench_overlaybd.sh
EOF
    exit 1
  fi
}

# Return total RX and TX bytes across all interfaces from /proc/net/dev
net_bytes_total() {
  awk 'NR>2{rx+=$2; tx+=$10} END{printf "%ld %ld\n", rx, tx}' /proc/net/dev
}

# Drop host page cache if DROP_CACHES==1 (sudo required)
drop_caches() {
  if [[ "$DROP_CACHES" == "1" ]]; then
    echo "[INFO] Dropping host caches (sudo required)" >&2
    sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches' || true
  fi
}

# Temporarily override DROP_CACHES within a scope
push_drop_caches() {
  __DC_SAVED=${DROP_CACHES:-0}
  DROP_CACHES="$1"
}
pop_drop_caches() {
  DROP_CACHES=${__DC_SAVED:-0}
  unset __DC_SAVED
}

# Return host memory used bytes (MemTotal - MemAvailable)
mem_used_bytes() {
  awk '/MemTotal:/{t=$2} /MemAvailable:/{a=$2} END{printf "%ld\n", (t-a)*1024}' /proc/meminfo
}

# Pull the image using the selected snapshotter
# - overlaybd: use user-provided ctr rpull with optional proxy and hosts-dir
# - baseline: use nerdctl/ctr standard pull
pull_with() {
  local snap="$1"; shift
  local image="$1"; shift
  local start end dur notes=""

  # Remove existing image to force download
  if [[ "$snap" == "overlaybd" ]]; then
    # Use user-specified ctr rpull flow for overlaybd images
    if [[ -x "$CTR_BIN" ]]; then
      "$CTR_BIN" i rm "$image" >/dev/null 2>&1 || true
    else
      echo "[WARN] CTR_BIN not executable at $CTR_BIN; trying 'ctr' in PATH" >&2
      if command -v ctr >/dev/null 2>&1; then ctr images rm "$image" >/dev/null 2>&1 || true; fi
    fi
    # Optional: prune nerdctl images to ensure clean state (best-effort)
    if command -v nerdctl >/dev/null 2>&1; then
      nerdctl image prune --force --all >/dev/null 2>&1 || true
    fi
  else
    if [[ $HAVE_NERDCTL -eq 1 ]]; then
      nerdctl --snapshotter "$snap" image rm -f "$image" >/dev/null 2>&1 || true
    else
      ctr images rm "$image" >/dev/null 2>&1 || true
    fi
  fi

  drop_caches
  local rx0 tx0 rx1 tx1
  read -r rx0 tx0 < <(net_bytes_total)
  start=$(date +%s%N)
  if [[ "$snap" == "overlaybd" ]]; then
    # Perform pull using "ctr rpull --hosts-dir" with optional https_proxy
    if [[ -x "$CTR_BIN" ]]; then
      if [[ -n "$RPULL_HTTPS_PROXY" ]]; then
        if ! https_proxy="$RPULL_HTTPS_PROXY" "$CTR_BIN" rpull --hosts-dir "$HOSTS_DIR" "$image" 1>/dev/null; then
          notes="pull_failed"; dur=-1; rx1=$rx0; tx1=$tx0; echo "$dur $rx1 $tx1 $notes"; return
        fi
      else
        if ! "$CTR_BIN" rpull --hosts-dir "$HOSTS_DIR" "$image" 1>/dev/null; then
          notes="pull_failed"; dur=-1; rx1=$rx0; tx1=$tx0; echo "$dur $rx1 $tx1 $notes"; return
        fi
      fi
    else
      # Fallback to standard ctr pull if custom ctr not available
      if ! ctr images pull --snapshotter "$snap" "$image" 1>/dev/null; then
        notes="pull_failed"; dur=-1; rx1=$rx0; tx1=$tx0; echo "$dur $rx1 $tx1 $notes"; return
      fi
    fi
  else
    if [[ $HAVE_NERDCTL -eq 1 ]]; then
      if ! nerdctl --snapshotter "$snap" image pull "$image" 1>/dev/null; then
        notes="pull_failed"; dur=-1; rx1=$rx0; tx1=$tx0; echo "$dur $rx1 $tx1 $notes"; return
      fi
    else
      if ! ctr images pull --snapshotter "$snap" "$image" 1>/dev/null; then
        notes="pull_failed"; dur=-1; rx1=$rx0; tx1=$tx0; echo "$dur $rx1 $tx1 $notes"; return
      fi
    fi
  fi
  end=$(date +%s%N)
  read -r rx1 tx1 < <(net_bytes_total)
  dur=$(( (end-start)/1000000 ))
  echo "$dur $rx1 $tx1 $notes"
}

# Run a trivial command inside container to measure container startup overhead
# - Uses RUN_CMD if provided; otherwise runs 'echo ready'
run_echo_with() {
  local snap="$1"; shift
  local image="$1"; shift
  local start end dur notes=""
  drop_caches
  start=$(date +%s%N)
  if [[ $HAVE_NERDCTL -eq 1 ]]; then
    local net_args=""
    case "$RUN_NET_MODE" in
      host) net_args="--net=host";;
      none) net_args="--net=none";;
      *)    net_args="";;
    esac
    if [[ -n "$RUN_CMD" ]]; then
      read -r -a __rcmd <<< "$RUN_CMD"
      nerdctl --snapshotter "$snap" run $net_args --rm "$image" "${__rcmd[@]}" >/dev/null 2>&1 || notes="run_failed"
    else
      nerdctl --snapshotter "$snap" run $net_args --rm "$image" sh -c 'echo ready' >/dev/null 2>&1 || notes="run_failed"
    fi
  else
    local net_args=""
    case "$RUN_NET_MODE" in
      host) net_args="--net-host";;
      none) net_args="";; # ctr lacks a simple "none" without CNI; use default if requested
      *)    net_args="";;
    esac
    if [[ -n "$RUN_CMD" ]]; then
      read -r -a __rcmd <<< "$RUN_CMD"
      ctr run --rm --snapshotter "$snap" $net_args "$image" test-echo "${__rcmd[@]}" >/dev/null 2>&1 || notes="run_failed"
    else
      ctr run --rm --snapshotter "$snap" $net_args "$image" test-echo sh -c 'echo ready' >/dev/null 2>&1 || notes="run_failed"
    fi
  fi
  end=$(date +%s%N)
  dur=$(( (end-start)/1000000 ))
  echo "$dur $notes"
}

# Measure first-read latency by reading PROBE_SIZE bytes from first available path in PROBE_PATHS
run_first_io_with() {
  local snap="$1"; shift
  local image="$1"; shift
  local start end dur notes=""
  local ps="$PROBE_SIZE"
  local paths=( $PROBE_PATHS )
  local probe_script='set -e; for p in '"${paths[*]}"'; do if [ -r "$p" ]; then echo "Using $p" 1>&2; if command -v dd >/dev/null 2>&1; then dd if="$p" of=/dev/null bs=1M count=$((ps/1048576)) status=none || head -c '"$ps"' "$p" >/dev/null; else head -c '"$ps"' "$p" >/dev/null; fi; exit 0; fi; done; echo "No probe file found" 1>&2; exit 0'
  drop_caches
  start=$(date +%s%N)
  if [[ $HAVE_NERDCTL -eq 1 ]]; then
    local net_args=""
    case "$RUN_NET_MODE" in
      host) net_args="--net=host";;
      none) net_args="--net=none";;
      *)    net_args="";;
    esac
    if [[ -n "$IO_CMD" ]]; then
      read -r -a __icmd <<< "$IO_CMD"
      nerdctl --snapshotter "$snap" run $net_args --rm "$image" "${__icmd[@]}" >/dev/null 2>&1 || notes="io_failed"
    else
      nerdctl --snapshotter "$snap" run $net_args --rm "$image" sh -c "$probe_script" >/dev/null 2>&1 || notes="io_failed"
    fi
  else
    local net_args=""
    case "$RUN_NET_MODE" in
      host) net_args="--net-host";;
      none) net_args="";;
      *)    net_args="";;
    esac
    if [[ -n "$IO_CMD" ]]; then
      read -r -a __icmd <<< "$IO_CMD"
      ctr run --rm --snapshotter "$snap" $net_args "$image" test-io "${__icmd[@]}" >/dev/null 2>&1 || notes="io_failed"
    else
      ctr run --rm --snapshotter "$snap" $net_args "$image" test-io sh -c "$probe_script" >/dev/null 2>&1 || notes="io_failed"
    fi
  fi
  end=$(date +%s%N)
  dur=$(( (end-start)/1000000 ))
  echo "$dur $notes"
}

# Measure "single full cold start" time as pull_ms + run_ms
# Steps:
#  1) Forcefully remove image (already done in pull_with)
#  2) Drop caches
#  3) Pull image (timed)
#  4) Immediately run trivial command (timed)
# Output to $COLD_FULL_CSV
bench_single_cold_full() {
  local mode="$1"; shift
  local snap="$1"; shift
  local image="$1"; shift
  echo "[INFO] ($mode) Single full cold start for $image" >&2
  push_drop_caches 1
  read -r pull_ms rx1 tx1 notes1 < <(pull_with "$snap" "$image")
  read -r run_ms notes2 < <(run_echo_with "$snap" "$image")
  pop_drop_caches
  local notes="${notes1}${notes2:+,$notes2}"
  local total_ms=-1
  if [[ $pull_ms -ge 0 && $run_ms -ge 0 ]]; then
    total_ms=$((pull_ms + run_ms))
  fi
  echo "$mode,$snap,$image,$total_ms,$pull_ms,$run_ms,$rx1,$tx1,$notes" | tee -a "$COLD_FULL_CSV" >/dev/null
}

# Launch many containers concurrently and measure average "start latency"
# - Prefer nerdctl (supports -d). Attempts ctr --detach if available.
# - Each container runs 'sleep HOLD_SECONDS' to keep it alive for memory observation.
# - We measure per-launch CLI return time as start latency proxy.
# - Outputs to $CONCUR_CSV: average/min/max start ms and memory increase.
bench_concurrent_cold() {
  local mode="$1"; shift
  local snap="$1"; shift
  local image="$1"; shift
  local N=${CONCURRENCY}
  echo "[INFO] ($mode) Concurrent cold start: N=$N image=$image" >&2

  # Ensure image is present to isolate start latency (not distribution)
  # Use a warm pull (no delete) to avoid re-download for each container
  if [[ $HAVE_NERDCTL -eq 1 ]]; then
    nerdctl --snapshotter "$snap" image inspect "$image" >/dev/null 2>&1 || nerdctl --snapshotter "$snap" image pull "$image" >/dev/null
  else
    ctr images list | grep -q "\b$image\b" || ctr images pull --snapshotter "$snap" "$image" >/dev/null
  fi

  # Compose network args
  local net_args=""
  if [[ $HAVE_NERDCTL -eq 1 ]]; then
    case "$RUN_NET_MODE" in
      host) net_args="--net=host";;
      none) net_args="--net=none";;
      *)    net_args="";;
    esac
  else
    case "$RUN_NET_MODE" in
      host) net_args="--net-host";;
      *)    net_args="";;
    esac
  fi

  # Prepare temp dir for timings
  local tdir
  tdir=$(mktemp -d)
  local mem_before mem_after
  mem_before=$(mem_used_bytes)

  # Spawn N containers
  echo "[INFO] Spawning $N containers (hold ${HOLD_SECONDS}s)" >&2
  local i
  for i in $(seq 1 "$N"); do
    (
      local t0 t1 dur
      t0=$(date +%s%N)
      if [[ $HAVE_NERDCTL -eq 1 ]]; then
        # nerdctl detached run
        nerdctl --snapshotter "$snap" run $net_args -d --rm "$image" sh -c "sleep $HOLD_SECONDS" >/dev/null 2>&1 || true
      else
        # Attempt ctr detach if supported; else run in background (best-effort)
        if ctr run --help 2>/dev/null | grep -q "--detach"; then
          ctr run --rm --detach --snapshotter "$snap" $net_args "$image" "c$i" sh -c "sleep $HOLD_SECONDS" >/dev/null 2>&1 || true
        else
          ctr run --rm --snapshotter "$snap" $net_args "$image" "c$i" sh -c "sleep $HOLD_SECONDS" >/dev/null 2>&1 &
          disown || true
        fi
      fi
      t1=$(date +%s%N)
      dur=$(( (t1 - t0)/1000000 ))
      echo "$dur" > "$tdir/$i.ms"
    ) &
  done
  wait

  # Allow processes to settle, then sample memory
  sleep 3
  mem_after=$(mem_used_bytes)

  # Aggregate timings
  local sum=0 min=999999999 max=0 count=0 v
  for vfile in "$tdir"/*.ms; do
    read -r v < "$vfile" || v=0
    sum=$((sum + v))
    (( v < min )) && min=$v
    (( v > max )) && max=$v
    count=$((count + 1))
  done
  local avg=0
  if [[ $count -gt 0 ]]; then avg=$((sum / count)); fi
  local mem_inc=$((mem_after - mem_before))
  local per_ct=0
  if [[ $N -gt 0 ]]; then per_ct=$(( mem_inc / N )); fi

  echo "$mode,$snap,$image,$N,$avg,$min,$max,$mem_inc,$per_ct," | tee -a "$CONCUR_CSV" >/dev/null
  rm -rf "$tdir"
}

# Measure hot start run time (no cache drops), image must be present already
bench_hot_start() {
  local mode="$1"; shift
  local snap="$1"; shift
  local image="$1"; shift
  echo "[INFO] ($mode) Hot start runs for $image (N=$N_RUNS)" >&2

  # Ensure image present
  if [[ $HAVE_NERDCTL -eq 1 ]]; then
    nerdctl --snapshotter "$snap" image inspect "$image" >/dev/null 2>&1 || nerdctl --snapshotter "$snap" image pull "$image" >/dev/null
  else
    ctr images list | grep -q "\b$image\b" || ctr images pull --snapshotter "$snap" "$image" >/dev/null
  fi

  push_drop_caches 0
  local i
  for i in $(seq 1 "$N_RUNS"); do
    read -r run_ms notes < <(run_echo_with "$snap" "$image")
    echo "$mode,$snap,$image,$run_ms,$notes" | tee -a "$HOT_CSV" >/dev/null
  done
  pop_drop_caches
}

bench_mode() {
  local mode="$1"; shift
  local snap="$1"; shift
  local image="$1"; shift
  for i in $(seq 1 "$N_RUNS"); do
    echo "[INFO] ($mode) Pull $image [run $i/$N_RUNS]" >&2
    read -r pull_ms rx1 tx1 notes < <(pull_with "$snap" "$image") #buging
    echo "[INFO] ($mode) Run echo" >&2
    read -r echo_ms notes2 < <(run_echo_with "$snap" "$image")
    echo "[INFO] ($mode) First IO" >&2
    read -r io_ms notes3 < <(run_first_io_with "$snap" "$image")
    local combined_notes="${notes}${notes2:+,$notes2}${notes3:+,$notes3}"
    echo "$mode,$snap,$image,$pull_ms,$echo_ms,$io_ms,$((rx1)),$((tx1)),$combined_notes" | tee -a "$RESULT_CSV" >/dev/null
  done
}

main() {
  require_images
  #bench_mode baseline "$SNAP_BASELINE" "$IMAGE_BASE"
  #bench_mode overlaybd "$SNAP_OBD" "$IMAGE_OBD"

  # Single full cold start (pull + run)
  bench_single_cold_full baseline "$SNAP_BASELINE" "$IMAGE_BASE"
  bench_single_cold_full overlaybd "$SNAP_OBD" "$IMAGE_OBD"

  # Concurrent cold start (N containers launching concurrently)
  #bench_concurrent_cold baseline "$SNAP_BASELINE" "$IMAGE_BASE"
  #bench_concurrent_cold overlaybd "$SNAP_OBD" "$IMAGE_OBD"
  # Hot start comparison (no cache drop)
  #bench_hot_start baseline "$SNAP_BASELINE" "$IMAGE_BASE"
  #bench_hot_start overlaybd "$SNAP_OBD" "$IMAGE_OBD"

  ln -sfn "$OUT_DIR" "$OUT_ROOT/latest"
  echo "Done. Results: $RESULT_CSV" >&2
}

main "$@"
