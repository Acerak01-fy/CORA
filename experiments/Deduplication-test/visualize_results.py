#!/usr/bin/env python3
"""
FastCDC 基准测试结果可视化工具
生成图表帮助分析性能数据
"""

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns
from pathlib import Path

# 设置中文字体支持
plt.rcParams['font.sans-serif'] = ['DejaVu Sans', 'Arial Unicode MS', 'SimHei']
plt.rcParams['axes.unicode_minus'] = False

# 数据文件路径
DATA_DIR = Path('/home/wfy/DADI_OverlayBD_demo/experiments/fastcdc_benchmark')
SUMMARY_FILE = DATA_DIR / 'benchmark_summary.csv'
DETAIL_FILE = DATA_DIR / 'benchmark_results.csv'
OUTPUT_DIR = DATA_DIR / 'charts'

# 创建输出目录
OUTPUT_DIR.mkdir(exist_ok=True)

def load_data():
    """加载测试数据"""
    summary = pd.read_csv(SUMMARY_FILE)
    detail = pd.read_csv(DETAIL_FILE)
    return summary, detail

def plot_compression_ratio_comparison(summary):
    """压缩率对比图"""
    # 只选择FastCDC的数据
    fastcdc = summary[summary['Method'] == 'FastCDC'].copy()
    fastcdc['FileSizeMB'] = fastcdc['FileSizeKB'] / 1024
    
    fig, ax = plt.subplots(figsize=(12, 6))
    
    # 按数据类型分组
    for dtype in ['random', 'pattern', 'mixed']:
        data = fastcdc[fastcdc['DataType'] == dtype]
        ax.plot(data['FileSizeMB'], data['AvgCompressionRatio'], 
                marker='o', linewidth=2, markersize=8, label=dtype.capitalize())
    
    ax.set_xlabel('File Size (MB)', fontsize=12)
    ax.set_ylabel('Compression Ratio (%)', fontsize=12)
    ax.set_title('FastCDC Compression Ratio by File Size and Data Type', fontsize=14, fontweight='bold')
    ax.legend(title='Data Type', fontsize=10)
    ax.grid(True, alpha=0.3)
    ax.set_xscale('log')
    
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'compression_ratio.png', dpi=300, bbox_inches='tight')
    print(f"  已生成: {OUTPUT_DIR / 'compression_ratio.png'}")
    plt.close()

def plot_space_saving(summary):
    """空间节省对比图"""
    fastcdc = summary[summary['Method'] == 'FastCDC'].copy()
    fastcdc = fastcdc[fastcdc['SpaceSaving%'] != '-']
    fastcdc['SpaceSaving%'] = pd.to_numeric(fastcdc['SpaceSaving%'])
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    # 按文件大小和数据类型分组
    data_pivot = fastcdc.pivot(index='FileSizeKB', columns='DataType', values='SpaceSaving%')
    
    x = np.arange(len(data_pivot.index))
    width = 0.25
    
    colors = {'random': '#ff6b6b', 'pattern': '#4ecdc4', 'mixed': '#45b7d1'}
    for i, dtype in enumerate(['random', 'pattern', 'mixed']):
        if dtype in data_pivot.columns:
            ax.bar(x + i*width, data_pivot[dtype], width, 
                   label=dtype.capitalize(), color=colors[dtype], alpha=0.8)
    
    ax.set_xlabel('File Size', fontsize=12)
    ax.set_ylabel('Space Saving (%)', fontsize=12)
    ax.set_title('FastCDC Space Saving vs Fixed Chunking', fontsize=14, fontweight='bold')
    ax.set_xticks(x + width)
    ax.set_xticklabels(['100KB', '1MB', '10MB'])
    ax.legend(title='Data Type')
    ax.grid(True, alpha=0.3, axis='y')
    
    # 添加数值标签
    for container in ax.containers:
        ax.bar_label(container, fmt='%.1f%%', padding=3)
    
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'space_saving.png', dpi=300, bbox_inches='tight')
    print(f"  已生成: {OUTPUT_DIR / 'space_saving.png'}")
    plt.close()

def plot_decompression_speedup(summary):
    """解压速度提升对比图"""
    fastcdc = summary[summary['Method'] == 'FastCDC'].copy()
    fastcdc = fastcdc[fastcdc['SpeedupDecompress'] != '-']
    fastcdc['SpeedupDecompress'] = pd.to_numeric(fastcdc['SpeedupDecompress'])
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    data_pivot = fastcdc.pivot(index='FileSizeKB', columns='DataType', values='SpeedupDecompress')
    
    x = np.arange(len(data_pivot.index))
    width = 0.25
    
    colors = {'random': '#ff6b6b', 'pattern': '#4ecdc4', 'mixed': '#45b7d1'}
    for i, dtype in enumerate(['random', 'pattern', 'mixed']):
        if dtype in data_pivot.columns:
            ax.bar(x + i*width, data_pivot[dtype], width, 
                   label=dtype.capitalize(), color=colors[dtype], alpha=0.8)
    
    ax.set_xlabel('File Size', fontsize=12)
    ax.set_ylabel('Speedup (times)', fontsize=12)
    ax.set_title('FastCDC Decompression Speedup vs Fixed Chunking', fontsize=14, fontweight='bold')
    ax.set_xticks(x + width)
    ax.set_xticklabels(['100KB', '1MB', '10MB'])
    ax.legend(title='Data Type')
    ax.grid(True, alpha=0.3, axis='y')
    ax.axhline(y=1, color='red', linestyle='--', linewidth=1, alpha=0.5, label='Baseline (1x)')
    
    # 添加数值标签
    for container in ax.containers:
        ax.bar_label(container, fmt='%.1fx', padding=3)
    
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'decompression_speedup.png', dpi=300, bbox_inches='tight')
    print(f"  已生成: {OUTPUT_DIR / 'decompression_speedup.png'}")
    plt.close()

def plot_stability_analysis(detail):
    """稳定性分析 - 箱型图"""
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    
    # 只关注混合数据(最重要的场景)
    mixed = detail[detail['DataType'] == 'mixed'].copy()
    
    # 1. 压缩时间稳定性
    ax = axes[0, 0]
    data_to_plot = [mixed[(mixed['TestName'] == f'mixed_{size}') & (mixed['Method'] == method)]['CompressTime_ms'].values
                    for size in ['100k', '1m', '10m'] for method in ['Fixed', 'FastCDC']]
    positions = [1, 1.5, 3, 3.5, 5, 5.5]
    bp = ax.boxplot(data_to_plot, positions=positions, widths=0.4, patch_artist=True,
                     labels=['100K\nFixed', '100K\nCDC', '1M\nFixed', '1M\nCDC', '10M\nFixed', '10M\nCDC'])
    
    # 上色
    colors = ['lightblue', 'lightgreen'] * 3
    for patch, color in zip(bp['boxes'], colors):
        patch.set_facecolor(color)
    
    ax.set_ylabel('Compression Time (ms)', fontsize=10)
    ax.set_title('Compression Time Stability (Mixed Data)', fontsize=12, fontweight='bold')
    ax.grid(True, alpha=0.3, axis='y')
    
    # 2. 解压时间稳定性
    ax = axes[0, 1]
    data_to_plot = [mixed[(mixed['TestName'] == f'mixed_{size}') & (mixed['Method'] == method)]['DecompressTime_ms'].values
                    for size in ['100k', '1m', '10m'] for method in ['Fixed', 'FastCDC']]
    bp = ax.boxplot(data_to_plot, positions=positions, widths=0.4, patch_artist=True,
                     labels=['100K\nFixed', '100K\nCDC', '1M\nFixed', '1M\nCDC', '10M\nFixed', '10M\nCDC'])
    
    for patch, color in zip(bp['boxes'], colors):
        patch.set_facecolor(color)
    
    ax.set_ylabel('Decompression Time (ms)', fontsize=10)
    ax.set_title('Decompression Time Stability (Mixed Data)', fontsize=12, fontweight='bold')
    ax.grid(True, alpha=0.3, axis='y')
    
    # 3. 压缩率稳定性
    ax = axes[1, 0]
    data_to_plot = [mixed[(mixed['TestName'] == f'mixed_{size}') & (mixed['Method'] == method)]['CompressionRatio'].values
                    for size in ['100k', '1m', '10m'] for method in ['Fixed', 'FastCDC']]
    bp = ax.boxplot(data_to_plot, positions=positions, widths=0.4, patch_artist=True,
                     labels=['100K\nFixed', '100K\nCDC', '1M\nFixed', '1M\nCDC', '10M\nFixed', '10M\nCDC'])
    
    for patch, color in zip(bp['boxes'], colors):
        patch.set_facecolor(color)
    
    ax.set_ylabel('Compression Ratio (%)', fontsize=10)
    ax.set_title('Compression Ratio Stability (Mixed Data)', fontsize=12, fontweight='bold')
    ax.grid(True, alpha=0.3, axis='y')
    
    # 4. 汇总统计
    ax = axes[1, 1]
    ax.axis('off')
    
    # 计算变异系数 (CV = std/mean * 100)
    stats_text = "Coefficient of Variation (CV)\n"
    stats_text += "=" * 40 + "\n\n"
    
    for test_name in ['mixed_100k', 'mixed_1m', 'mixed_10m']:
        for method in ['Fixed', 'FastCDC']:
            data = mixed[(mixed['TestName'] == test_name) & (mixed['Method'] == method)]
            cv_ratio = (data['CompressionRatio'].std() / data['CompressionRatio'].mean() * 100)
            cv_decomp = (data['DecompressTime_ms'].std() / data['DecompressTime_ms'].mean() * 100)
            stats_text += f"{test_name.replace('mixed_', '')} {method}:\n"
            stats_text += f"  Ratio CV: {cv_ratio:.2f}%\n"
            stats_text += f"  Decomp CV: {cv_decomp:.2f}%\n\n"
    
    ax.text(0.1, 0.9, stats_text, transform=ax.transAxes, fontsize=9,
            verticalalignment='top', fontfamily='monospace',
            bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.3))
    
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'stability_analysis.png', dpi=300, bbox_inches='tight')
    print(f"  已生成: {OUTPUT_DIR / 'stability_analysis.png'}")
    plt.close()

def plot_performance_heatmap(summary):
    """性能热力图"""
    fastcdc = summary[summary['Method'] == 'FastCDC'].copy()
    
    # 准备数据
    metrics = ['AvgCompressionRatio', 'SpaceSaving%', 'SpeedupDecompress']
    metric_names = ['Compression\nRatio (%)', 'Space\nSaving (%)', 'Decomp\nSpeedup (x)']
    
    fig, axes = plt.subplots(1, 3, figsize=(15, 4))
    
    for idx, (metric, name) in enumerate(zip(metrics, metric_names)):
        ax = axes[idx]
        
        # 准备数据
        data = fastcdc.copy()
        if metric != 'AvgCompressionRatio':
            data = data[data[metric] != '-']
            data[metric] = pd.to_numeric(data[metric])
        
        pivot = data.pivot(index='DataType', columns='FileSizeKB', values=metric)
        pivot = pivot.reindex(['random', 'pattern', 'mixed'])
        
        # 绘制热力图
        sns.heatmap(pivot, annot=True, fmt='.1f', cmap='RdYlGn_r' if metric == 'AvgCompressionRatio' else 'RdYlGn',
                    cbar_kws={'label': name}, ax=ax, vmin=0)
        
        ax.set_xlabel('File Size (KB)', fontsize=10)
        ax.set_ylabel('Data Type', fontsize=10)
        ax.set_title(name, fontsize=12, fontweight='bold')
        ax.set_xticklabels(['100KB', '1MB', '10MB'], rotation=0)
        ax.set_yticklabels(['Random', 'Pattern', 'Mixed'], rotation=0)
    
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'performance_heatmap.png', dpi=300, bbox_inches='tight')
    print(f"  已生成: {OUTPUT_DIR / 'performance_heatmap.png'}")
    plt.close()

def generate_summary_table(summary):
    """生成汇总表格"""
    fastcdc = summary[summary['Method'] == 'FastCDC'].copy()
    
    # 计算各场景的平均值
    summary_stats = []
    
    for dtype in ['random', 'pattern', 'mixed']:
        data = fastcdc[fastcdc['DataType'] == dtype]
        
        # 空间节省
        space_data = data[data['SpaceSaving%'] != '-']['SpaceSaving%'].astype(float)
        avg_space = space_data.mean() if len(space_data) > 0 else 0
        
        # 解压加速
        speedup_data = data[data['SpeedupDecompress'] != '-']['SpeedupDecompress'].astype(float)
        avg_speedup = speedup_data.mean() if len(speedup_data) > 0 else 0
        
        # 压缩率
        avg_ratio = data['AvgCompressionRatio'].mean()
        
        summary_stats.append({
            'Data Type': dtype.capitalize(),
            'Avg Compression Ratio': f"{avg_ratio:.2f}%",
            'Avg Space Saving': f"{avg_space:.2f}%",
            'Avg Decomp Speedup': f"{avg_speedup:.2f}x"
        })
    
    df = pd.DataFrame(summary_stats)
    
    # 保存为CSV
    output_file = OUTPUT_DIR / 'summary_stats.csv'
    df.to_csv(output_file, index=False)
    print(f"  已生成: {output_file}")
    
    # 打印表格
    print("\n" + "="*60)
    print("FastCDC 性能汇总统计")
    print("="*60)
    print(df.to_string(index=False))
    print("="*60 + "\n")

def main():
    """主函数"""
    print("="*60)
    print("FastCDC 基准测试结果可视化")
    print("="*60)
    print()
    
    # 加载数据
    print(" 加载数据...")
    summary, detail = load_data()
    print(f"   - 汇总数据: {len(summary)} 行")
    print(f"   - 详细数据: {len(detail)} 行")
    print()
    
    # 生成图表
    print(" 生成图表...")
    plot_compression_ratio_comparison(summary)
    plot_space_saving(summary)
    plot_decompression_speedup(summary)
    plot_stability_analysis(detail)
    plot_performance_heatmap(summary)
    print()
    
    # 生成统计表
    print(" 生成统计表...")
    generate_summary_table(summary)
    print()
    
    print("="*60)
    print(f" 完成！所有图表已保存到: {OUTPUT_DIR}")
    print("="*60)
    print()
    print("生成的文件:")
    for f in OUTPUT_DIR.glob('*.png'):
        print(f"  - {f.name}")
    print()

if __name__ == '__main__':
    main()
