# Go API: ensure go.exe on PATH, optional winget, then go run . (ASCII-only)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
. (Join-Path $PSScriptRoot "_ensure-go.ps1")

Refresh-PathFromRegistry
if (-not (Test-GoOnPath)) {
    $null = Try-DiscoverGoBin
}
if (-not (Test-GoOnPath)) {
    Write-Host "go.exe not on PATH; trying winget GoLang.Go ..."
    $null = Try-WingetInstallGo
    Refresh-PathFromRegistry
    $null = Try-DiscoverGoBin
}

if (-not (Test-GoOnPath)) {
    Write-Error "go.exe still not found. Install from https://go.dev/dl/ or: winget install -e --id GoLang.Go --source winget  then open a NEW terminal."
}

Write-GoApiUrls
Write-Host "Starting API (Ctrl+C to stop) ..."
go run .
