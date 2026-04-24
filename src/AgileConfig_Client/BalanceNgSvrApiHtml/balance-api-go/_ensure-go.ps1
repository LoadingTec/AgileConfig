# Discover go.exe / refresh PATH / optional winget. ASCII-only.
$ErrorActionPreference = "Stop"

function Refresh-PathFromRegistry {
    $m = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $u = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if ($m -or $u) { $env:Path = "$m;$u" }
}

function Test-GoOnPath {
    return $null -ne (Get-Command go.exe -ErrorAction SilentlyContinue)
}

function Try-DiscoverGoBin {
    $dirs = @(
        "$env:ProgramFiles\Go\bin",
        "${env:ProgramFiles(x86)}\Go\bin",
        (Join-Path $env:LOCALAPPDATA "Programs\Go\bin"),
        "C:\Go\bin",
        (Join-Path $env:USERPROFILE "go\bin"),
        (Join-Path $env:USERPROFILE "scoop\shims")
    )
    foreach ($dir in $dirs) {
        if (-not $dir) { continue }
        $exe = Join-Path $dir "go.exe"
        if (Test-Path -LiteralPath $exe) {
            $env:Path = "$dir;$env:Path"
            return $true
        }
    }
    return $false
}

function Try-WingetInstallGo {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) { return $false }
    # Use --source winget only: avoids msstore SSL errors (0x8a15005e) on some networks/proxies.
    Write-Host "winget install GoLang.Go --source winget (may need admin approval) ..."
    $p = Start-Process -FilePath "winget.exe" -ArgumentList @(
        "install", "-e", "--id", "GoLang.Go", "--source", "winget",
        "--accept-package-agreements", "--accept-source-agreements", "--disable-interactivity"
    ) -Wait -PassThru -NoNewWindow
    $code = $p.ExitCode
    return ($code -eq 0 -or $code -eq 3010)
}

function Write-GoApiUrls {
    $port = $env:PORT
    if ([string]::IsNullOrWhiteSpace($port)) { $port = "5093" }
    $port = "$port".Trim()
    while ($port.StartsWith(":")) { $port = $port.TrimStart(":").Trim() }
    $base = "http://127.0.0.1:$port"
    Write-Host ""
    Write-Host "---- Balance API (Go, this process) -----------------------------"
    Write-Host " Base URL:    $base"
    Write-Host " Health:      $base/api/health"
    Write-Host " Submit POST: $base/api/submit  (multipart/form-data)"
    Write-Host " (Set env PORT to change port, e.g. 8093)"
    Write-Host "----------------------------------------------------------------"
    Write-Host ""
}
