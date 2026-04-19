# AgileConfig Server - Ubuntu 部署说明

基于 AgileConfig.Server.Apisite 的 Ubuntu systemd 服务部署方案。

## 文件说明

| 文件 | 说明 |
|------|------|
| `agileconfig.service` | systemd 服务单元模板 |
| `Service_Install.md` | **Windows 服务 + Ubuntu systemd** 安装说明与主/从节点角色 |
| `install-windows-service.ps1` | Windows 交互一键安装（主节点带后台 / 从节点无 UI） |
| `install-linux-service.sh` | Linux 交互一键安装（同上，生成 `/etc/agileconfig/agileconfig.env`） |
| `install-ubuntu.sh` | 非交互首次安装（固定参数） |
| `deploy-ubuntu.sh` | 更新部署脚本（本地或远程） |

##  quick start

### 1. 首次安装（在 Ubuntu 服务器上）

一般性逻辑说明：通过开发机器采用 dotnet publish -r linux-x64 -o deploy/linux-x64/v1.11.3 指定框架为linux-x64 发布，并复制到服务器上。通过单元服务启动指定端口：8050，自动重启验证效果。

```bash
PS C:\Users\Administrator\source\repos\AgileConfig\src\AgileConfig.Server.Apisite

dotnet publish -r linux-x64 -o deploy/linux-x64/v1.11.3 -c Release --self-contained true

~/dotnet10/dotnet AgileConfig.Server.Apisite.dll
```
- 有新特性开发，走代码逻辑迭代后，停止服务，再次启动单元服务。

由于项目使用 **.NET 10**，推荐使用自包含发布（无需安装 .NET 运行时）：

```bash
# 将项目复制到 Ubuntu 后
cd /path/to/AgileConfig/src/AgileConfig.Server.Apisite/deploy
sudo bash install-ubuntu.sh --self-contained
```

自定义参数：

```bash
sudo bash install-ubuntu.sh --self-contained \
  --deploy-dir /opt/agileconfig \
  --user agileconfig \
  --port 5000
```

### 2. 更新部署

**本地更新**（在已安装的服务器上）：

```bash
cd /path/to/AgileConfig/src/AgileConfig.Server.Apisite/deploy
sudo bash deploy-ubuntu.sh
```

**远程更新**（从开发机推送至服务器）：

```bash
cd /path/to/AgileConfig/src/AgileConfig.Server.Apisite/deploy
bash deploy-ubuntu.sh --remote user@192.168.1.100
```

### 3. 服务管理

```bash
systemctl start agileconfig    # 启动
systemctl stop agileconfig    # 停止
systemctl restart agileconfig # 重启
systemctl status agileconfig  # 状态
journalctl -u agileconfig -f  # 查看日志
```

## 环境变量配置

在 `/etc/systemd/system/agileconfig.service` 的 `[Service]` 下添加：

```ini
# 数据库
Environment=db:provider=mysql
Environment=db:conn=Server=127.0.0.1;Database=configcenter;User=root;Password=xxx

# 管理控制台与集群
Environment=adminConsole=true
Environment=cluster=true
Environment=saPassword=your_admin_password
```

修改后执行：

```bash
sudo systemctl daemon-reload
sudo systemctl restart agileconfig
```

## Windows 与交互式 Linux 安装

主节点（`adminConsole=true`）与从节点（`adminConsole=false`、`cluster` 可配）见 **`Service_Install.md`**，并可直接运行：

- Windows（管理员 PowerShell）：`.\install-windows-service.ps1`
- Ubuntu：`sudo bash install-linux-service.sh`

## 高可用（HA）部署

高可用分步部署与客户端示例见 **`ha/HA-Deploy.md`**；从 SQLite 迁到 MongoDB 见 **`ha/Migrate-Sqlite-To-Mongodb.md`**。内网 + 办公网多节点方案与清单见 `ha/README_HA.md`，包含：

- 共享 MySQL/PostgreSQL 多节点集群
- 跨网段节点注册
- Nginx 负载均衡示例
- 客户端 nodes 配置

## 注意事项

- 默认监听端口：**5000**（本项目使用 8050）
- 日志目录：`{部署目录}/logs/`
- SQLite 数据文件：`agile_config.db`（使用 sqlite 时）
- 部署前请先在 `appsettings.json` 中配置数据库等参数
