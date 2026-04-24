# balance-api-go

与 `BalanceNgSvrApi` 相同：`GET /api/health`、`POST /api/submit`（`multipart/form-data`：`name`、可选 `remark`、可选 `file`）。上传保存在 `uploads/`。

- 默认监听 **`:5093`**（即本机所有网卡上的 5093）
- **端口**：环境变量 `PORT` 填数字即可，如 `5093`（PowerShell：`$env:PORT='5093'`）

## 环境要求

- **Go 1.21+**（[官方安装包](https://go.dev/dl/)），安装后新开终端执行 `go version` 确认 PATH。

`start.ps1` 会：刷新注册表 **PATH**、在常见目录（如 `Program Files\Go\bin`、`%LOCALAPPDATA%\Programs\Go\bin`、Scoop shims）查找 **`go.exe`**；若仍没有，会尝试 **`winget install --source winget GoLang.Go`**（跳过易出证书问题的 **msstore** 源；可能需管理员）。仅安装可运行 **`.\install-go.ps1`**，完成后**新开终端**再执行 `.\start.ps1`。

## 环境初始化（Windows）

**一键启动**：

```powershell
cd balance-api-go
.\start.ps1
```

**手动**：

```powershell
cd balance-api-go
go run .
```

## 编译可执行文件

```powershell
go build -o balance-api-go.exe .
.\balance-api-go.exe
```

（Linux/macOS 可去掉 `.exe`。）

## 自检

```powershell
curl.exe http://127.0.0.1:5093/api/health
```
