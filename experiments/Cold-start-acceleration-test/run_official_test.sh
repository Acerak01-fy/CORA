#!/bin/bash

# ========================================================
# OverlayBD 比赛测试套件 V2.0
# 功能：自动拆分测试场景，独立采集数据，生成对比报告
# ========================================================

# 配置
MONITOR_SCRIPT="/root/Test-Guide/monitor_resource.sh"
INTERVAL=0.5
OUTPUT_DIR="/root/competition_results"

# 创建输出目录
mkdir -p $OUTPUT_DIR
# rm -f $OUTPUT_DIR/* # 保留旧文件以防万一，覆盖即可

echo "=============================================="
echo "   OverlayBD 性能对比测试 (Auto-Split Mode)"
echo "=============================================="

# 1. 自动拆分 ctr.sh 为两个独立脚本
echo "[系统] 正在拆分测试脚本..."
# 提取前半部分 (普通镜像)
sed -n '1,93p' /root/ctr.sh > $OUTPUT_DIR/ctr_normal.sh
# 提取后半部分 (按需镜像)，并补上 shebang
echo "#!/bin/bash" > $OUTPUT_DIR/ctr_lazy.sh
sed -n '94,$p' /root/ctr.sh >> $OUTPUT_DIR/ctr_lazy.sh

chmod +x $OUTPUT_DIR/ctr_normal.sh
chmod +x $OUTPUT_DIR/ctr_lazy.sh
echo "  ✓ 拆分完成: ctr_normal.sh, ctr_lazy.sh"

# 函数：执行测试并监控
run_test_stage() {
    local stage_name=$1
    local script_path=$2
    local output_prefix=$3
    
    echo ""
    echo "----------------------------------------------"
    echo "[阶段] 开始测试: $stage_name"
    echo "----------------------------------------------"
    
    # 尝试定位 OverlayBD 进程 (如果存在)
    local target_pid=$(pgrep -f "/opt/overlaybd/snapshotter/overlaybd-snapshotter" | head -n 1)
    
    local monitor_pid=""
    if [ ! -z "$target_pid" ]; then
        echo "  [监控] 目标 PID: $target_pid"
        # 启动监控
        nohup $MONITOR_SCRIPT $target_pid 600 $INTERVAL $OUTPUT_DIR/${output_prefix} > /dev/null 2>&1 &
        monitor_pid=$!
    else
        echo "  [警告] 未找到 overlaybd 进程，跳过资源监控 (可能是第一次启动前)"
    fi
    
    # 执行测试脚本并记录输出
    bash $script_path > $OUTPUT_DIR/${output_prefix}.log 2>&1
    # 同时显示在屏幕上
    cat $OUTPUT_DIR/${output_prefix}.log
    
    # 停止监控
    if [ ! -z "$monitor_pid" ]; then
        kill $monitor_pid 2>/dev/null
        pkill -P $monitor_pid 2>/dev/null
        echo "  [监控] 已停止"
    fi
}
# 2. 运行按需镜像测试
run_test_stage "按需镜像 (OverlayBD Lazy)" "$OUTPUT_DIR/ctr_lazy.sh" "lazy_run"

# 3. 运行普通镜像测试
run_test_stage "普通镜像 (OCI Standard)" "$OUTPUT_DIR/ctr_normal.sh" "normal_run"



# 4. 提取关键指标
echo ""
echo "=============================================="
echo "   测试结果汇总"
echo "=============================================="

# 从日志中提取时间
# 查找格式: "镜像拉取 + 容器启动 = 12.34s"
get_time() {
    grep "镜像拉取 + 容器启动 =" $OUTPUT_DIR/$1.log | tail -n 1 | awk -F'= ' '{print $2}' | sed 's/s//'
}

TIME_NORMAL=$(get_time "normal_run")
TIME_LAZY=$(get_time "lazy_run")

# 保存结果到文本文件供 Python 读取
echo "Mode,TotalTime" > $OUTPUT_DIR/time_results.csv
echo "Normal,$TIME_NORMAL" >> $OUTPUT_DIR/time_results.csv
echo "Lazy,$TIME_LAZY" >> $OUTPUT_DIR/time_results.csv

echo "冷启动耗时对比:"
echo "  普通镜像: ${TIME_NORMAL}s"
echo "  按需镜像: ${TIME_LAZY}s"

if [[ $(echo "$TIME_LAZY < $TIME_NORMAL" | bc) -eq 1 ]]; then
    SPEEDUP=$(echo "scale=2; $TIME_NORMAL / $TIME_LAZY" | bc)
    echo "  >>> 提升倍数: ${SPEEDUP}x <<<"
else
    echo "  (注意: 按需加载似乎没有变快，请检查网络或缓存)"
fi

echo ""
echo "数据文件已生成至 $OUTPUT_DIR:"
ls -1 $OUTPUT_DIR/*.csv

echo ""
echo "=============================================="
echo "   生成图表"
echo "=============================================="
echo "正在尝试运行绘图脚本..."
cd $OUTPUT_DIR
python3 generate_charts.py

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ 无法在服务器上直接生成图表 (缺少 matplotlib)。"
    echo "✅ 请将整个 '$OUTPUT_DIR' 文件夹下载到你的本地电脑，"
    echo "   然后在本地运行: python3 generate_charts.py"
else
    echo "✅ 图表生成成功！请查看 $OUTPUT_DIR 下的 .png 文件。"
fi
