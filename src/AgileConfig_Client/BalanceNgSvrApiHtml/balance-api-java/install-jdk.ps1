# Optional: install Temurin JDK via winget only (ASCII-only). Usage: .\install-jdk.ps1 17   or   .\install-jdk.ps1 8
param(
    [Parameter(Position = 0)]
    [ValidateSet("17", "8")]
    [string]$Version = "17"
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
. (Join-Path $PSScriptRoot "_ensure-jdk.ps1")

if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    Write-Error "winget not found. Install App Installer / Windows Package Manager, or install JDK manually from https://adoptium.net/"
}

$ok = Try-WingetInstall -Major $Version
Refresh-PathFromRegistry
if (-not $ok) {
    Write-Warning "winget returned non-zero; install may need admin UI approval. Re-run elevated or install manually."
}
Write-Host "Done. Open a NEW terminal, then run .\start.ps1 or .\start-java8.ps1"
