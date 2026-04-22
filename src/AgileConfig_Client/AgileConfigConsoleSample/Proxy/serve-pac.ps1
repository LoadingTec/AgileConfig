<#
.SYNOPSIS
  在当前目录通过 HTTP 托管文件，便于客户端配置「PAC URL」（listen 0.0.0.0）。
.PARAMETER Port
  监听端口，默认 8080。
.PARAMETER RootPath
  网站根目录，默认为脚本所在目录。
.PARAMETER QuietBanner
  不打印示例 PAC URL（由 pac-lan-service.ps1 统一展示时可开启）。
#>
param(
    [int]$Port = 8080,
    [string]$RootPath = $PSScriptRoot,
    [switch]$QuietBanner
)

$root = [System.IO.Path]::GetFullPath($RootPath)
if (-not (Test-Path $root)) {
    Write-Error "RootPath not found: $root"
    exit 1
}

$listener = New-Object System.Net.HttpListener
$prefix = "http://+:$Port/"
$listener.Prefixes.Add($prefix)
try {
    $listener.Start()
}
catch {
    Write-Error "Failed to start listener. Try running as Administrator, or: netsh http add urlacl url=http://+:$Port/ user=$env:USERNAME"
    exit 1
}

Write-Host "Serving: $root"
if (-not $QuietBanner) {
    Write-Host "PAC example URL: http://<this-machine-ip>:$Port/proxy.pac"
}
Write-Host "Press Ctrl+C to stop."

while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    try {
        $rel = [Uri]::UnescapeDataString($req.Url.AbsolutePath.TrimStart('/'))
        if ([string]::IsNullOrEmpty($rel)) { $rel = "index.html" }
        $full = Join-Path $root $rel
        $full = [System.IO.Path]::GetFullPath($full)
        if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
            $res.StatusCode = 403
        }
        elseif (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            $res.StatusCode = 404
        }
        else {
            $bytes = [System.IO.File]::ReadAllBytes($full)
            $ext = [System.IO.Path]::GetExtension($full).ToLowerInvariant()
            if ($ext -eq ".pac") {
                $res.ContentType = "application/x-ns-proxy-autoconfig; charset=utf-8"
            }
            elseif ($ext -eq ".html" -or $ext -eq ".htm") {
                $res.ContentType = "text/html; charset=utf-8"
            }
            else {
                $res.ContentType = "application/octet-stream"
            }
            $res.ContentLength64 = $bytes.Length
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
        }
    }
    finally {
        $res.Close()
    }
}
