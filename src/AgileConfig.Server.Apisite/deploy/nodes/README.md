# 三节点本地 HA 演示（node-admin + node-console-1/2）

| 目录 | 角色 | 端口 | `adminConsole` |
|------|------|------|----------------|
| `node-admin` | 主节点（带管理界面） | **8051** | `true` |
| `node-console-1` | 从节点 | **8052** | `false` |
| `node-console-2` | 从节点 | **8053** | `false` |

三份 `appsettings.json` 已统一为 **共享 MongoDB**（HA 场景**不可**使用 SQLite）：

- `db:provider` = **`mongodb`**
- `db:conn` = **`mongodb://127.0.0.1:27017/AgileConfig`**（无认证本地；生产请改为带用户名密码的 URI，见下文）

`env.TEST` 使用库 **`AgileConfig_TEST`**，可按需修改。

## 1. 安装 MongoDB（Windows 服务）

**推荐（最新稳定渠道版，当前 winget 多为 8.2.x）：** 以管理员打开 PowerShell，在 `deploy\nodes` 下执行：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install-mongodb-windows.ps1
```

脚本通过 **`winget install MongoDB.Server`** 静默安装；安装完成后服务名一般为 **`MongoDB`**，默认监听 **`27017`**。

手动安装：从 [MongoDB Community Download](https://www.mongodb.com/try/download/community) 下载 Windows x64 MSI，安装时勾选 **Install MongoDB as a Service**。

验证：

```powershell
Get-Service MongoDB
Test-NetConnection -ComputerName 127.0.0.1 -Port 27017
```

### mongosh 与 PATH

新终端若提示找不到 `mongosh`，先刷新当前会话 PATH：

```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
mongosh --version
```

未安装 Shell 时：`winget install MongoDB.Shell --source winget`

### CRUD 冒烟脚本（独立库 `mongosh_smoke_test`）

不写入 **AgileConfig** 业务库，仅验证连接与增删改查：

```powershell
cd ...\deploy\nodes
.\run-mongosh-crud-smoke.ps1
# 或指定 URI：
.\run-mongosh-crud-smoke.ps1 -Uri 'mongodb://127.0.0.1:27017/mongosh_smoke_test'
```

逻辑见 **`mongosh-crud-smoke.js`**：`deleteMany` 清理 → `insertOne` → `findOne` → `updateOne`（`$set`）→ `deleteOne` → `countDocuments` 断言为 0。

## 2. 从旧 SQLite 迁数据（可选）

若此前用过 `shared/h300_agileconfig.db` 或单节点 `h300_config.db`，可使用仓库工具迁到 MongoDB，详见：

**[../ha/Migrate-Sqlite-To-Mongodb.md](../ha/Migrate-Sqlite-To-Mongodb.md)** 与 `..\ha\migrate-sqlite-to-mongodb.ps1`。

全新部署可跳过迁移，直接启动主节点走初始化向导。

## 3. 生产用 MongoDB 连接串示例

无认证（仅内网调试）：

```text
mongodb://127.0.0.1:27017/AgileConfig
```

有用户、认证库为 `admin`：

```text
mongodb://agileconfig:YourPassword@192.168.1.50:27017/AgileConfig?authSource=admin
```

将三节点 `db:conn` 改为**同一** URI 即可。

## 4. 启动顺序（三个终端，工作目录分别为各节点根目录）

```powershell
# 终端 1 — 主节点
cd ...\deploy\nodes\node-admin
dotnet AgileConfig.Server.Apisite.dll

# 终端 2 — 从节点
cd ...\deploy\nodes\node-console-1
dotnet AgileConfig.Server.Apisite.dll

# 终端 3 — 从节点
cd ...\deploy\nodes\node-console-2
dotnet AgileConfig.Server.Apisite.dll
```

若使用自包含发布包，将 `dotnet AgileConfig.Server.Apisite.dll` 换为 `.\AgileConfig.Server.Apisite.exe`。

启动后在 **主节点控制台 → 节点管理** 核对三条地址是否为 `http://<本机IP>:8051` / `:8052` / `:8053`（若自动注册端口不对请手动修正）。

## 5. Nginx 统一入口（8538）

将 `deploy/nodes/nginx-8538-upstream-agileconfig.conf` 中与 **upstream**、`location ^~ /config/` 相关的片段合并到本机 Nginx 的 `conf\nginx.conf`。

**务必**使用固定前缀启动/重载，例如：

```bat
nginx.exe -p C:/nginx-1.30.0/ -c conf/nginx.conf -t
nginx.exe -p C:/nginx-1.30.0/ -c conf/nginx.conf -s reload
```

浏览器访问：`http://<本机IP>:8538/config/` —— 由 Nginx **最少连接** 负载到 8051 / 8052 / 8053。

客户端 `nodes` 建议只填 **`http://<LB>:8538/config/`**（若应用仍走根路径而非 `/config/`，需调整 Nginx `location` 与 `pathBase`）。

## 6. 更多说明

- HA 原则与拓扑见 **[../ha/README_HA.md](../ha/README_HA.md)**。
- 目录 `shared/` 曾用于 SQLite 演示；改用 MongoDB 后**不再需要**该库文件，可保留空目录或自行清理旧 `.db` 文件。
