# 配置中心服务安装说明（Windows 服务 + Ubuntu systemd）

本文说明如何在 **Windows** 与 **Ubuntu** 上以系统服务方式安装 AgileConfig.Server.Apisite，并支持 **主节点（带管理后台）** 与 **从节点（无管理界面、加入集群）** 两种角色。

程序已集成 **`UseWindowsService()`**（Windows）与 **`UseSystemd()`**（Linux），与 `Type=notify` 的 systemd 单元配合，服务启停由系统正确管理。

---

## 角色与配置对照

| 角色 | `adminConsole` | `cluster` | 说明 |
|------|----------------|-----------|------|
| **主节点** | `true` | 可选 `true`/`false` | 至少部署 **一个** 主节点；浏览器打开管理 UI、维护节点列表。 |
| **从节点** | `false` | 建议 `true`（同网段自动注册） | 仅提供 API；跨网段时设 `cluster=false` 并在主节点控制台 **手动添加节点**。 |

**高可用（多节点）** 必须使用 **共享数据库**（MySQL / PostgreSQL / SQL Server / MongoDB 等），**不能**各节点各用一份 SQLite。详见 `ha/README_HA.md`。

---

## 一键脚本（推荐）

在 **`deploy`** 目录下执行，按提示选择节点角色、端口、数据库等。

| 平台 | 脚本 | 权限 |
|------|------|------|
| Windows | `install-windows-service.ps1` | **以管理员身份**打开 PowerShell |
| Ubuntu / Debian 等 | `install-linux-service.sh` | `sudo bash install-linux-service.sh` |

### Windows 示例

```powershell
cd C:\path\to\AgileConfig\src\AgileConfig.Server.Apisite\deploy
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install-windows-service.ps1
```

可选参数（非交互或覆盖提示）：

```powershell
.\install-windows-service.ps1 -Role Primary -DeployDir "D:\AgileConfig" -Port 8050 -DbProvider mysql -DbConn "Server=127.0.0.1;Database=agileconfig;User=root;Password=xxx;Port=3306" -SkipPublish
```

- `-Role`：`Primary` | `Secondary`
- `-Cluster`：`true` | `false`（从节点默认 `true`；主节点会询问或指定）
- `-SkipPublish`：不执行 `dotnet publish`，仅使用已有发布目录或 `-PublishSource`

### Linux 示例

```bash
cd /path/to/AgileConfig/src/AgileConfig.Server.Apisite/deploy
sudo bash install-linux-service.sh
```

可选环境变量（非交互）：

```bash
sudo ROLE=secondary CLUSTER=true DB_PROVIDER=mysql DB_CONN='Server=...' PORT=8050 bash install-linux-service.sh
```

- `ROLE`：`primary` | `secondary`
- `CLUSTER`：`true` | `false`
- `SELF_CONTAINED`：`true` | `false`

---

## Windows：手动安装服务

1. **发布**（在开发机）：

   ```powershell
   dotnet publish ..\AgileConfig.Server.Apisite.csproj -c Release -o D:\publish\agileconfig
   ```

2. 编辑 `D:\publish\agileconfig\appsettings.json`：设置 `urls`、`adminConsole`、`cluster`、`db`（与脚本逻辑一致）。

3. **注册服务**（管理员 CMD，路径按实际修改）：

   ```bat
   sc create AgileConfigServer binPath= "\"C:\Program Files\dotnet\dotnet.exe\" \"D:\publish\agileconfig\AgileConfig.Server.Apisite.dll\"" start= auto DisplayName= "AgileConfig Server"
   sc description AgileConfigServer "AgileConfig configuration center"
   sc start AgileConfigServer
   ```

4. **卸载**：

   ```bat
   sc stop AgileConfigServer
   sc delete AgileConfigServer
   ```

自包含发布时，将 `binPath` 改为生成的可执行文件路径（如 `AgileConfig.Server.Apisite.exe`），且无需 `dotnet.exe`。

---

## Ubuntu：手动安装 systemd

1. 将发布目录复制到服务器，例如 `/opt/agileconfig`。
2. 参考 `agileconfig.service` 或 `ha/agileconfig-ha.service` 编写 `/etc/systemd/system/agileconfig.service`，设置 `WorkingDirectory`、`ExecStart`、`User`。环境变量可写在单元文件的 `Environment=` 中，或使用 **`install-linux-service.sh` 生成的** `/etc/agileconfig/agileconfig.env`（脚本内使用 `db__provider` / `db__conn`，与 .NET 的 `db:provider` / `db:conn` 等价）。

   手动示例（与 HA 文档一致，亦可用 `EnvironmentFile` 引用单独文件）：

   ```ini
   Environment=urls=http://*:8050
   Environment=adminConsole=true
   Environment=cluster=true
   Environment=db:provider=mysql
   Environment=db:conn=Server=...;Database=...;User=...;Password=...;Port=3306
   ```

3. 执行：

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now agileconfig
   journalctl -u agileconfig -f
   ```

高可用完整部署顺序与客户端接入见 **`ha/HA-Deploy.md`**；架构与清单见 **`ha/README_HA.md`**。

---

## 与现有脚本的关系

| 文件 | 用途 |
|------|------|
| `install-ubuntu.sh` | 非交互：固定参数安装（可与本交互脚本二选一） |
| `deploy-ubuntu.sh` | 已安装后的更新发布 |
| `install-linux-service.sh` | **交互式**：主/从角色 + 数据库 + systemd |
| `install-windows-service.ps1` | **交互式**：主/从角色 + 修改 appsettings + Windows 服务 |

---

## 检查清单

- [ ] 多节点时所有实例连接 **同一数据库**
- [ ] 至少一个节点 `adminConsole=true`
- [ ] 跨网段从节点：`cluster=false` 并在控制台添加节点 URL
- [ ] 防火墙放行监听端口（默认常配 `8050`）
- [ ] 服务运行账户对部署目录、日志、数据库文件有读写权限
