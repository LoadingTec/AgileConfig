# AgileConfig 高可用部署方案

**分步部署与客户端接入的完整流程**见同目录 [HA-Deploy.md](./HA-Deploy.md)（推荐先读该文档再对照本节架构与清单）。

## 架构概览

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                    共享数据库 (MySQL/PostgreSQL)           │
                    │            DB 需同时被内网与办公网节点访问                   │
                    └─────────────────────────────────────────────────────────┘
                                         │
                    ┌────────────────────┼────────────────────┐
                    │                    │                    │
                    ▼                    ▼                    ▼
        ┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐
        │  内网节点 1       │  │  内网节点 2       │  │  办公网节点       │
        │  adminConsole=true│  │  cluster=true     │  │  cluster=true     │
        │  :8050            │  │  :8050            │  │  :8050            │
        └─────────┬─────────┘  └─────────┬─────────┘  └─────────┬─────────┘
                  │                       │                       │
                  │        内网客户端       │        办公网客户端   │
                  └───────────┬───────────┘                       │
                              │                                    │
                    ┌─────────┴─────────┐              ┌──────────┴──────────┐
                    │  Nginx/HAProxy    │              │  办公网直接访问      │
                    │  (可选负载均衡)     │              │  或办公网 LB         │
                    └───────────────────┘              └─────────────────────┘
```

## 核心要点

| 项目 | 说明 |
|------|------|
| **数据库** | 必须使用 MySQL / PostgreSQL / SQL Server / MongoDB，**不能使用 SQLite** |
| **共享 DB** | 所有节点连接同一数据库，配置自动同步 |
| **节点无状态** | 任意节点可承担读写，客户端可连接任一节点 |
| **跨网段** | 内网与办公网节点均需能访问数据库；客户端按所在网段连接对应节点 |
| **管理控制台** | 至少一个节点设置 `adminConsole=true`，用于后台管理 |
| **cluster 模式** | `cluster=true` 时节点自动注册到节点列表（适用于同网段/Docker）；跨网段时建议手动在控制台添加节点 |

---

## 一、数据库准备

### MySQL 示例

```sql
CREATE DATABASE agileconfig_ha CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'agileconfig'@'%' IDENTIFIED BY 'YourSecurePassword';
GRANT ALL ON agileconfig_ha.* TO 'agileconfig'@'%';
FLUSH PRIVILEGES;
```

连接串示例（根据实际地址修改）：

```
Server=192.168.1.100;Database=agileconfig_ha;User=agileconfig;Password=YourSecurePassword;Port=3306
```

> 确保数据库可被内网和办公网的所有 AgileConfig 节点访问。

---

## 二、节点部署配置

### 2.1 内网节点（akdatasvr1 等）

**systemd 环境变量示例（/etc/systemd/system/agileconfig.service）：**

```ini
[Service]
# 数据库 - 使用共享 MySQL
Environment=db:provider=mysql
Environment=db:conn=Server=192.168.1.100;Database=agileconfig_ha;User=agileconfig;Password=xxx;Port=3306

# 管理控制台（至少一个节点开启）
Environment=adminConsole=true

# 集群模式（同网段可开启自动注册）
Environment=cluster=true

# 端口
Environment=urls=http://*:8050
```

### 2.2 办公网节点

与内网节点相同数据库连接，不同之处：

- 若办公网与内网不通：建议 `cluster=false`，在管理控制台中**手动添加节点**（如 `http://office-server-ip:8050`）
- 至少一个节点开启 `adminConsole=true`，便于办公网用户管理

---

## 三、节点注册说明

### 自动注册（cluster=true）

- 适用于：节点在同一网段或 Docker 环境
- 节点启动时会自动获取本机 IP 并注册到节点列表
- 注意：默认注册端口为 5000，若使用 8050，需在管理控制台手动修正或使用手动注册

### 手动注册（推荐跨网段）

1. 登录任一开启 `adminConsole=true` 的节点
2. 进入 **节点管理**（Nodes） 页面
3. 点击「添加节点」，填写：
   - 内网节点：`http://192.168.x.x:8050`
   - 办公网节点：`http://10.x.x.x:8050` 或 `http://office-hostname:8050`

---

## 四、客户端配置

客户端需配置**所有可访问的节点地址**（内网 + 办公网），客户端会随机选择连接，失败自动切换：

```json
{
  "AgileConfig": {
    "appId": "your_app",
    "secret": "xxx",
    "nodes": "http://192.168.1.10:8050,http://192.168.1.11:8050,http://10.0.1.5:8050",
    "name": "client_name",
    "env": "PROD"
  }
}
```

- 内网应用：可只写内网节点
- 办公网应用：写办公网节点（或内网节点，若网络可达）
- 跨网段应用：同时配置内网 + 办公网节点

---

## 五、负载均衡（可选）

### Nginx 示例

```nginx
upstream agileconfig_internal {
    server 192.168.1.10:8050;
    server 192.168.1.11:8050;
}

server {
    listen 8050;
    location / {
        proxy_pass http://agileconfig_internal;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

客户端可将 `nodes` 配置为负载均衡地址，实现统一入口。

若需消除 **单台 Nginx** 的单点风险，可在反代层再做 **Keepalived + VIP** 等「入口高可用」；概念与部署顺序见 [HA-Deploy.md](./HA-Deploy.md) **步骤 D 补充**，亦可参考 [CSDN：NGINX 集群高可用类实践](https://blog.csdn.net/gitblog_00077/article/details/139110355)。

---

## 六、部署检查清单

- [ ] MySQL/PostgreSQL 已创建库并授权
- [ ] 内网、办公网节点均能访问数据库
- [ ] 每个节点 `appsettings.json` 或 systemd 中配置相同 `db:provider`、`db:conn`
- [ ] 至少一个节点 `adminConsole=true`
- [ ] 跨网段时在控制台手动添加所有节点地址
- [ ] 客户端 `nodes` 包含其可访问的节点列表

---

## 七、故障切换说明

| 场景 | 影响 |
|------|------|
| 某节点下线 | 客户端自动连其他节点，无影响 |
| 管理节点下线 | 无法通过该节点维护配置，客户端无影响；可由其他 admin 节点接替 |
| 所有节点下线 | 客户端从本地缓存读取配置，应用仍可启动 |
| 数据库不可用 | 无法读写新配置，客户端继续使用已有配置直到恢复 |

---

## 八、参考文件

- `HA-Deploy.md` - 高可用分步部署与客户端接入
- `Migrate-Sqlite-To-Mongodb.md` - 从 SQLite 迁移到 MongoDB（含一键工具说明）
- `migrate-sqlite-to-mongodb.ps1` / `migrate-sqlite-to-mongodb.sh` - 调用表级迁移工具的包装脚本
- `appsettings.ha-template.json` - HA 配置模板
- `agileconfig-ha.service` - systemd 服务模板
- `nginx-lb.conf` - Nginx 负载均衡配置示例
- `nginx-windows-8538.md` / `nginx-windows-agileconfig-8538.conf` - Windows 入口端口 **8538** 的完整实践示例
