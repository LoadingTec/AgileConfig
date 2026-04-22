#Requires -Version 5.1
<#
.SYNOPSIS
  刷新当前会话 PATH，调用 mongosh 连接本机 MongoDB 并执行 CRUD 冒烟脚本。

.PARAMETER Uri
  MongoDB 连接 URI，默认 mongodb://127.0.0.1:27017/mongosh_smoke_test

.EXAMPLE
  .\run-mongosh-crud-smoke.ps1
.EXAMPLE
  .\run-mongosh-crud-smoke.ps1 -Uri 'mongodb://127.0.0.1:27017/mongosh_smoke_test'
#>
[CmdletBinding()]
param(
    [string] $Uri = 'mongodb://127.0.0.1:27017/mongosh_smoke_test'
)

$ErrorActionPreference = 'Stop'

# 合并 Machine + User PATH，使新安装的 mongosh 在当前窗口立即可用
$env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
    [System.Environment]::GetEnvironmentVariable('Path', 'User')

$mongoshCmd = Get-Command mongosh -ErrorAction SilentlyContinue
if (-not $mongoshCmd) {
    $fallback = Join-Path $env:LOCALAPPDATA 'Programs\mongosh\mongosh.exe'
    if (Test-Path -LiteralPath $fallback) {
        $mongoshExe = $fallback
    }
    else {
        throw '未找到 mongosh。请执行: winget install MongoDB.Shell --source winget'
    }
}
else {
    $mongoshExe = $mongoshCmd.Source
}

$scriptPath = Join-Path $PSScriptRoot 'mongosh-crud-smoke.js'
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "未找到脚本: $scriptPath"
}

Write-Host "mongosh: $mongoshExe" -ForegroundColor Cyan
Write-Host "URI:     $Uri" -ForegroundColor Cyan
Write-Host "script:  $scriptPath" -ForegroundColor Cyan
Write-Host ''

& $mongoshExe $Uri $scriptPath
if ($LASTEXITCODE -ne 0) {
    throw "mongosh 退出码: $LASTEXITCODE"
}
Write-Host ''
Write-Host 'run-mongosh-crud-smoke.ps1 done.' -ForegroundColor Green
