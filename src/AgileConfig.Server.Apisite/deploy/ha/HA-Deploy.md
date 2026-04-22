# AgileConfig 高可用（HA）部署指南

本文在现有架构设计基础上，给出**从共享数据库到多节点、再到业务应用接入**的完整部署顺序与示例。概念与拓扑详见同目录下的 [README_HA.md](./README_HA.md)；单机/系统服务安装见上级目录 [Service_Install.md](../Service_Install.md)。

---

## 1. 架构与原则（摘要）

| 原则 | 说明 |
|------|------|
| **共享数据库** | 所有节点使用**同一** MySQL / PostgreSQL / SQL Server / MongoDB 等；**禁止**多节点各用 SQLite。 |
| **节点无状态** | 配置与元数据在库中；任意节点均可对外提供 API。 |
| **管理后台** | 至少 **一个** 节点 `adminConsole=true`（主节点）。 |
| **集群注册** | `cluster=true` 时适合同网段/Docker 自动注册；**跨网段**建议 `cluster=false` 并在控制台手动维护节点列表。 |
| **客户端** | `nodes` 填写应用**网络可达**的节点 URL（可多地址逗号分隔，故障时自动切换）。 |

典型拓扑（内网多节点 + 可选办公网节点 + 可选 Nginx 入口）与 [README_HA.md](./README_HA.md) 中架构图一致。

---

## 2. 部署前准备

### 2.1 网络与端口

- 节点间：均需访问**同一数据库**地址与端口。
- 客户端：能访问至少一个节点 HTTP 端口（示例常用 **8050**）。
- 防火墙：放行节点监听端口；若经 Nginx 反代，放行 Nginx 监听端口。

### 2.2 共享数据库

以 MySQL 为例（PostgreSQL 等请按项目支持的 `db:provider` 配置）：

```sql
CREATE DATABASE agileconfig_ha CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'agileconfig'@'%' IDENTIFIED BY 'YourSecurePassword';
GRANT ALL ON agileconfig_ha.* TO 'agileconfig'@'%';
FLUSH PRIVILEGES;
```

连接串示例（请替换主机、库名、账号密码）：

```text
Server=192.168.1.100;Database=agileconfig_ha;User=agileconfig;Password=YourSecurePassword;Port=3306
```

确保**每一个** AgileConfig 节点所在网络都能访问该数据库。

### 2.3 配置文件模板

- 服务端节点：`appsettings.ha-template.json`（本目录）
- systemd 单元示例：`agileconfig-ha.service`（本目录）
- Nginx 负载均衡：`nginx-lb.conf`（本目录）

---

## 3. 推荐部署顺序

按下面顺序执行，可避免「无主节点、节点未注册、库不一致」等问题。

### 步骤 A：部署第一个节点（主节点，带管理后台）

1. 使用与生产一致的发布包（Linux 建议 `linux-x64` 发布或自包含）。
2. 配置**相同**的 `db:provider`、`db:conn`（或 systemd / 环境变量中的 `db__provider`、`db__conn`，与 [Service_Install.md](../Service_Install.md) 说明一致）。
3. 设置：
   - `adminConsole` = **true**
   - `urls` = 实际监听，如 `http://*:8050`
   - `cluster` = 按网络选择（同网段可 `true`）
4. 启动服务后，浏览器访问 `http://<主节点IP>:8050`，完成管理员初始化（如配置 `saPassword` 等）。

**快捷方式（交互安装）**

- Windows（管理员 PowerShell）：`deploy/install-windows-service.ps1`，选择 **主节点**。
- Linux：`sudo bash deploy/install-linux-service.sh`，选择 **主节点**，填写共享库连接串。

### 步骤 B：部署后续节点（从节点，可无管理界面）

1. **相同** `db:provider`、`db:conn` 与主节点。
2. 建议：
   - `adminConsole` = **false**（减少暴露面；需要时也可再开一台 admin 节点）
   - `urls` 与规划端口一致（如 `http://*:8050`）
   - 同网段自动注册：`cluster` = **true**
   - 跨网段、节点间无法互相发现：`cluster` = **false**，稍后在主节点控制台 **节点管理** 中手动添加 `http://<从节点IP>:8050`

**快捷方式**：同上脚本，选择 **从节点**。

### 步骤 C：校验节点列表

1. 登录任一 `adminConsole=true` 的节点。
2. 打开 **节点管理（Nodes）**，确认所有对外地址正确（若自动注册端口不符，例如仍为 5000，请按实际监听端口 **8050** 修正或删除后手动添加）。

### 步骤 D：（可选）Nginx / HAProxy 统一入口

- 将 `nginx-lb.conf` 中 `upstream` 的 IP 改为真实节点地址。
- **必须**保留 WebSocket 相关配置（`Upgrade`、`Connection`），否则客户端长连接无法建立。详见仓库根目录 [README_CN.md](../../../../README_CN.md) 中 Nginx 说明。

客户端可将 `nodes` 配为 **单个** 负载均衡地址，例如 `http://192.168.1.88:8050`（LB 再转发到多节点）。

- **Windows 本机实践**：以 Nginx **8538** 作为统一入口的完整 `nginx.conf` 与步骤见 [nginx-windows-8538.md](./nginx-windows-8538.md)（配置文件 [nginx-windows-agileconfig-8538.conf](./nginx-windows-agileconfig-8538.conf)）。

### 步骤 D 补充：Nginx 入口自身的高可用（可选）

`nginx-lb.conf` 解决的是 **多台 AgileConfig 节点** 的负载均衡；若只有 **一台** Nginx 对外，入口仍是单点。生产上常再对「反代层」做高可用，典型思路包括：

- **Keepalived + 虚拟 IP（VIP）**：两台（或多台）主机部署相同 Nginx 与 `upstream` 配置，通过 VRRP 漂移 **同一 VIP**；主节点故障或本机 Nginx 异常时，备机接管 VIP，客户端仍访问同一 `http(s)://VIP:端口`。
- 可配合 **健康检查脚本**（检测 `nginx` 进程或本地反代端口），在进程不可用时降低本机优先级，促使 VIP 迁移。

安装步骤、`keepalived.conf` 中 `vrrp_instance`、`virtual_ipaddress`、`priority`、与 Nginx 联动等，可参考社区整理：

- [NGINX 维护集群高可用相关方案（CSDN 示例文）](https://blog.csdn.net/gitblog_00077/article/details/139110355)

与本仓库的关系：AgileConfig 侧仍为多节点 + 共享库；**客户端 `nodes` 填对业务可见的 VIP 或域名**（解析到 VIP）即可，无需改应用协议。若使用 HTTPS，证书应签在客户端实际访问的域名或 VIP 对应主机名上（按你们证书策略）。

---

## 4. 配置项对照（服务端）

| 配置项 | 主节点（至少 1 台） | 从节点（建议） |
|--------|---------------------|----------------|
| `adminConsole` | `true` | `false` |
| `cluster` | 同网段可 `true` | 同网段 `true`；跨网段 `false` + 手动加节点 |
| `db:provider` / `db:conn` | 全员一致 | 全员一致 |
| `urls` | 如 `http://*:8050` | 与规划一致 |

环境变量与 JSON 键的对应关系（Linux 常用）：

- 单元文件：`Environment=db:provider=...` / `Environment=db:conn=...`
- 或使用 `install-linux-service.sh` 生成的 `/etc/agileconfig/agileconfig.env` 中的 `db__provider` / `db__conn`

---

## 5. 接入高可用环境：业务应用（.NET 客户端）

以下示例适用于通过 **NuGet `AgileConfig.Client`** 接入的 ASP.NET Core 应用（与 [README_CN.md](../../../../README_CN.md) 一致）。

### 5.1 安装包

```powershell
dotnet add package AgileConfig.Client
```

### 5.2 `appsettings.json` 示例

将 `nodes` 改为**当前应用能访问**的地址：可多节点逗号分隔，或单一 Nginx 入口。

完整示例见本目录 [client-appsettings-sample.json](./client-appsettings-sample.json)。

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning"
    }
  },
  "AgileConfig": {
    "appId": "your_app_id",
    "secret": "your_app_secret",
    "nodes": "http://192.168.1.10:8050,http://192.168.1.11:8050,http://10.0.1.5:8050",
    "name": "client_name",
    "tag": "tag1",
    "env": "PROD"
  }
}
```

**按部署位置选择 `nodes`：**

| 应用所在网络 | 建议 `nodes` |
|----------------|--------------|
| 仅内网 | 只填内网节点（或内网 LB 地址） |
| 仅办公网 | 只填办公网可达节点（或办公网 LB） |
| 需跨网冗余 | 内网 + 办公网多个 URL（逗号分隔） |

> 在控制台为应用创建应用后，将真实的 `appId`、`secret` 填入上述配置。

### 5.3 在宿主中注册客户端

在 `Program.cs` / `Host` 构建处增加 `UseAgileConfig()`（与官方 README 一致）：

```csharp
public static IHostBuilder CreateHostBuilder(string[] args) =>
    Host.CreateDefaultBuilder(args)
        .UseAgileConfig()
        .ConfigureWebHostDefaults(webBuilder =>
        {
            webBuilder.UseStartup<Startup>();
        });
```

### 5.4 读取配置

- 继续使用 `IConfiguration`、`IOptions<T>`；或注入 `IConfigClient` 按 key 读取。
- 某台节点宕机时，客户端会尝试列表中其他节点；全部不可达时行为见下文「可用性说明」。

### 5.5 生产环境补充说明

- **.NET Framework** 客户端请使用 [AgileConfig.Client4FR](https://github.com/kklldog/AgileConfig.Client4FR)，勿混用当前 Client 以免死锁等问题（见 README_CN）。
- **经 Nginx 反代**：必须配置 WebSocket 转发，否则无法建立长连接。
- **HTTPS**：节点与客户端 `nodes` 中的 scheme 需与实际一致（`https://...`），并处理证书信任（开发环境可参考服务端 `alwaysTrustSsl` 相关说明，生产建议正规证书）。

### 5.6 使用环境变量覆盖（可选）

若不希望把敏感信息写入文件，可在部署平台为进程设置环境变量（具体前缀以 Client 版本文档为准，常见为配置系统的 `AgileConfig__*` 形式），例如：

```text
AgileConfig__nodes=http://node1:8050,http://node2:8050
AgileConfig__appId=your_app_id
AgileConfig__secret=your_app_secret
```

（是否支持以运行环境为准；不确定时优先使用 `appsettings.json` + 密钥保管库。）

---

## 6. 验证清单

- [ ] 数据库仅一份，所有节点连接串一致。
- [ ] 至少一台节点 `adminConsole=true`，且可打开管理 UI。
- [ ] **节点管理** 中列表完整、URL 与监听端口一致（含 8050 等非默认端口）。
- [ ] 从第二台节点起，接口与健康检查在直连 IP 下可访问。
- [ ] 测试客户端：`nodes` 只填其中一台时可用；故意停一台后仍可拉取配置（多地址或 LB 场景）。
- [ ] 若使用 Nginx：WebSocket 连通（浏览器或客户端日志无长连失败）。
- [ ] 若对入口做了 **双机 Nginx + Keepalived/VIP**：主备切换后，同一 VIP 下 WebSocket 与控制台仍可用。

---

## 7. 可用性与故障影响（摘要）

| 场景 | 影响 |
|------|------|
| 单节点故障 | 客户端切换其他 `nodes`，业务读配置通常无感。 |
| 全部节点短时不可达 | 客户端多使用本地缓存启动；细节以 Client 版本行为为准。 |
| 数据库故障 | 无法更新中心配置；已下发缓存仍可能被应用使用。 |
| 无主节点或无法登录控制台 | 不影响已接入客户端读配置；无法做后台变更。 |

更细的说明见 [README_HA.md](./README_HA.md) 第七节。

---

## 8. 从 SQLite 迁移到 MongoDB

单机或小型环境常用 SQLite；要上 **HA** 或统一使用 MongoDB 时，需把配置中心数据迁到 MongoDB。仓库**无** SQLite→MongoDB 一键转换，推荐 **并行部署新实例 + 控制台按应用/环境导出 JSON 再导入** 的路径，详见：

**[Migrate-Sqlite-To-Mongodb.md](./Migrate-Sqlite-To-Mongodb.md)**

---

## 9. 相关文件

| 文件 | 用途 |
|------|------|
| [README_HA.md](./README_HA.md) | 架构、节点注册、清单与故障说明 |
| [Migrate-Sqlite-To-Mongodb.md](./Migrate-Sqlite-To-Mongodb.md) | SQLite 迁 MongoDB 实践（导出/导入、切换与验证） |
| [../Service_Install.md](../Service_Install.md) | Windows / Linux 服务安装与主从脚本 |
| [appsettings.ha-template.json](./appsettings.ha-template.json) | 服务端 HA 模板 |
| [agileconfig-ha.service](./agileconfig-ha.service) | systemd 模板 |
| [nginx-lb.conf](./nginx-lb.conf) | Nginx 负载均衡 + WebSocket |
| [nginx-windows-8538.md](./nginx-windows-8538.md) | Windows 上 Nginx 入口 **8538** 实践步骤 |
| [nginx-windows-agileconfig-8538.conf](./nginx-windows-agileconfig-8538.conf) | Windows 用完整 `nginx.conf` 示例（`listen 8538`） |
| [client-appsettings-sample.json](./client-appsettings-sample.json) | 客户端 `appsettings` 样例 |
| [../nodes/README.md](../nodes/README.md) | Windows 三节点（8051/8052/8053）+ Nginx 负载示例 |
