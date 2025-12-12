#!/bin/bash


# ==================== 冷启动计时器 ====================
echo "======================================"
echo "  CORA 按需加载冷启动性能测试"
echo "======================================"
echo ""

# 记录总开始时间
TOTAL_START=$(date +%s.%N)

# ==================== 环境准备阶段 ====================
echo "[阶段 1] 停止服务并清理环境..."
PREP_START=$(date +%s.%N)

systemctl stop overlaybd-tcmu
#killall overlaybd-snapshotter
rm /var/log/overlaybd.log 2>/dev/null
rm nohup.out 2>/dev/null
sleep 1

# === 彻底清理 OverlayBD 缓存 ===
rm -rf /opt/overlaybd/registry_cache/*
# 如果有 snapshotter 数据目录，也建议清理 (请根据实际挂载点调整)
# rm -rf /var/lib/containerd/io.containerd.snapshotter.v1.overlaybd/*
# =============================

systemctl start overlaybd-tcmu
nohup proxychains /opt/overlaybd/snapshotter/ctr &
sleep 1

PREP_END=$(date +%s.%N)
PREP_TIME=$(echo "$PREP_END - $PREP_START" | bc)
echo "  ✓ 环境准备完成: ${PREP_TIME}s"
echo ""

# ==================== 清理阶段 ====================
echo "[阶段 2] 清理镜像和缓存..."
CLEAN_START=$(date +%s.%N)

CTR="/opt/overlaybd/snapshotter/ctr"
#IMAGE="docker.io/overlaybd/redis:7.2.3_obd"
IMAGE="xfusion5:5000/redis:7.2.3_obd-new"
#IMAGE="xfusion5:5000/tst-lazy-pull:latest_obd"
#IMAGE="xfusion5:5000/tst-lazy-pull:latest_wfy_obd"
#IMAGE="xfusion5:5000/wordpress:5.6.2_obd"
#IMAGE="xfusion5:5000/tst-lazy-pull:latest"
#IMAGE="xfusion5:5000/tst-lazy-pull:latest_fastcdc_xf5"
#IMAGE="xfusion5:5000/tst-lazy-pull:obd-push"
#IMAGE="xfusion5:5000/tst-lazy-pull:latest_wfy_obdpush"
$CTR i rm $IMAGE 2>/dev/null
nerdctl image prune --force --all 2>/dev/null
rm -rf /opt/overlaybd/registry_cache/*

CLEAN_END=$(date +%s.%N)
CLEAN_TIME=$(echo "$CLEAN_END - $CLEAN_START" | bc)
echo "  ✓ 清理完成: ${CLEAN_TIME}s"
echo " 清理系统缓存 "
bash /root/clear_system_cache.sh

# ==================== 镜像拉取阶段 ====================
echo "[阶段 3] 拉取镜像元数据..."
PULL_START=$(date +%s.%N)

#https_proxy=10.26.42.239:7890 
no_proxy="10.26.42.226,xfusion5" $CTR rpull --download-blobs=false --hosts-dir "/etc/containerd/certs.d" $IMAGE
#https_proxy=10.26.42.239:7890 http_proxy=10.26.42.239:7890 $CTR rpull --hosts-dir "/etc/containerd/certs.d" $IMAGE

PULL_END=$(date +%s.%N)
PULL_TIME=$(echo "$PULL_END - $PULL_START" | bc)
echo "  ✓ 镜像拉取完成: ${PULL_TIME}s"
echo ""

# ==================== 容器启动阶段 ====================
echo "[阶段 4] 启动容器 (覆盖默认命令)..."
RUN_START=$(date +%s.%N)

# --- 开始抓包 ---
PCAP_FILE="/tmp/cold_start_run.pcap"
rm -f $PCAP_FILE
# -i any: 监听所有接口
# host xfusion5: 过滤目标 Registry 的流量
# -w: 写入文件
echo "  Starting tcpdump capture to $PCAP_FILE..."
tcpdump -i any host xfusion5 -w $PCAP_FILE > /dev/null 2>&1 &
TCPDUMP_PID=$!
sleep 1 # 等待 tcpdump 启动
# ----------------

$CTR run --net-host --snapshotter=overlaybd --rm -t $IMAGE demo
# 注意：必须在 IMAGE 后指定容器ID (demo)，然后才是命令
# 示例 1: 极简测试（最快）
#$CTR run --net-host --snapshotter=overlaybd --rm -t $IMAGE demo /bin/sh -c "echo 'OverlayBD Lazy Pulling Works!'"

# 示例 2: 查看系统版本
#$CTR run --net-host --snapshotter=overlaybd --rm $IMAGE demo sh -c "cd /testdir && ./md5check.sh random_file_300M_1.dat-md5.txt ."
#$CTR run --net-host --snapshotter=overlaybd --rm $IMAGE wordpress
# 示例 3: 查看目录结构 (会触发目录内文件的元数据读取)
# $CTR run --net-host --snapshotter=overlaybd --rm -t $IMAGE demo ls -R /app

# 示例 4: 如果是 Redis 镜像，查看版本
# $CTR run --net-host --snapshotter=overlaybd --rm -t $IMAGE demo redis-server --version

RUN_END=$(date +%s.%N)
RUN_TIME=$(echo "$RUN_END - $RUN_START" | bc)

# --- 停止抓包 ---
kill $TCPDUMP_PID 2>/dev/null
wait $TCPDUMP_PID 2>/dev/null
echo "  Capture stopped."
# 统计 pcap 文件大小 (近似流量)
TRAFFIC_SIZE=$(du -h $PCAP_FILE | cut -f1)
TRAFFIC_BYTES=$(stat -c%s $PCAP_FILE)
echo "  [流量统计] 冷启动阶段网络流量 (PCAP文件大小): $TRAFFIC_SIZE ($TRAFFIC_BYTES bytes)"
# ----------------

# ==================== 总结报告 ====================
TOTAL_END=$(date +%s.%N)
TOTAL_TIME=$(echo "$TOTAL_END - $TOTAL_START" | bc)

echo ""
echo "======================================"
echo "  性能测试报告"
echo "======================================"
echo "环境准备:     ${PREP_TIME}s"
echo "清理缓存:     ${CLEAN_TIME}s"
echo "拉取镜像:     ${PULL_TIME}s"
echo "容器启动:     ${RUN_TIME}s"
echo "--------------------------------------"
echo "总耗时:       ${TOTAL_TIME}s"
echo "======================================"
echo ""
echo "关键指标 (冷启动速度):"
echo "  镜像拉取 + 容器启动 = $(echo "$PULL_TIME + $RUN_TIME" | bc)s"
echo ""


