import csv
import sys
import os

# 尝试导入 matplotlib，如果失败则优雅退出
try:
    import matplotlib.pyplot as plt
except ImportError:
    print("错误: 未检测到 matplotlib 库。")
    print("请在安装了 matplotlib 的环境中运行此脚本 (pip install matplotlib)。")
    print("你可以将整个 competition_results 文件夹下载到本地电脑运行。")
    sys.exit(1)

def read_csv_data(filepath):
    timestamps = []
    cpu_usage = []
    mem_usage = []
    try:
        with open(filepath, 'r') as f:
            reader = csv.reader(f)
            header = next(reader) # Skip header
            start_time = None
            for row in reader:
                if not row or len(row) < 3: continue
                # Timestamp format might be MM:SS, we convert to relative seconds
                ts_str = row[0]
                try:
                    parts = ts_str.split(':')
                    seconds = int(parts[0]) * 60 + int(parts[1])
                    if start_time is None:
                        start_time = seconds
                    timestamps.append(seconds - start_time)
                    cpu_usage.append(float(row[1]))
                    mem_usage.append(float(row[2]))
                except:
                    continue
    except FileNotFoundError:
        print(f"Warning: File {filepath} not found.")
        return [], [], []
    return timestamps, cpu_usage, mem_usage

def read_time_results(filepath):
    times = {}
    try:
        with open(filepath, 'r') as f:
            reader = csv.reader(f)
            next(reader) # Skip header
            for row in reader:
                if row:
                    times[row[0]] = float(row[1])
    except FileNotFoundError:
        print(f"Warning: File {filepath} not found.")
    return times

# 1. 绘制冷启动时间对比柱状图
time_data = read_time_results('time_results.csv')
if time_data:
    plt.figure(figsize=(8, 6))
    bars = plt.bar(time_data.keys(), time_data.values(), color=['#3498db', '#2ecc71'])
    plt.title('Cold Start Time Comparison (Lower is Better)')
    plt.ylabel('Time (seconds)')
    
    # Add value labels
    for bar in bars:
        height = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2., height,
                f'{height:.2f}s',
                ha='center', va='bottom')
    
    plt.savefig('cold_start_comparison.png')
    print("Generated cold_start_comparison.png")

# 2. 绘制资源开销对比图 (折线图)
t_norm, cpu_norm, mem_norm = read_csv_data('normal_run_usage_summary.csv')
t_lazy, cpu_lazy, mem_lazy = read_csv_data('lazy_run_usage_summary.csv')

if t_norm and t_lazy:
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 10))
    
    # CPU Plot
    ax1.plot(t_norm, cpu_norm, label='Normal (Standard OCI)', color='#3498db')
    ax1.plot(t_lazy, cpu_lazy, label='Lazy (OverlayBD)', color='#2ecc71')
    ax1.set_title('CPU Usage Comparison')
    ax1.set_ylabel('CPU %')
    ax1.set_xlabel('Time (s)')
    ax1.legend()
    ax1.grid(True, alpha=0.3)
    
    # Memory Plot
    ax2.plot(t_norm, mem_norm, label='Normal (Standard OCI)', color='#3498db')
    ax2.plot(t_lazy, mem_lazy, label='Lazy (OverlayBD)', color='#2ecc71')
    ax2.set_title('Memory Usage Comparison')
    ax2.set_ylabel('Memory (MB)')
    ax2.set_xlabel('Time (s)')
    ax2.legend()
    ax2.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('resource_usage_comparison.png')
    print("Generated resource_usage_comparison.png")
else:
    print("Insufficient data for resource plotting.")

