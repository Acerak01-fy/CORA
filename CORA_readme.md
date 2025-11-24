# CORA 构建说明

本指南将帮助您配置和运行 CORA 镜像服务的常规使用场景。

- [CORA 构建说明](#cora-构建说明)
  - [安装](#安装)
    - [overlaybd-snapshotter](#overlaybd-snapshotter)
      - [源码编译](#源码编译)
      - [配置](#配置)
      - [启动服务](#启动服务)
    - [overlaybd-tcmu](#overlaybd-tcmu)
      - [从源码编译](#从源码编译)
      - [配置](#配置-1)
      - [启动服务](#启动服务-1)
  - [系统配置](#系统配置)
    - [Containerd](#containerd)
    - [认证](#认证)
  - [运行 overlaybd 镜像](#运行-overlaybd-镜像)
  - [镜像转换](#镜像转换)
  - [备注](#备注)
- [测验用例及方法](#测验用例及方法)
  - [测试镜像](#测试镜像)
  - [测试脚本](#测试脚本)
    - [1.容器镜像冷启动测试](#1容器镜像冷启动测试)
    - [2.分块算法去重效果对比实验](#2分块算法去重效果对比实验)

## 安装

需要配置两个组件：`overlaybd-snapshotter` 和 `overlaybd-tcmu`。它们分别位于当前代码仓库Accelerated_Container_Imag以及overlaybd中。


### overlaybd-snapshotter


#### 源码编译

安装依赖：
- golang 1.22+

运行以下命令进行构建：
```bash
#git clone https://github.com/containerd/accelerated-container-image.git 也可以在原仓库拉取，DADI的这部分未作修改
cd Accelerated_Container_Image
make
sudo make install
```


#### 配置
配置文件位于 `/etc/overlaybd-snapshotter/config.json`。如果文件不存在，请创建它。我们建议将 snapshotter 的根路径设置为 containerd 根路径的一个子路径。

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

| 字段 | 描述 |
|---|---|
| `root` | 存储快照的根目录。建议：此路径应为 containerd 根目录的子路径。 |
| `address` | 用于与 containerd 连接的 socket 地址。 |
| `verbose` | 日志级别，`info` 或 `debug`。 |
| `rwMode` | rootfs 模式，关于是否使用原生可写层。详情请见“原生可写支持”。 |
| `logReportCaller` | 启用/禁用调用方法日志。 |
| `autoRemoveDev` | 启用/禁用在容器移除后自动清理 overlaybd 设备。 |
| `exporterConfig.enable` | 是否创建一个服务器以展示 Prometheus 指标。 |
| `exporterConfig.uriPrefix` | 导出指标的 URI 前缀，默认为 `/metrics`。 |
| `exporterConfig.port` | 用于展示指标的 http 服务器端口，默认为 9863。 |
| `mirrorRegistry` | 镜像仓库的数组。 |
| `mirrorRegistry.host` | 主机地址，例如 `registry-1.docker.io`。 |
| `mirrorRegistry.insecure` | `true` 或 `false`。 |

#### 启动服务
直接运行 `/opt/overlaybd/snapshotter/overlaybd-snapshotter` 二进制文件，或者通过添加到systemctl启动 `overlaybd-snapshotter.service` 来作为服务运行。

如果从源码安装，请运行以下命令启动服务：
```bash
sudo systemctl enable /opt/overlaybd/snapshotter/overlaybd-snapshotter.service
sudo systemctl start overlaybd-snapshotter
```

### overlaybd-tcmu


<!-- > **注意**：`overlaybd-snapshotter` 和 `overlaybd-tcmu` 的版本之间没有强依赖关系。但是，`overlaybd-snapshotter v1.0.1+` 需要 `overlaybd-tcmu v1.0.4+`，因为镜像转换的参数有所调整。 -->

#### 从源码编译

安装依赖：
- cmake 3.15+
- gcc/g++ 7+
- 开发依赖：
  - **CentOS 7/Fedora**: `sudo yum install libaio-devel libcurl-devel openssl-devel libnl3-devel libzstd-static e2fsprogs-devel`
  - **CentOS 8**: `sudo yum install libaio-devel libcurl-devel openssl-devel libnl3-devel libzstd-devel e2fsprogs-devel`
  - **Debian/Ubuntu**: `sudo apt install libcurl4-openssl-dev libssl-dev libaio-dev libnl-3-dev libnl-genl-3-dev libgflags-dev libzstd-dev libext2fs-dev`

运行以下命令进行构建：
```bash
cd overlaybd
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j
sudo make install
```


#### 配置
配置文件位于 `/etc/overlaybd/overlaybd.json`。如果通过包管理器安装，会自动生成默认配置，可以直接使用无需更改。


#### 启动服务
```bash
sudo systemctl enable /opt/overlaybd/overlaybd-tcmu.service
sudo systemctl start overlaybd-tcmu
```

## 系统配置

### Containerd
需要 `containerd 1.4+` 版本。

将 snapshotter 配置添加到 containerd 的配置文件中（默认为 `/etc/containerd/config.toml`）。
```toml
[proxy_plugins.overlaybd]
    type = "snapshot"
    address = "/run/overlaybd-snapshotter/overlaybd.sock"
```

如果使用 k8s/cri，请添加以下配置：
```toml
[plugins.cri]
    [plugins.cri.containerd]
        snapshotter = "overlaybd"
        disable_snapshot_annotations = false
```
确保 `cri` 没有在 containerd 配置文件的 `disabled_plugins` 列表中。

最后，不要忘记重启 containerd 服务。

### 认证
由于 `containerd` 和 `overlaybd-tcmu` 之间无法共享认证信息，因此必须为 `overlaybd-tcmu` 单独配置认证。

`overlaybd-tcmu` 的认证配置文件路径可以在 `/etc/overlaybd/overlaybd.json` 中指定（默认为 `/opt/overlaybd/cred.json`）。

这是一个示例，其格式与 Docker 的认证文件（`/root/.docker/config.json`）相同：
```json
{
  "auths": {
    "hub.docker.com": {
      "username": "username",
      "password": "password"
    },
    "hub.docker.com/hello/world": {
      "auth": "dXNlcm5hbWU6cGFzc3dvcmQK"
    }
  }
}
```

## 运行 overlaybd 镜像
现在用户可以运行 overlaybd 格式的镜像了。有以下几种方法：

**使用 `nerdctl`**
```bash
sudo nerdctl run --net host -it --rm --snapshotter=overlaybd registry.hub.docker.com/overlaybd/redis:6.2.1_obd
```

**使用 `rpull`**
```bash
# 使用 rpull 拉取镜像，但不会下载层数据
sudo /opt/overlaybd/snapshotter/ctr rpull -u {user}:{pass} registry.hub.docker.com/overlaybd/redis:6.2.1_obd

# 使用 ctr run 运行容器
sudo ctr run --net-host --snapshotter=overlaybd --rm -t registry.hub.docker.com/overlaybd/redis:6.2.1_obd demo
```


## 镜像转换
有两种方法可以将 OCI 格式的镜像转换为 overlaybd 格式：使用内嵌的 `image-convertor` 或使用独立的用户空间 `image-convertor`。

**使用内嵌的 `image-convertor`**
```bash
# 拉取源镜像 (使用 nerdctl 或 ctr)
sudo nerdctl pull registry.hub.docker.com/library/redis:7.2.3

# 转换
sudo /opt/overlaybd/snapshotter/ctr obdconv registry.hub.docker.com/library/redis:7.2.3 registry.hub.docker.com/overlaybd/redis:7.2.3_obd_new

# 将 overlaybd 镜像推送到镜像仓库，之后新的转换后镜像就可以作为远程镜像使用
sudo nerdctl push registry.hub.docker.com/overlaybd/redis:7.2.3_obd_new

# 移除本地的 overlaybd 镜像
sudo nerdctl rmi registry.hub.docker.com/overlaybd/redis:7.2.3_obd_new
```

**使用独立的用户空间 `image-convertor`**
```bash
# userspace-image-convertor 会自动从镜像仓库拉取和推送镜像
sudo /opt/overlaybd/snapshotter/convertor -r registry.hub.docker.com/library/redis -i 6.2.1 -o 6.2.1_obd_new
```

## 备注
由于DADI当前版本引入的[libphoton](https://photonlibos.github.io/cn/docs/category/introduction)的网络库，这个库是不支持http_proxy的变量的，所以设置代理没有用，run的时候是由overlaybd-tcmu去发请求，所以即使把containerd，ctr，overlaybd-tcmu, overlaybd-snapshotter全部加上http_proxy的环境变量也都没有用，运行的时候会获取blob失败。
因此本次实验采用的是局域网内不同主机之间做测试，采用的是一台主机做registry，另一台主机来做冷启动实验。目的是解决校园网访问dockerhub仓库存在的网络问题。并且这种情况需要为registry主机申请https自签名证书走https协议传输。才能成功。

# 测试用例
相关截图和视频在experiments目录下。
## 测试一 冷启动加速测试
### 目标 
验证验证按需加载机制对容器冷启动的加速效果

#### 测试步骤：

1）非按需加载验证 （例如直接使用docker下载）

清理本地镜像缓存与系统缓存，记录当前的磁盘占用
验证原始镜像在环境上冷启动时间

2）按需加载验证

清理本地镜像缓存，记录当前的磁盘占用
使用监控脚本记录资源开销情况
验证按需下载的冷启动时间

#### 输出：
- 冷启动加速的情况

- 对比过程中资源开销折线图

- 过程屏幕录屏

### 结果

#### 1. 冷启动情况

> 如下图所示，OverlayBD 按需加载（绿色）相比普通 OCI 镜像全量下载（蓝色），显著缩短了冷启动时间。

![冷启动耗时对比](./experiments/Cold-start-acceleration-test/cold_start_comparison.png)

#### 2. 资源开销情况

> 下图展示了测试全过程中的资源消耗。可以看到 OverlayBD 即使在按需读取数据时，CPU 和内存的开销也保持在较低水平，与普通镜像运行无显著差异，证明了其轻量高效的特性。

注：由于当前服务器CPU性能较为强悍，这种小负载无法拉高CPU的利用率。

![资源开销对比](./experiments/Cold-start-acceleration-test//resource_usage_comparison.png)

## 测试二 数据去重测试
### 目的
测试数据去重情况。对比DADI的固定大小分块。
#### 测试数据集
为全面评估 CORA 在不同数据特征下的性能，本文设计了三类测试数据集：
1. 随机数据（Random）：使用 /dev/urandom 生成，模拟不可压缩的最坏情况。
2. 模式数据（Pattern）：通过重复固定字符串生成，模拟高度可压缩的场景。
3. 混合数据（Mixed）：交替使用 4KB 重复块和 4KB 随机块，模拟真实容器镜像的混合
场景。

每类数据集包含三种文件大小：100KB、1MB、10MB，共计 9 组测试用例。
#### 测试方法与指标
• 重复次数：每组测试用例重复执行 5 次。
• 数据记录与分析：自动记录压缩后大小、耗时等数据，并计算平均值与标准差。
• 完整性验证：对每次解压缩结果进行 MD5 哈希校验，确保数据与原始数据完全一致。
• 核心性能指标：
– 空间节省率（Space Saving）：评估去重效果。
– 压缩/解压缩加速比（Speedup Ratio）：衡量处理效率。
– 数据完整性：MD5 校验通过率必须为 100%。
总计执行了 90 组基准测试（9 种配置 × 2 种方法 × 5 次重复）。
### 结果

表 2 从宏观上展示了在三种不同数据类型下，CORA 方案的综合表现。

#### 表 2: FastCDC vs 固定分块综合性能对比

| 数据类型 | 平均空间节省率 | 平均解压缩加速比 | MD5 通过率 |
| :--- | :---: | :---: | :---: |
| 随机数据（Random） | -0.10% | 8.31× | 100% |
| 模式数据（Pattern） | 61.51% | 8.58× | 100% |
| 混合数据（Mixed） | 72.36% | 8.79× | 100% |

#### 关键发现：

• **高去重率**：在最接近真实场景的“混合数据”中，FastCDC 实现了 **72.36%** 的空间节省，证明其在识别跨边界重复数据方面的卓越能力。

• **高稳定性**：即使在不可压缩的“随机数据”场景下，空间开销也仅为 0.10%，无性能退化。

• **数据完整性**：所有 90 组测试的 MD5 校验通过率均为 **100%**，证明方案的可靠性。

## 测试三 OCIv1兼容性测试
### 目标
验证与现有容器生态的兼容性。
#### 测试步骤
- 清理节点上镜像以及其缓存

- 支持按需下载的镜像，在标准环境环境下冷启动运行；

- ociv1标准的镜像，可以在支持按需下载的环境下冷启动运行；
### 结果
![alt text](./experiments/OCI-compatibility-test/compatibility-photo.png)
完全符合预期，在按需加载环境下能够顺利完成OCIv1镜像的冷启动。

## 测试四 高并发压力测试
### 目的
评估系统在并发启动多个按需下载，数据去重容器时的表现。
#### 测试镜像：
xfusion5:5000:
- godnf/tst-depdup:v1.0 
- godnf/tst-depdup:v2.0
- godnf/tst-lazy-pull:latest
- godnf/test-python:latest
#### 测试步骤
- 清理节点上镜像以及其系统缓存
- 在单节点上同时启动4个镜像的冷启动
### 结果
并发效果良好，并且仅需0.7秒即可完成所有镜像的启动。
![alt text](./experiments/pressure-test/pressure-test-photo.png)