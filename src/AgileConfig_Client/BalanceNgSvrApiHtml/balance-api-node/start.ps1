# npm install if needed, then node API on http://127.0.0.1:5094 (ASCII-only)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "node not found. Install Node.js 18+ LTS from https://nodejs.org/"
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Error "npm not found (install Node.js)."
}

if (-not (Test-Path "node_modules")) {
    Write-Host "First run: npm install ..."
    npm install
}

Write-Host "Starting API (Ctrl+C to stop) ..."
npm start
