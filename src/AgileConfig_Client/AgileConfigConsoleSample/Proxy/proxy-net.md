# 同一局域网：代理终端（CLI）上网方案

面向「一台机器跑代理入站，同网段其他电脑/终端走这台机器出网」的场景。浏览器走 PAC 见同目录 [README.md](./README.md)；本文只讲**命令行与系统环境变量**。

## 前提

1. **代理机**（跑 v2ray 等）：入站 `listen` 为 `0.0.0.0`，端口与 [v2ray-inbound-snippet.json](./v2ray-inbound-snippet.json) 一致（示例 HTTP `10809`）。仅本机可用时请改为监听局域网或 `0.0.0.0` 并在防火墙放行。
2. **客户端机**：与代理机在同一二层/三层网段，能 `ping` 通代理机内网 IP（如 `192.168.1.10`）。
3. **协议**：HTTP 入站时，多数工具用 `http://IP:端口`；若使用 SOCKS5 入站，则 URL 形如 `socks5://IP:端口`（以实际配置为准）。

## 核心思路

终端里大部分工具认环境变量（小写为主，部分也认大写）：

| 变量 | 作用 |
|------|------|
| `http_proxy` / `HTTP_PROXY` | HTTP 请求 |
| `https_proxy` / `HTTPS_PROXY` | HTTPS 请求（常设成与 http 相同） |
| `all_proxy` / `ALL_PROXY` | 部分工具「所有协议」走代理（SOCKS 时常用） |
| `no_proxy` / `NO_PROXY` | 不走代理的地址列表，逗号分隔 |

代理 URL 示例（HTTP 入站、代理机 `192.168.1.10`、端口 `10809`）：

```text
http://192.168.1.10:10809
```

`no_proxy` 建议至少包含本机与内网，避免访问局域网服务误走代理：

```text
localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12
```

（具体网段按你环境裁剪。）

## Linux / macOS（当前 shell 会话）

```bash
export http_proxy="http://192.168.1.10:10809"
export https_proxy="http://192.168.1.10:10809"
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$https_proxy"
export no_proxy="localhost,127.0.0.1,192.168.0.0/16"
export NO_PROXY="$no_proxy"
```

写入 `~/.bashrc` / `~/.zshrc` 可长期生效；换代理机 IP 时改一处即可。

## Windows（PowerShell 当前用户持久）

```powershell
[System.Environment]::SetEnvironmentVariable("http_proxy", "http://192.168.1.10:10809", "User")
[System.Environment]::SetEnvironmentVariable("https_proxy", "http://192.168.1.10:10809", "User")
[System.Environment]::SetEnvironmentVariable("no_proxy", "localhost,127.0.0.1,192.168.0.0/16", "User")
```

新开终端后生效。仅当前窗口临时设置可用：

```powershell
$env:http_proxy="http://192.168.1.10:10809"
$env:https_proxy="http://192.168.1.10:10809"
```

## 常见工具补充

- **Git**：除环境变量外可单独指定  
  `git config --global http.proxy http://192.168.1.10:10809`  
  `git config --global https.proxy http://192.168.1.10:10809`  
  取消：`git config --global --unset http.proxy`（https 同理）。
- **npm / yarn**：可用 `npm config set proxy` / `https-proxy`，或依赖上述环境变量（视版本而定）。
- **curl**：`curl -x http://192.168.1.10:10809 https://example.com`  
  若已设 `https_proxy`，直接 `curl` 即可。
- **Docker（拉镜像）**：在 Docker Desktop 或 `daemon.json` 里配置 HTTP 代理，指向同一 `http://代理机IP:端口`；与终端环境变量是两套配置。
- **无视环境变量的程序**：可用 **proxychains**（Linux）或同类工具强制走 SOCKS/HTTP，需在代理机开放对应协议端口。

## 防火墙与安全

- **同局域网**：在代理机系统防火墙放行入站端口（如 `10809`），来源可限制为内网网段。
- **不要**把无认证 HTTP 代理暴露到公网；内网也建议固定 IP 段、必要时加认证或改用 VPN。

## 与 PAC 的分工

| 场景 | 推荐 |
|------|------|
| 浏览器、系统「使用设置脚本」 | PAC URL + `serve-pac` / Web 托管 |
| 终端、CI、ssh 到远端再执行命令 | 环境变量 `http_proxy` / `https_proxy` 或各工具独立配置 |

同一台代理机可同时提供：v2ray 入站（终端用）+ PAC 静态页（浏览器用），端口不同即可。

## 快速自检

在**客户端机**执行（替换为你的代理机 IP 与端口）：

```bash
curl -x http://192.168.1.10:10809 -I https://www.example.com
```

若返回 HTTP 头则说明链路可达；再试不设 `-x` 但已 `export` 代理变量，验证环境变量是否被当前 shell 识别。
