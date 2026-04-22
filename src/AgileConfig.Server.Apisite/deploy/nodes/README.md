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

## 4. 控制台启动三节点

仓库内路径（按你本机克隆位置调整盘符）：

| 节点 | 目录 | 监听 |
|------|------|------|
| 主（管理 UI） | `AgileConfig.Server.Apisite\deploy\nodes\node-admin` | **8051** |
| 从 | `...\deploy\nodes\node-console-1` | **8052** |
| 从 | `...\deploy\nodes\node-console-2` | **8053** |

**前置：** Windows 服务 **MongoDB** 已启动（`Get-Service MongoDB`），三节点 `db:conn` 指向同一 MongoDB 库 **`AgileConfig`**。

### 方式 A：三个 PowerShell 窗口（推荐先看日志）

```powershell
# 终端 1 — 主节点（先开，便于首次初始化）
cd C:\Users\Administrator\source\repos\AgileConfig\src\AgileConfig.Server.Apisite\deploy\nodes\node-admin
dotnet AgileConfig.Server.Apisite.dll

# 终端 2 — 从节点
cd C:\Users\Administrator\source\repos\AgileConfig\src\AgileConfig.Server.Apisite\deploy\nodes\node-console-1
dotnet AgileConfig.Server.Apisite.dll

# 终端 3 — 从节点
cd C:\Users\Administrator\source\repos\AgileConfig\src\AgileConfig.Server.Apisite\deploy\nodes\node-console-2
dotnet AgileConfig.Server.Apisite.dll
```

若使用自包含发布包，将 `dotnet AgileConfig.Server.Apisite.dll` 换为 `.\AgileConfig.Server.Apisite.exe`。

### 方式 B：一键开三个新窗口

在 **`deploy\nodes`** 目录执行：

```powershell
.\start-three-nodes.ps1
```

会在三个独立 PowerShell 窗口中各跑一个节点（仍依赖本机已安装 `dotnet` 且在 PATH 中）。

---

## 5. 打开主节点管理后台

三节点 `pathBase` 为空时，**直连主节点**（带界面、端口 8051）：

| 说明 | URL |
|------|-----|
| 管理前端（推荐书签） | **http://localhost:8051/ui#/** |
| 同机浏览器也可用 | **http://127.0.0.1:8051/ui#/** |
| 局域网其它机器 | 将上表中的 `localhost` 换成本机 IPv4，例如 `http://192.168.201.51:8051/ui#/` |

首次部署若库中尚无超级管理员，会跳转到初始化密码页（`/ui#/user/initpassword`）。

登录后在 **节点管理** 中核对三条节点地址端口是否为 **8051 / 8052 / 8053**（`cluster=true` 时可能自动注册；若端口不对请手动改或删除后添加）。

---

## 6. 开发者接入（.NET 客户端，多节点 `nodes`）

在配置中心为应用创建应用后，将控制台中的 **`appId`**、**`secret`** 填入业务应用。客户端需能访问至少一个节点 URL；多节点时 **英文逗号** 分隔，故障时 Client 会切换。

### 6.1 直连三节点（不经 Nginx）

本机开发示例（`appsettings.json` 中 `AgileConfig` 节）：

```json
{
  "AgileConfig": {
    "appId": "在控制台创建应用后复制",
    "secret": "在控制台创建应用后复制",
    "nodes": "http://127.0.0.1:8051,http://127.0.0.1:8052,http://127.0.0.1:8053",
    "name": "your_service_name",
    "tag": "tag1",
    "env": "DEV"
  }
}
```

局域网内其它机器上的应用应写 **对该机路由可达的 IP**，例如：

```text
nodes = "http://192.168.201.51:8051,http://192.168.201.51:8052,http://192.168.201.51:8053"
```

### 6.2 经 Nginx 统一入口（与当前 `location /config/` 一致）

若 Nginx 将 **`/config/`** 反代到 upstream（8051/8052/8053），且服务端 **`pathBase` 仍为默认空**（未在 `appsettings.json` 配置 `/config`），则浏览器走 LB 时路径常为 **`http://<负载均衡机IP>:8538/config/ui#/`**；**.NET 客户端 `nodes`** 是否只写 LB 单地址取决于客户端与反代路径是否一致，常见写法：

- **只配 LB 单地址（由 LB 转发到健康节点）**：

```json
"nodes": "http://192.168.201.51:8538/config"
```

（末尾是否带 `/` 以你环境为准；须与 Nginx `proxy_pass` 及前端实际路径一致。）

- **不配 pathBase 时更稳妥**：客户端仍使用 **6.1 多端口列表**，由 DNS/运维统一改 IP。

### 6.3 环境变量覆盖（可选）

```text
AgileConfig__nodes=http://127.0.0.1:8051,http://127.0.0.1:8052,http://127.0.0.1:8053
AgileConfig__appId=your_app_id
AgileConfig__secret=your_app_secret
```

宿主中注册：`Host.CreateDefaultBuilder(args).UseAgileConfig()`（与官方 README 一致）。

可复制模板：**[developer-client-appsettings.sample.json](./developer-client-appsettings.sample.json)**。更多说明见 **[../ha/client-appsettings-sample.json](../ha/client-appsettings-sample.json)** 与 **[../ha/HA-Deploy.md](../ha/HA-Deploy.md)** 第五节。

---

## 7. Nginx 统一入口（8538）

将 `deploy/nodes/nginx-8538-upstream-agileconfig.conf` 中与 **upstream**、`location ^~ /config/` 相关的片段合并到本机 Nginx 的 `conf\nginx.conf`。

**务必**使用固定前缀启动/重载，例如：

```bat
nginx.exe -p C:/nginx-1.30.0/ -c conf/nginx.conf -t
nginx.exe -p C:/nginx-1.30.0/ -c conf/nginx.conf -s reload
```

浏览器访问：`http://<本机IP>:8538/config/` —— 由 Nginx **最少连接** 负载到 8051 / 8052 / 8053。

客户端 `nodes` 建议只填 **`http://<LB>:8538/config/`**（若应用仍走根路径而非 `/config/`，需调整 Nginx `location` 与 `pathBase`）。

## 8. 更多说明

- HA 原则与拓扑见 **[../ha/README_HA.md](../ha/README_HA.md)**。
- 目录 `shared/` 曾用于 SQLite 演示；改用 MongoDB 后**不再需要**该库文件，可保留空目录或自行清理旧 `.db` 文件。
