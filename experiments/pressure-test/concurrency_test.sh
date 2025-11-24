#!/bin/bash

# ========================================================
# OverlayBD 比赛测试套件 - 场景 3: 高并发启动压力测试 (V3 - Random ID)
# ========================================================

# 配置
CTR="/opt/overlaybd/snapshotter/ctr"
# 镜像列表 (OverlayBD 格式)
IMG_1="xfusion5:5000/tst-depdup:v1.0-obd"
IMG_2="xfusion5:5000/tst-depdup:v2.0-obd"
IMG_3="xfusion5:5000/tst-lazy-pull:latest_obd"
IMG_4="xfusion5:5000/test-python:latest-obd"

# 生成随机后缀，避免 "Already Exists" 错误
RUN_ID=$(date +%s)
C1="demo1_${RUN_ID}"
C2="demo2_${RUN_ID}"
C3="demo3_${RUN_ID}"
C4="demo4_${RUN_ID}"

echo "=============================================="
echo "   OverlayBD 高并发冷启动压力测试"
echo "   本次测试 ID: $RUN_ID"
echo "=============================================="

# 1. 环境清理
echo "[阶段 1] 清理环境..."
systemctl stop overlaybd-tcmu
# 尝试清理旧容器（忽略错误）
$CTR c rm -f demo1 demo2 demo3 demo4 >/dev/null 2>&1
$CTR i rm $IMG_1 $IMG_2 $IMG_3 $IMG_4 >/dev/null 2>&1
# 清理缓存
bash /root/clear_system_cache.sh >/dev/null 2>&1
rm -rf /opt/overlaybd/registry_cache/*

# 重启服务并等待内核稳定
echo "  [系统] 重启 OverlayBD 服务..."
systemctl start overlaybd-tcmu
sleep 5 # 给 TCMU 多一点时间
echo "  ✓ 服务已就绪"

# 1.5 预拉取镜像元数据 (串行)
echo "[阶段 1.5] 准备镜像元数据..."
for img in $IMG_1 $IMG_2 $IMG_3 $IMG_4; do
    echo "  正在拉取: $img"
    $CTR rpull --hosts-dir "/etc/containerd/certs.d" $img >/dev/null
    if [ $? -ne 0 ]; then
        echo "  错误: 拉取 $img 失败！"
        # 不退出，继续尝试
    fi
done
echo "  ✓ 镜像元数据准备就绪"

# 2. 并发启动
echo ""
echo "[阶段 2] 开始并发冷启动 (4个容器同时启动)..."
START_TIME=$(date +%s.%N)

# 定义启动命令 (使用 nohup 或 & 后台运行)
# 使用随机容器名
$CTR run --net-host --snapshotter=overlaybd --rm $IMG_1 $C1 sh -c "cd /testdir && ./md5check.sh all-check.txt ." < /dev/null > /root/${C1}.log 2>&1 &
PID1=$!

$CTR run --net-host --snapshotter=overlaybd --rm $IMG_2 $C2 sh -c "cd /testdir && ./md5check.sh all-check.txt ." < /dev/null > /root/${C2}.log 2>&1 &
PID2=$!

$CTR run --net-host --snapshotter=overlaybd --rm $IMG_4 $C3 python3 -c "import time; print('Python Started'); time.sleep(60)" < /dev/null > /root/${C3}.log 2>&1 &
PID3=$!

$CTR run --net-host --snapshotter=overlaybd --rm $IMG_3 $C4 sh -c "cd /testdir && ./md5check.sh random_file_1.dat-md5.txt ." < /dev/null > /root/${C4}.log 2>&1 &
PID4=$!

echo "  >>> 4个容器启动指令已发出 <<<"
echo "  容器名: $C1, $C2, $C3, $C4"

# 3. 监控与验证 (精确计时版)
echo ""
echo "[阶段 3] 监控启动状态 (等待所有容器进入 RUNNING 状态)..."

# 设置超时时间 (秒)
TIMEOUT=60
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    # 统计当前 RUNNING 的容器数量 (使用精确匹配 RUN_ID)
    RUNNING_COUNT=$($CTR tasks ls | grep "${RUN_ID}" | grep "RUNNING" | wc -l)
    
    if [ "$RUNNING_COUNT" -eq 4 ]; then
        END_TIME=$(date +%s.%N)
        echo "  ✓ 检测到所有容器 (4/4) 已启动!"
        break
    fi
    
    # 如果有容器退出了 (STOPPED/EXITED)，说明启动失败或任务太快结束了
    EXITED_COUNT=$($CTR tasks ls | grep "${RUN_ID}" | grep -E "STOPPED|EXITED" | wc -l)
    if [ "$EXITED_COUNT" -gt 0 ]; then
        echo "  ⚠️  警告: 有 $EXITED_COUNT 个容器已退出，可能启动失败或运行过快。"
        # 这里我们可以选择直接结束计时，视作"已完成启动阶段"
        END_TIME=$(date +%s.%N)
        break
    fi

    # 短暂休眠以减少轮询开销，同时保证计时精度 (100ms)
    sleep 0.1
    # 简单的计时器递增 (虽然 sleep 不准，但用于超时控制够了)
    ELAPSED=$((ELAPSED + 1))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "  ❌ 超时: 容器未能全部启动。"
    END_TIME=$(date +%s.%N)
fi

# 计算精确耗时
REAL_STARTUP_TIME=$(echo "$END_TIME - $START_TIME" | bc)

echo ""
echo "=============================================="
echo "   测试完成"
echo "=============================================="
echo "并发启动总耗时 (Time to Running): ${REAL_STARTUP_TIME}s"
echo "日志文件: /root/${C1}.log 等"

# 显示最终状态供截图
echo ""
echo "[最终容器状态]"
$CTR tasks ls | grep "${RUN_ID}"


