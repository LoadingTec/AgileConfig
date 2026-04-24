# Optional: install Go via winget only (ASCII-only)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
. (Join-Path $PSScriptRoot "_ensure-go.ps1")

if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    Write-Error "winget not found. Install Go manually from https://go.dev/dl/"
}

$ok = Try-WingetInstallGo
Refresh-PathFromRegistry
if (-not $ok) {
    Write-Warning "winget returned non-zero; try elevated PowerShell or install manually."
}
Write-Host "Done. Open a NEW terminal, then run .\start.ps1"
