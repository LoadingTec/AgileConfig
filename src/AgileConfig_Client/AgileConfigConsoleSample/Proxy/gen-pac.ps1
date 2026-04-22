<#
.SYNOPSIS
  根据代理主机与端口生成 PAC 文件（供客户端通过 PAC URL 使用）。
.PARAMETER ProxyHost
  客户端能访问到的服务器主机名或 IP（勿用 127.0.0.1 对外分发）。
.PARAMETER ProxyPort
  v2ray HTTP 入站端口。
.PARAMETER OutputPath
  输出的 .pac 路径，默认当前目录 proxy.pac。
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ProxyHost,

    [Parameter(Mandatory = $true)]
    [int]$ProxyPort,

    [string]$OutputPath = (Join-Path $PSScriptRoot "proxy.pac")
)

$templatePath = Join-Path $PSScriptRoot "proxy.pac.template"
if (-not (Test-Path $templatePath)) {
    Write-Error "Missing template: $templatePath"
    exit 1
}

$content = Get-Content -Raw -LiteralPath $templatePath -Encoding UTF8
$content = $content.Replace("{{PROXY_HOST}}", $ProxyHost).Replace("{{PROXY_PORT}}", $ProxyPort.ToString())
[System.IO.File]::WriteAllText($OutputPath, $content, [System.Text.UTF8Encoding]::new($false))
Write-Host "Written: $OutputPath"
