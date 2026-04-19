# 实践：从 SQLite 迁移到 MongoDB

本文说明在 **AgileConfig 服务端** 将存储从 **SQLite**（如 `agile_config.db` / `Data Source=...`）迁到 **MongoDB** 时的推荐做法。除 **一键表级迁移工具**（见第 4 节）外，仍可通过**控制台导出/导入 JSON** 等方式按需迁移。

---

## 1. 何时需要迁移

| 场景 | 说明 |
|------|------|
| **高可用 / 多节点** | HA 要求共享关系库或 MongoDB 等，SQLite 不适合多实例共写。 |
| **集中运维与备份** | MongoDB 集群、副本集、备份策略更易与现有中间件统一。 |
| **规模与并发** | 配置项、发布记录、日志量大时，可评估迁到 MongoDB。 |

迁移前请阅读 [HA-Deploy.md](./HA-Deploy.md) 中与共享存储、多节点相关的原则。

---

## 2. 服务端配置约定

- 配置键仍为 `db:provider` / `db:conn`（或 Linux 环境文件中的 `db__provider` / `db__conn`）。
- MongoDB 时 **`db:provider`** 取值为 **`mongodb`**（小写，与 [README.md](../../../../README.md) 中 dbprovider 说明一致）。
- 连接串为 MongoDB 标准 URI，驱动会解析库名；若 URI 中**未指定数据库名**，服务端逻辑会使用默认库名 **`AgileConfig`**（见 `MongodbAccess` 实现）。

示例（请按实际账号、认证库修改）：

```text
mongodb://agileconfig:YourPassword@192.168.1.50:27017/AgileConfig
```

使用 `admin` 用户且认证库为 `admin` 时常见写法：

```text
mongodb://admin:YourPassword@192.168.1.50:27017/AgileConfig?authSource=admin
```

在 MongoDB 上预先创建用户并授予目标库的读写权限；**无需**手工建集合，应用首次写入时会按实体创建集合（与现有 MongoDB 仓储实现一致）。

---

## 3. 迁移策略概览

**不存在**「把 `agile_config.db` 文件直接导入 MongoDB」的官方路径：SQLite 与 MongoDB 的表/集合模型不同，应按下述**业务数据迁移**思路操作。

| 策略 | 适用 | 说明 |
|------|------|------|
| **A. 配置 JSON 导出/导入（推荐）** | 已有控制台、应用与配置较多 | 旧实例保持 SQLite 运行，在控制台按应用、环境导出 JSON，新实例连 MongoDB 后重建应用并导入。 |
| **B. 小规模重建** | 应用少、配置可手工重做 | 新 MongoDB 实例启动服务，走初始化向导，手工创建应用与配置项。 |
| **C. 自研脚本调 API** | 需批量自动化 | 基于 [Restful API](https://github.com/dotnetcore/AgileConfig/wiki/Restful-API) 从旧节点读、向新节点写（需处理认证与权限）。 |
| **D. 表级一键迁移（本仓库）** | 可停服或只读库、已安装 .NET SDK | 使用 `AgileConfig.Tools.MigrateSqliteToMongo` 将 SQLite 中 `agc_*` 表数据按实体写入 MongoDB 集合（见下文第 4 节）。 |

下文 **第 4 节** 为推荐的一键迁移；**第 5 节** 详述策略 A（与 Web 管理端 `ExportJson` / `SaveJson` / `PreViewJsonFile` 等能力一致）。

---

## 4. 一键迁移工具（SQLite 全表 → MongoDB）

### 4.1 原理与范围

- **项目路径**：`src/AgileConfig.Tools.MigrateSqliteToMongo`（已加入解决方案）。
- **行为**：用 FreeSql 读取 SQLite 中 AgileConfig 各业务表，按与服务端相同的 **实体类型** 写入 MongoDB；集合名为类型名（如 `App`、`Config`、`User`），与 `MongodbAccess<T>` 约定一致。
- **迁移实体顺序**：`Role` → `Function` → `User` → `App` → `Setting` → `ServerNode` → `AppInheritanced` → `UserRole` → `UserAppAuth` → `RoleFunction` → `Config` → `ConfigPublished` → `PublishTimeline` → `PublishDetail` → `ServiceInfo` → `SysLog`。

### 4.2 前提

- 安装与仓库一致的 **.NET SDK**（当前目标框架为 **net10.0**）。
- **停止** 对源库的写入（建议停止 AgileConfig 服务后，**复制** `agile_config.db` 副本，对副本执行迁移更安全）。
- 目标 MongoDB 已创建用户与权限；URI 中库名与后续服务端 `db:conn` 一致。

### 4.3 包装脚本（推荐）

在仓库内执行（脚本从 `deploy/ha` 解析仓库根目录）：

**Windows（PowerShell）**

```powershell
cd src\AgileConfig.Server.Apisite\deploy\ha
.\migrate-sqlite-to-mongodb.ps1 -Sqlite 'Data Source=C:\path\agile_config.db' -Mongo 'mongodb://127.0.0.1:27017/AgileConfig' -DryRun
.\migrate-sqlite-to-mongodb.ps1 -Sqlite 'Data Source=C:\path\agile_config.db' -Mongo 'mongodb://127.0.0.1:27017/AgileConfig' -Drop
```

**Linux / macOS**

```bash
cd src/AgileConfig.Server.Apisite/deploy/ha
bash migrate-sqlite-to-mongodb.sh --sqlite 'Data Source=/opt/agileconfig/agile_config.db' \
  --mongo 'mongodb://127.0.0.1:27017/AgileConfig' --dry-run
bash migrate-sqlite-to-mongodb.sh --sqlite 'Data Source=/opt/agileconfig/agile_config.db' \
  --mongo 'mongodb://127.0.0.1:27017/AgileConfig' --drop
```

参数说明：

| 参数 | 说明 |
|------|------|
| `--sqlite` / `-Sqlite` | SQLite 连接串，如 `Data Source=C:\app\agile_config.db` |
| `--mongo` / `-Mongo` | MongoDB URI |
| `--dry-run` / `-DryRun` | 只打印各表行数，不写 MongoDB |
| `--drop` / `-Drop` | 写入**每个**集合前先 `drop` 该集合（需同时传 `--yes`，脚本已自动附加） |

### 4.4 直接调用 `dotnet run`

```bash
dotnet run -c Release --project src/AgileConfig.Tools.MigrateSqliteToMongo/AgileConfig.Tools.MigrateSqliteToMongo.csproj -- \
  --sqlite "Data Source=./agile_config.db" \
  --mongo "mongodb://user:pass@127.0.0.1:27017/AgileConfig" \
  --drop --yes
```

### 4.5 注意事项

- **默认仅插入**：若 Mongo 中已存在相同 `_id` 的文档会报错；需要覆盖时请使用 **`--drop --yes`**（或先手工清空目标库）。
- 迁移完成后，将服务端 **`db:provider`** 设为 **`mongodb`**，**`db:conn`** 设为同一 URI，**重启** 所有节点。
- **AgileConfig 程序版本** 建议与生成 SQLite 的版本一致或兼容；大版本升级后请先 **dry-run** 并在测试库验证。
- 若 Mongo 中已有**同名集合**且未使用 `--drop`，可能产生重复键错误；生产环境务必先在**空库或备份库**上演练。

---

## 5. 推荐实践：策略 A（并行环境 + 导出/导入）

### 5.1 迁移前准备

1. **全量备份 SQLite**  
   停止写入或短暂停服务后，复制部署目录下的 `*.db` 文件到安全位置，便于回滚。

2. **准备 MongoDB**  
   创建数据库与用户，确认网络与防火墙允许 AgileConfig 服务器访问。

3. **准备新服务端部署目录**  
   与线上一致版本；`appsettings.json`（或环境变量）中配置：

   ```json
   "db": {
     "provider": "mongodb",
     "conn": "mongodb://user:password@host:27017/AgileConfig"
   }
   ```

4. **保留旧实例**  
   在切换 DNS/负载均衡之前，旧 SQLite 实例继续运行，仅用于导出与对照。

### 5.2 在新实例（MongoDB）上完成初始化

1. 启动连接 **MongoDB** 的新节点（可先单机、不加入 HA）。
2. 浏览器打开管理控制台，完成 **超级管理员** 等首次初始化（空库上的初始化与 SQLite 首次启动类似）。
3. 在 **应用管理** 中 **创建与线上一致的应用**（`appId`、密钥 `secret` 等建议与线上一致，避免业务客户端批量改配置；若必须轮换密钥，需同步修改所有客户端 `AgileConfig` 配置）。

### 5.3 导出配置（SQLite 旧实例）

对每个 **应用**、每个需要迁移的 **环境**（如 `PROD`、`DEV`）：

1. 登录旧实例控制台。
2. 进入该应用的配置管理界面。
3. 使用控制台提供的 **导出 JSON** 能力（对应服务端 `ExportJson`：将已维护的配置项合并为 JSON 文件下载）。

> 若存在多个环境（`db:env`），请**按环境分别**导出，避免混在一个文件中难以对应。

### 5.4 导入配置（MongoDB 新实例）

1. 登录新实例控制台，切换到目标应用与 **相同环境**。
2. 使用控制台 **导入 JSON** / **保存 JSON** 相关功能（与 `SaveJson`、`PreViewJsonFile` 等流程一致）：  
   - 可先上传预览，再写入；  
   - 注意是否使用 **补丁模式**（`isPatch`），全量替换时建议先确认空环境或备份新库。

3. 对每个应用、每个环境重复，直到与旧系统一致。

### 5.5 其他数据

| 数据类型 | 建议 |
|----------|------|
| **已发布快照 / 发布历史** | 一般随业务可接受从 MongoDB 新环境重新发布；若有审计强需求，需结合 API 或 DB 级方案自行评估。 |
| **用户、角色、权限** | 通常在 MongoDB 新库走初始化管理员后，按需重建账号与授权；不要求与 SQLite 行级一致时可手工维护。 |
| **节点列表（ServerNode）** | 切换存储后在新环境重新注册节点或手动添加（见 [README_HA.md](./README_HA.md)）。 |
| **JwtSetting / 系统设置** | 若依赖库内密钥，注意新环境首次运行后的表现；必要时在控制台或配置中显式设置 `JwtSetting:SecurityKey`（或环境变量），避免多节点密钥不一致。 |

---

## 6. 切换与 HA 对齐

1. **单机验证**：新实例 + MongoDB 上应用与配置与旧站对照无误后，再接入客户端灰度或低峰切换 `nodes`（若域名/LB 不变可不改客户端）。
2. **多节点 HA**：所有节点 `db:provider`、`db:conn` 指向**同一 MongoDB**（或同一副本集连接串），并满足 [HA-Deploy.md](./HA-Deploy.md) 中的检查项。
3. **下线旧 SQLite 实例**：确认无客户端仍指向旧节点后，保留 SQLite 备份一段时间再归档删除。

---

## 7. 验证清单

- [ ] MongoDB 用户权限正确，AgileConfig 进程可读写目标库。
- [ ] 新控制台可登录，应用列表、`appId` / `secret` 与预期一致。
- [ ] 各环境配置项数量、关键 Key 与旧系统抽样对比一致。
- [ ] 执行一次 **发布**，客户端能拉到新配置（WebSocket 正常）。
- [ ] 若使用 Nginx：升级与 [README_CN.md](../../../../README_CN.md) 中 WebSocket 要求一致。
- [ ] HA 多节点均指向同一 MongoDB，节点列表正确。

---

## 8. 常见问题

**Q：能否只改 `appsettings.json` 里的 provider 和 conn，指向 MongoDB？**  
A：可以启动空 Mongo 并初始化，但 **SQLite 里的数据不会自动出现** 在 MongoDB 中，需使用 **第 4 节一键迁移工具**、或控制台导出/导入、或 API 迁数据。

**Q：一键迁移后还需要做控制台导出/导入吗？**  
A：表级工具已拷贝实体表对应数据时，一般**不必**再按应用导 JSON；若你只信任部分数据或需跨版本裁剪，可仍以策略 A 为辅。

**Q：迁移期间客户端会断吗？**  
A：若仍连接旧 SQLite 节点，旧数据仍可用；切换到仅指向新节点后，以新库为准。建议低峰操作并做好回退（保留旧实例与 SQLite 文件）。

**Q：连接串里的数据库名写错会怎样？**  
A：数据会写到 URI 指定库（或默认 `AgileConfig`），请与备份与监控中的库名保持一致。

---

## 9. 相关文档

- [HA-Deploy.md](./HA-Deploy.md) — 高可用部署与客户端接入  
- [README_HA.md](./README_HA.md) — 架构与节点注册  
- [../Service_Install.md](../Service_Install.md) — 服务安装与 `db__*` 环境变量  
