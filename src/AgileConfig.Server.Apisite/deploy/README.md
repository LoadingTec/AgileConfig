# AgileConfig Server - Ubuntu 部署说明

基于 AgileConfig.Server.Apisite 的 Ubuntu systemd 服务部署方案。

## 文件说明

| 文件 | 说明 |
|------|------|
| `agileconfig.service` | systemd 服务单元模板 |
| `install-ubuntu.sh` | 首次安装脚本（安装依赖、发布、注册服务） |
| `deploy-ubuntu.sh` | 更新部署脚本（本地或远程） |

##  quick start

### 1. 首次安装（在 Ubuntu 服务器上）

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

## 注意事项

- 默认监听端口：**5000**
- 日志目录：`{部署目录}/logs/`
- SQLite 数据文件：`agile_config.db`（使用 sqlite 时）
- 部署前请先在 `appsettings.json` 中配置数据库等参数
