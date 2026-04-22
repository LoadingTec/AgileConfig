#Requires -RunAsAdministrator
<#
.SYNOPSIS
  在 Windows 上安装 MongoDB Community Server（当前渠道最新稳定版，经 winget 为 MongoDB.Server）。

.DESCRIPTION
  - 优先使用 winget 静默安装，安装后默认注册为 Windows 服务「MongoDB」，监听 27017。
  - 若未安装 winget，请从 https://www.mongodb.com/try/download/community 下载 MSI 后按官方文档静默安装。

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\install-mongodb-windows.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host '=== AgileConfig 前置：安装 MongoDB Community Server ===' -ForegroundColor Cyan

$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) {
    throw '未找到 winget。请安装「应用安装程序」/ App Installer，或手动下载 MongoDB MSI：https://www.mongodb.com/try/download/community'
}

Write-Host '正在通过 winget 安装 MongoDB.Server（静默，接受协议）...'
& winget install --id MongoDB.Server --source winget --accept-package-agreements --accept-source-agreements -e --silent
if ($LASTEXITCODE -ne 0) {
    throw "winget 安装失败，退出码: $LASTEXITCODE"
}

Write-Host ''
Write-Host '安装完成。正在检查服务...' -ForegroundColor Green
Start-Sleep -Seconds 2
$svc = Get-Service -Name MongoDB -ErrorAction SilentlyContinue
if ($svc) {
    Write-Host "  服务名: MongoDB  状态: $($svc.Status)"
    if ($svc.Status -ne 'Running') {
        Start-Service -Name MongoDB
        Write-Host '  已尝试启动 MongoDB 服务。'
    }
}
else {
    Write-Warning '未找到名为 MongoDB 的服务（部分安装包服务名可能不同）。请在 services.msc 中确认。'
}

Write-Host ''
Write-Host '连接串示例（与 deploy/nodes 下 appsettings 一致，无认证本地）：' -ForegroundColor Cyan
Write-Host '  mongodb://127.0.0.1:27017/AgileConfig'
Write-Host ''
Write-Host '从旧 SQLite 迁移数据可使用：deploy\ha\migrate-sqlite-to-mongodb.ps1' -ForegroundColor Yellow
