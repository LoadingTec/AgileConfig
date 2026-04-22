<#
.SYNOPSIS
  Windows 11 局域网 PAC 托管：HTTP 提供 proxy.pac，启动时列出 PAC 地址入口。
.DESCRIPTION
  - 监听 http://0.0.0.0:<Port>/ （同网段设备可访问）。
  - 浏览器打开 http://本机IP:端口/ 可看到「PAC 地址入口」。
  - 可选根据模板生成 proxy.pac（PROXY 指向 v2ray 等对客户端可见的 HTTP 入站）。
.PARAMETER ProxyHost
  客户端能访问到的代理主机（v2ray 等）。与 -ProxyPort 同时指定时会调用 gen-pac.ps1 生成 proxy.pac。
.PARAMETER ProxyPort
  代理 HTTP 入站端口（PAC 内 PROXY 使用；非本脚本监听端口）。
.PARAMETER Port
  本 PAC 站点 HTTP 端口，默认 8080。
.PARAMETER RootPath
  托管根目录，默认脚本所在目录（需含 proxy.pac，可选 index.html）。
.EXAMPLE
  .\pac-lan-service.ps1 -ProxyHost 192.168.201.51 -ProxyPort 10809
.EXAMPLE
  .\pac-lan-service.ps1 -Port 8080
  （已手动准备好 proxy.pac 时）
#>
param(
    [string]$ProxyHost,
    [int]$ProxyPort = 0,
    [int]$Port = 8080,
    [string]$RootPath = $PSScriptRoot,
    [switch]$SkipOpenFirewallHint
)

$ErrorActionPreference = "Stop"
$root = [System.IO.Path]::GetFullPath($RootPath)
if (-not (Test-Path $root)) {
    Write-Error "RootPath not found: $root"
    exit 1
}

$pacPath = Join-Path $root "proxy.pac"
if ($ProxyHost -and $ProxyPort -gt 0) {
    $gen = Join-Path $PSScriptRoot "gen-pac.ps1"
    if (-not (Test-Path $gen)) {
        Write-Error "Missing gen-pac.ps1 next to this script."
        exit 1
    }
    & $gen -ProxyHost $ProxyHost -ProxyPort $ProxyPort -OutputPath $pacPath
}
elseif (-not (Test-Path -LiteralPath $pacPath)) {
    Write-Error "缺少 proxy.pac。请指定 -ProxyHost 与 -ProxyPort 以自动生成，或手动放置 proxy.pac 到: $root"
    exit 1
}

function Get-LanIPv4Addresses {
    [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
        Where-Object {
            $_.OperationalStatus -eq [System.Net.NetworkInformation.OperationalStatus]::Up -and
            $_.NetworkInterfaceType -ne [System.Net.NetworkInformation.NetworkInterfaceType]::Loopback
        } |
        ForEach-Object { $_.GetIPProperties().UnicastAddresses } |
        Where-Object { $_.Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } |
        ForEach-Object { $_.Address.ToString() } |
        Where-Object { $_ -notmatch '^127\.' } |
        Sort-Object -Unique
}

function Get-IPv4FromDnsHost {
    try {
        $hn = [System.Net.Dns]::GetHostName()
        $entry = [System.Net.Dns]::GetHostEntry($hn)
        @(
            $entry.AddressList |
                Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } |
                ForEach-Object { $_.ToString() } |
                Where-Object { $_ -notmatch '^127\.' }
        ) | Sort-Object -Unique
    }
    catch {
        @()
    }
}

Write-Host ""
Write-Host "========== PAC 地址入口（局域网内填到：设置 - 网络和 Internet - 代理 - 使用设置脚本）==========" -ForegroundColor Cyan
$ips = @(Get-LanIPv4Addresses)
if ($ips.Count -eq 0) {
    $ips = @(Get-IPv4FromDnsHost)
}
if ($ips.Count -eq 0) {
    Write-Host "（未检测到非回环 IPv4，请将 <本机局域网IP> 换为本机实际地址）"
    Write-Host "http://<本机局域网IP>:$Port/proxy.pac"
}
else {
    foreach ($ip in $ips) {
        Write-Host "http://${ip}:$Port/proxy.pac" -ForegroundColor Green
    }
}
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "浏览器说明页（自动显示 PAC 完整 URL）: http://<与上列相同主机>:$Port/"
Write-Host "监听: TCP $Port  |  根目录: $root"
if (-not $SkipOpenFirewallHint) {
    Write-Host "若他机无法访问: Windows 防火墙入站规则放行 TCP $Port。" -ForegroundColor Yellow
}
Write-Host ""

$serve = Join-Path $PSScriptRoot "serve-pac.ps1"
& $serve -Port $Port -RootPath $root -QuietBanner
