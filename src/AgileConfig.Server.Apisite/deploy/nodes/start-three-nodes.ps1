#Requires -Version 5.1
<#
.SYNOPSIS
  在三个新的 PowerShell 窗口中分别启动 node-admin、node-console-1、node-console-2。

.DESCRIPTION
  每个窗口会先 cd 到对应发布目录，再执行 dotnet AgileConfig.Server.Apisite.dll。
  请先确保 MongoDB 服务已运行，且已在主节点完成初始化（首次需单独开一个终端看日志）。

.EXAMPLE
  cd ...\AgileConfig.Server.Apisite\deploy\nodes
  .\start-three-nodes.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

$admin = Join-Path $Root 'node-admin'
$c1 = Join-Path $Root 'node-console-1'
$c2 = Join-Path $Root 'node-console-2'

foreach ($p in @($admin, $c1, $c2)) {
    if (-not (Test-Path (Join-Path $p 'AgileConfig.Server.Apisite.dll'))) {
        throw "未找到发布文件: $p\AgileConfig.Server.Apisite.dll"
    }
}

function Start-NodeWindow([string] $Title, [string] $WorkDir) {
    $cmd = @"
Set-Location -LiteralPath '$WorkDir'
Write-Host '[$Title] ' -NoNewline -ForegroundColor Cyan
Write-Host (Get-Location)
dotnet AgileConfig.Server.Apisite.dll
"@
    Start-Process powershell.exe -ArgumentList @('-NoExit', '-NoProfile', '-Command', $cmd) -WorkingDirectory $env:SystemRoot
}

Start-NodeWindow 'node-admin :8051' $admin
Start-Sleep -Milliseconds 400
Start-NodeWindow 'node-console-1 :8052' $c1
Start-Sleep -Milliseconds 400
Start-NodeWindow 'node-console-2 :8053' $c2

# 末尾 URL 使用双引号，避免部分编码/引号字符被误解析为字符串未闭合
Write-Host "Opened 3 PowerShell windows (one node each)." -ForegroundColor Green
Write-Host "Admin UI (primary, port 8051): http://localhost:8051/ui#/" -ForegroundColor Yellow
Write-Host "If using Nginx /config/ (port 8538): http://localhost:8538/config/ui#/" -ForegroundColor Yellow
