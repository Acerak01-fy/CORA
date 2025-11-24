#!/bin/bash

# 清理系统缓存脚本 - 针对容器镜像测试场景

if [ "$EUID" -ne 0 ]; then
    echo "错误：需要 root 权限清理系统缓存"
    echo "请使用: sudo bash $0"
    exit 1
fi

echo "=========================================="
echo "  清理系统缓存"
echo "=========================================="
echo ""

# 1. 显示清理前的内存状态
echo "[1] 清理前内存状态："
free -h | grep -E "Mem|Swap|Buff"
echo ""

# 2. 同步磁盘数据到存储
echo "[2] 同步磁盘数据..."
sync
sync
sync
echo "  ✓ 同步完成"
echo ""

# 3. 清理 Page Cache（页面缓存）
echo "[3] 清理 Page Cache..."
echo 1 > /proc/sys/vm/drop_caches
sleep 1
echo "  ✓ Page Cache 已清理"
echo ""

# 4. 清理 Dentries 和 Inodes
echo "[4] 清理 Dentries 和 Inodes..."
echo 2 > /proc/sys/vm/drop_caches
sleep 1
echo "  ✓ Dentries 和 Inodes 已清理"
echo ""

# 5. 清理所有缓存（Page Cache + Dentries + Inodes）
echo "[5] 清理所有内核缓存..."
echo 3 > /proc/sys/vm/drop_caches
sleep 1
echo "  ✓ 所有缓存已清理"
echo ""

# 6. 显示清理后的内存状态
echo "[6] 清理后内存状态："
free -h | grep -E "Mem|Swap|Buff"
echo ""

# 7. 计算释放的内存
echo "=========================================="
echo "  清理完成！"
echo "=========================================="
echo ""

# 提示
echo "说明："
echo "  - drop_caches = 1: 清理页面缓存"
echo "  - drop_caches = 2: 清理目录项和inode缓存"
echo "  - drop_caches = 3: 清理所有缓存"
echo ""
echo "注意："
echo "  - 这不会清理脏页（dirty pages），所以先执行 sync"
echo "  - 这是非破坏性操作，只清理缓存，不影响数据"
echo "  - 清理后首次访问会较慢（需要重新缓存）"
echo ""

