# CORA 容器镜像加速服务 - 构建与测试报告

> 📖 **完整技术文档**： [CORA技术文稿.pdf](./CORA技术文稿.pdf) （包含 CORA 的系统架构、设计细节、技术实现、实验设计、综合效益分析以及应用价值等）
>
> 📈 **标准测试报告**： [查看测试报告章节](#2-实验验证) （包含详细的测试环境、测试步骤、测试脚本、原始数据记录及测试结果截图）

本指南详细记录了 CORA (基于 OverlayBD) 镜像服务的环境搭建、配置流程以及针对比赛要求的四项核心测试报告。
## 目录

- [1. 环境搭建与配置](#1-环境搭建与配置)
  - [1.1 安装 overlaybd-snapshotter](#11-安装-overlaybd-snapshotter)
  - [1.2 安装 overlaybd-tcmu](#12-安装-overlaybd-tcmu)
  - [1.3 系统配置](#13-系统配置)
  - [1.4 运行 overlaybd 镜像](#14-运行-overlaybd-镜像)
  - [1.5 镜像转换](#15-镜像转换)
  - [1.6 环境备注 (重要)](#16-环境备注-重要)
- [2. 实验验证](#2-实验验证)
  - [2.1 测试一：冷启动加速测试](#21-测试一冷启动加速测试)
  - [2.2 测试二：数据去重测试 (FastCDC)](#22-测试二数据去重测试)
  - [2.3 测试三：OCIv1 兼容性测试](#23-测试三ociv1-兼容性测试)
  - [2.4 测试四：高并发压力测试](#24-测试四高并发压力测试)

---

## 1. 环境搭建与配置

需要配置两个核心组件：`overlaybd-snapshotter` (快照插件) 和 `overlaybd-tcmu` (用户态块设备后端)。

### 1.1 安装 overlaybd-snapshotter

#### 源码编译

安装依赖：`golang 1.22+`

运行以下命令进行构建：
```bash
# 源码位于本仓库 Accelerated_Container_Image 目录
cd Accelerated_Container_Image
make
sudo make install
```

#### 配置

配置文件位于 `/etc/overlaybd-snapshotter/config.json`。建议配置如下：

```json
{
    "root": "/var/lib/containerd/io.containerd.snapshotter.v1.overlaybd",
    "address": "/run/overlaybd-snapshotter/overlaybd.sock",
    "verbose": "info",
    "rwMode": "overlayfs",
    "logReportCaller": false,
    "autoRemoveDev": false,
    "exporterConfig": {
        "enable": false,
        "uriPrefix": "/metrics",
        "port": 9863
    },
    "mirrorRegistry": [
        {
            "host": "localhost:5000",
            "insecure": true
        },
        {
            "host": "registry-1.docker.io",
            "insecure": false
        }
    ]
}
```

#### 启动服务

```bash
sudo systemctl enable /opt/overlaybd/snapshotter/overlaybd-snapshotter.service
sudo systemctl start overlaybd-snapshotter
```

### 1.2 安装 overlaybd-tcmu

#### 从源码编译

安装依赖：`cmake 3.15+`, `gcc/g++ 7+` 以及相关开发库 (libcurl, openssl, libnl3, libzstd, e2fsprogs 等)。

运行以下命令进行构建：
```bash
cd overlaybd
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j
sudo make install
```

#### 启动服务

```bash
sudo systemctl enable /opt/overlaybd/overlaybd-tcmu.service
sudo systemctl start overlaybd-tcmu
```

### 1.3 系统配置

#### Containerd 配置

编辑 `/etc/containerd/config.toml`，注册 overlaybd 插件：

```toml
[proxy_plugins.overlaybd]
    type = "snapshot"
    address = "/run/overlaybd-snapshotter/overlaybd.sock"
```

如果使用 k8s/cri：
```toml
[plugins.cri.containerd]
    snapshotter = "overlaybd"
    disable_snapshot_annotations = false
```
*配置完成后请重启 containerd。*

#### 认证配置

由于 `containerd` 和 `overlaybd-tcmu` 认证隔离，需单独配置 `/opt/overlaybd/cred.json`（格式同 Docker config.json）。

### 1.4 运行 overlaybd 镜像

**使用 `nerdctl` (推荐)**
```bash
sudo nerdctl run --net host -it --rm --snapshotter=overlaybd registry.hub.docker.com/overlaybd/redis:6.2.1_obd
```

**使用 `ctr`**
```bash
# 拉取元数据
sudo /opt/overlaybd/snapshotter/ctr rpull -u {user}:{pass} registry.hub.docker.com/overlaybd/redis:6.2.1_obd
# 运行容器
sudo ctr run --net-host --snapshotter=overlaybd --rm registry.hub.docker.com/overlaybd/redis:6.2.1_obd demo
```

### 1.5 镜像转换

将 OCI 格式镜像转换为 OverlayBD 格式：

```bash
# 转换
sudo /opt/overlaybd/snapshotter/ctr obdconv \
    registry.hub.docker.com/library/redis:7.2.3 \
    registry.hub.docker.com/overlaybd/redis:7.2.3_obd_new

# 推送转换后的镜像
sudo nerdctl push registry.hub.docker.com/overlaybd/redis:7.2.3_obd_new
```

### 1.6 环境备注 (重要)

> **关于网络代理与证书**：
> 由于 DADI 当前版本引入的 `libphoton` 网络库不支持 `http_proxy` 环境变量，且本次实验在需要 HTTPS 自签名证书的局域网环境中进行（以解决校园网访问 DockerHub 的限制）。
> 因此，实验环境采用了一台主机做 Registry，另一台主机做测试节点，并配置了相应的 Hosts 和证书信任。

---

## 2. 实验验证

所有测试相关的截图、视频和原始数据均位于 `experiments/` 目录下。

### 2.1 测试一：冷启动加速测试

#### 目标
验证 OverlayBD 按需加载机制（Lazy Loading）相比传统 OCI 全量下载对容器冷启动速度的提升。

#### 测试步骤
1.  **Baseline (OCI)**: 清理缓存，使用标准 OCI 镜像运行，记录冷启动耗时和资源开销。
2.  **OverlayBD**: 清理缓存，使用 OverlayBD 镜像运行（按需加载），记录同等条件下的数据。

#### 结果分析

**1. 冷启动耗时对比**
> 如下图所示，OverlayBD 按需加载（绿色）相比普通 OCI 镜像全量下载（蓝色），显著缩短了冷启动时间。

![冷启动耗时对比](./experiments/Cold-start-acceleration-test/cold_start_comparison.png)

**2. 资源开销对比**
> 下图展示了测试全过程中的资源消耗。OverlayBD 在按需读取数据时，CPU 和内存开销保持在较低水平。
> *注：由于服务器 CPU 性能较强，负载未显著拉高利用率。*

![资源开销对比](./experiments/Cold-start-acceleration-test/resource_usage_comparison.png)

### 2.2 测试二：数据去重测试 (FastCDC)

#### 目标
评估引入 FastCDC 分块算法后，CORA 方案在不同数据类型下的去重效率，并与固定大小分块进行对比。

#### 测试数据集
- **Random**: 随机数据，模拟不可压缩场景。
- **Pattern**: 模式数据，模拟高重复率场景。
- **Mixed**: 混合数据，模拟真实镜像场景。

#### 关键发现 (FastCDC vs 固定分块)

| 数据类型 | 平均空间节省率 | 平均解压缩加速比 | MD5 通过率 |
| :--- | :---: | :---: | :---: |
| 随机数据 (Random) | -0.10% | 8.31× | 100% |
| 模式数据 (Pattern) | 61.51% | 8.58× | 100% |
| **混合数据 (Mixed)** | **72.36%** | **8.79×** | **100%** |

*   **高去重率**：在混合数据场景下，FastCDC 实现了 **72.36%** 的空间节省。
*   **稳定性**：在最差情况（随机数据）下无显著负优化。
*   **完整性**：90 组测试用例 MD5 校验全部通过。

### 2.3 测试三：OCIv1 兼容性测试

#### 目标
验证 OverlayBD 环境对标准 OCIv1 镜像的向后兼容性。

#### 结果
![OCI兼容性测试](./experiments/OCI-compatibility-test/compatibility-photo.png)

测试结果表明，标准 OCIv1 镜像可以在 OverlayBD 环境下正常下载并冷启动运行，完全符合预期。

### 2.4 测试四：高并发压力测试

#### 目标
评估系统在单节点高并发场景下，同时启动多个 OverlayBD 容器（涉及数据去重和按需下载）的稳定性与性能。

#### 测试环境
- **并发数**: 4 个容器同时启动
- **负载**: 3 个 IO 密集型 (MD5 校验) + 1 个计算型 (Python)

#### 结果
![压力测试结果](./experiments/pressure-test/pressure-test-photo.png)

*   **启动速度**: 仅需约 **0.7秒** 即可完成所有 4 个镜像的并发启动（Time to Running）。
*   **稳定性**: 所有容器均成功进入 Running 状态，未出现 I/O 挂死或服务崩溃。
