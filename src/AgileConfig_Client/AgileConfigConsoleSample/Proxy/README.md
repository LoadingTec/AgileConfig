# v2ray + PAC 对外提供代理（实现逻辑）

## 角色划分

| 项目 | 说明 |
|------|------|
| **v2ray** | 负责提供 HTTP/SOCKS **入站**；不生成、不替代 PAC 文件内容。 |
| **PAC** | 自行编写或用工具生成后，把其中的代理地址改为**你的服务器**（IP 或域名 + 端口）。 |
| **对外** | v2ray `listen` 使用 `0.0.0.0`；客户端能访问到你的 IP/域名；PAC 文件通过 **HTTP(S)** 托管，系统/浏览器填写 PAC URL。 |

## 整体数据流

```text
浏览器 / 系统代理设置（PAC URL）
        ↓ 拉取 PAC（HTTP/HTTPS）
静态站点或本目录 serve-pac 脚本
        ↓ PAC 内返回 PROXY host:port
用户机器上的请求 → 你的服务器:入站端口 → v2ray 入站 → 后续 outbound 规则
```

## 实现步骤（逻辑顺序）

### 1. 配置 v2ray 入站（对外监听）

1. 在 v2ray 配置中增加 **HTTP** 或 **SOCKS** 入站：将 `v2ray-inbound-snippet.json` 中的**单个对象**追加到完整 `config.json` 的 `inbounds` **数组**中（该文件不是完整配置）。
2. 将 `listen` 设为 **`0.0.0.0`**，否则仅本机可连，局域网/公网无法使用。
3. 选定端口（示例为 `10809`），在防火墙或安全组中按需放行。
4. **公网暴露**时务必限制来源网段、加认证或使用 VPN，避免开放无认证 HTTP 代理。

### 2. 编写或生成 PAC

1. PAC 本质是包含 `FindProxyForURL(url, host)` 的 JavaScript。
2. 代理语句形如：`return "PROXY <你的IP或域名>:<端口>; DIRECT";`
3. 可使用同目录 **`proxy.pac.template`** 为模板，或用 **`gen-pac.ps1`** 按参数生成 `proxy.pac`。
4. 若用 v2rayN 等工具生成了 PAC，需把其中的 `127.0.0.1`（或本机地址）**全部替换**为对客户端可见的服务器地址。

### 3. 对外托管 PAC（HTTP/HTTPS）

1. 客户端（Windows「使用设置脚本」、浏览器等）需要能访问 **`http(s)://.../xxx.pac`**。
2. 任选一种方式：
   - 公司/自己的 Web 服务器：上传 `proxy.pac`，保证 URL 固定、可用。
   - 临时验证：在同目录运行 **`serve-pac.ps1`**（Windows，监听 `0.0.0.0`）；Linux 可用 **`serve-pac.sh`**（Python 简易静态服务）。
3. 将 PAC 的响应类型设为 `application/x-ns-proxy-autoconfig` 更规范（`serve-pac.ps1` 已处理）。`serve-pac.sh` 使用 Python 内置服务，`.pac` 多为通用二进制类型，一般仍可被系统使用；生产环境建议用 Nginx 等显式指定 MIME。
4. **Windows** 使用 `serve-pac.ps1` 若提示权限失败，需以管理员执行，或对前缀注册 URL ACL，例如：`netsh http add urlacl url=http://+:8080/ user=Everyone`（端口与策略请按环境收紧）。

### 4. 客户端配置

- **Windows**：设置 → 网络和 Internet → 代理 → **使用设置脚本** → 填入 PAC 的完整 URL。
- **浏览器**：在代理/扩展中填写 PAC URL（依产品而定）。

## 本目录文件说明

| 文件 | 作用 |
|------|------|
| `v2ray-inbound-snippet.json` | 可复制合并到完整 `config.json` 的入站片段（HTTP 示例）。 |
| `proxy.pac.template` | PAC 模板，`{{PROXY_HOST}}` / `{{PROXY_PORT}}` 占位。 |
| `gen-pac.ps1` | 根据主机名与端口生成 `proxy.pac`。 |
| `serve-pac.ps1` | Windows 下在 `0.0.0.0` 上简易托管当前目录（便于下发 PAC）。 |
| `serve-pac.sh` | Linux/macOS 下用 Python 在 `0.0.0.0` 托管当前目录。 |

## 安全提示

- 仅内网使用时，优先绑定内网 IP 或防火墙只允许内网访问入站端口。
- 公网不要使用无认证的裸 HTTP 代理；合规场景请使用带认证、TLS 或专线/VPN。
