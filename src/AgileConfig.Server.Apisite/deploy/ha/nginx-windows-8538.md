# Windows 上用 Nginx 做 AgileConfig 入口（端口 8538）

在 **本机 Windows** 上把 Nginx 作为反向代理，对外监听 **8538**，转发到本机或多台 AgileConfig 实例（默认 `http://127.0.0.1:8050`）。管理控制台与客户端长连接均经此端口进入，**须保留 WebSocket 相关 `proxy_set_header`**（已写在示例配置中）。

示例配置文件：**[nginx-windows-agileconfig-8538.conf](./nginx-windows-agileconfig-8538.conf)**（完整 `nginx.conf`，可直接替换 Nginx 安装目录下的 `conf\nginx.conf`）。

---

## 1. 准备 Nginx（Windows）

1. 打开 [https://nginx.org/en/download.html](https://nginx.org/en/download.html)，下载 **Stable version** 的 **Windows** 压缩包（如 `nginx-1.xx.x.zip`）。
2. 解压到无中文、无空格的路径（示例：`D:\tools\nginx-1.26.3`）。
3. 备份 `conf\nginx.conf`，再用仓库中的 `nginx-windows-agileconfig-8538.conf` **整文件替换** `conf\nginx.conf`。
4. 用记事本或编辑器打开 `conf\nginx.conf`，在 `upstream agileconfig_backend` 中确认：
   - 单机本机：`server 127.0.0.1:8050;` 与 AgileConfig 的 `urls`（如 `http://*:8050`）一致。
   - 多机：增加多行 `server IP:8050;`。

---

## 2. 启动 AgileConfig

先启动 **AgileConfig.Server.Apisite**（本机 `8050` 或你在 upstream 里写的端口），浏览器直连 `http://127.0.0.1:8050` 能打开管理端后再测 Nginx。

---

## 3. 启动 / 重载 Nginx（务必带 `-p` 前缀目录）

Windows 版若在**任意目录**直接执行 `nginx` 或 `nginx -s reload`，会把**当前工作目录**当成安装前缀，去加载 `当前目录\conf\nginx.conf`，出现 `CreateFile() "C:\Users\xxx\conf\nginx.conf" failed`，且 worker 仍沿用**错误/旧配置**，表现为 **反向代理不生效**、`/config/` 落到静态 `root` 找 `config\index.html` 等。

正确做法：**始终指定安装目录**（以下以 `C:\nginx-1.30.0` 为例，请改成你的解压路径）：

```bat
cd /d C:\nginx-1.30.0
nginx.exe -p C:/nginx-1.30.0/ -c conf/nginx.conf
```

- 改配置后重载：`nginx.exe -p C:/nginx-1.30.0/ -c conf/nginx.conf -s reload`
- 停止：`nginx.exe -p C:/nginx-1.30.0/ -c conf/nginx.conf -s stop`
- 检查语法：`nginx.exe -p C:/nginx-1.30.0/ -c conf/nginx.conf -t`

若已复制仓库提供的 **`nginx-start.cmd` / `nginx-reload.cmd` / `nginx-stop.cmd`** 到 Nginx 根目录，可双击或在 CMD 中执行它们，避免忘写 `-p`。

若 `start nginx` 无反应或瞬间退出，查看安装目录下 `logs\error.log`。常见原因：**8538 已被占用**、或 `conf\nginx.conf` 语法错误。

---

## 4. 防火墙放行 8538

首次从其它机器访问本机 8538 时，在 **Windows Defender 防火墙** 中放行 **入站 TCP 8538**（或使用图形界面「高级设置」新建规则）。

---

## 5. 验证

- 浏览器访问：`http://127.0.0.1:8538`（或 `http://<本机IP>:8538`），应出现与直连后端一致的 AgileConfig 管理界面。
- 客户端：将 `nodes` 配为 `http://<对客户端可达的IP或主机名>:8538`（经 LB 时只写 LB 地址即可）。

---

## 6. 与 Linux 示例的关系

- Linux 多节点场景下片段配置见 [nginx-lb.conf](./nginx-lb.conf)（原示例 `listen 8050`，可按需改为 8538）。
- 完整 HA 步骤见 [HA-Deploy.md](./HA-Deploy.md)。
