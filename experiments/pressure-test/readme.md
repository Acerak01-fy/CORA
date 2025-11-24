# 高并发压力测试
## 目的
评估系统在并发启动多个按需下载，数据去重容器时的表现。
### 测试镜像：
xfusion5:5000:
- godnf/tst-depdup:v1.0 
- godnf/tst-depdup:v2.0
- godnf/tst-lazy-pull:latest
- godnf/test-python:latest
### 测试步骤
- 清理节点上镜像以及其系统缓存
- 在单节点上同时启动4个镜像的冷启动
## 结果
并发效果良好，并且仅需0.7秒即可完成所有镜像的启动。
![alt text](pressure-test-photo.png)