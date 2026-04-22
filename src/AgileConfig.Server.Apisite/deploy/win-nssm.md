# Windows：使用 NSSM 将 AgileConfig.Server.Apisite 安装为后台服务

[NSSM](https://nssm.cc/)（Non-Sucking Service Manager）可把普通控制台程序注册为 Windows 服务，进程在后台运行；通过 **I/O 重定向** 把标准输出/错误写入文件，便于排查问题。

本文以发布目录为例（按实际路径替换）：

`C:\Users\Administrator\source\repos\AgileConfig\src\AgileConfig.Server.Apisite\bin\Release\net10.0\publish`

> 说明：仓库已提供 **`install-windows-service.ps1`**（`sc create` + `dotnet` 或自包含 exe），与 NSSM 二选一即可。若你希望 **统一用 NSSM 管进程、管日志轮转、崩溃后重启策略**，可按本文操作。

---

## 前置条件

1. **管理员权限**（安装/卸载服务、写 `Program Files` 等目录）。
2. 已 **`dotnet publish -c Release`** 到上述 `publish` 目录，且该目录下存在 **`AgileConfig.Server.Apisite.exe`**（及 `appsettings.json`、`wwwroot` 等）。
3. 下载 NSSM：打开 [https://nssm.cc/download](https://nssm.cc/download)，解压后按系统位数使用 `win64\nssm.exe` 或 `win32\nssm.exe`。下文假设 NSSM 在 `C:\Tools\nssm\nssm.exe`（请改成你的路径）。

---

## 1. 准备日志目录

在发布目录下建 `logs`（与程序内 NLog 等日志目录习惯一致；NSSM 的 stdout/stderr 也可写到这里）：

```powershell
$Publish = 'C:\Users\Administrator\source\repos\AgileConfig\src\AgileConfig.Server.Apisite\bin\Release\net10.0\publish'
New-Item -ItemType Directory -Path (Join-Path $Publish 'logs') -Force | Out-Null
```

---

## 2. 安装服务（图形界面，推荐首次使用）

在 **管理员** 命令提示符或 PowerShell 中：

```powershell
& 'C:\Tools\nssm\nssm.exe' install AgileConfigServer
```

在弹出的 NSSM 窗口中配置：

| 选项卡 | 项 | 建议值 |
|--------|-----|--------|
| **Application** | Path | `...\publish\AgileConfig.Server.Apisite.exe`（完整路径） |
| **Application** | Startup directory | `...\publish`（**必须与 exe 同目录**，否则读不到 `appsettings.json`、静态文件等） |
| **Application** | Arguments | 留空（除非你要传 ASP.NET Core 的 `--urls` 等；一般写在 `appsettings.json` 的 `urls`） |
| **I/O** | Output (stdout) | 例如 `...\publish\logs\nssm-stdout.log` |
| **I/O** | Error (stderr) | 例如 `...\publish\logs\nssm-stderr.log` |
| **Details** | Display name | 例如 `AgileConfig Server` |
| **Details** | Description | 任意说明文字 |
| **Exit actions** | 默认退出动作 | 可按需选 **Restart application**（崩溃自动拉起） |

点 **Install service** 完成安装。

---

## 3. 安装服务（命令行，可脚本化）

将变量改成你的路径后执行（管理员 PowerShell）：

```powershell
$Nssm    = 'C:\Tools\nssm\nssm.exe'
$Publish = 'C:\Users\Administrator\source\repos\AgileConfig\src\AgileConfig.Server.Apisite\bin\Release\net10.0\publish'
$Exe     = Join-Path $Publish 'AgileConfig.Server.Apisite.exe'
$Logs    = Join-Path $Publish 'logs'
$Name    = 'AgileConfigServer'

New-Item -ItemType Directory -Path $Logs -Force | Out-Null

& $Nssm install $Name $Exe
& $Nssm set $Name AppDirectory $Publish
& $Nssm set $Name DisplayName 'AgileConfig Server'
& $Nssm set $Name Description 'AgileConfig configuration center (NSSM)'
& $Nssm set $Name AppStdout (Join-Path $Logs 'nssm-stdout.log')
& $Nssm set $Name AppStderr (Join-Path $Logs 'nssm-stderr.log')
# 追加写入日志（若版本支持；不支持时可在 I/O 选项卡里选 Append）
& $Nssm set $Name AppStdoutCreationDisposition 4
& $Nssm set $Name AppStderrCreationDisposition 4
```

启动并设为自动启动：

```powershell
Start-Service -Name $Name
Set-Service -Name $Name -StartupType Automatic
```

查看状态：

```powershell
Get-Service -Name $Name
```

---

## 4. 与直接运行 `.\AgileConfig.Server.Apisite.exe` 的对应关系

- 在 `publish` 目录下双击或命令行运行 exe，控制台会挂在前台；**NSSM 以 LocalSystem 或你指定的账户在后台启动同一 exe**，不占用当前会话窗口。
- **Startup directory** 必须设为 `publish`，与你在该目录执行 `.\AgileConfig.Server.Apisite.exe` 时的工作目录一致。
- 应用在 `appsettings.json` 里配置的 **`urls`**、**`db`**、**`adminConsole`**、**`cluster`** 等与是否用 NSSM **无关**；高可用请勿各节点独立 SQLite，参见 `ha/README_HA.md`。

---

## 5. 停止、卸载

```powershell
Stop-Service -Name AgileConfigServer -Force
& 'C:\Tools\nssm\nssm.exe' remove AgileConfigServer confirm
```

---

## 6. 常见问题

- **服务启动后立即退出**：先看 `logs\nssm-stderr.log` 与程序自己的 `logs` 目录；确认已安装对应版本的 **.NET 运行时**（本项目目标框架为 **net10.0**），或改用 **自包含发布** 再指向生成的 exe。
- **端口被占用**：修改 `appsettings.json` 中 `urls`，或释放占用进程后再启动服务。
- **权限写库/写日志失败**：在 NSSM **Log on** 选项卡中为服务指定有权限访问数据目录的账户（默认 LocalSystem 通常可写本机目录；网络路径需专门账户）。

若更倾向不依赖 NSSM、使用系统自带服务安装，请使用 **`deploy\install-windows-service.ps1`**，说明见 **`Service_Install.md`**。
