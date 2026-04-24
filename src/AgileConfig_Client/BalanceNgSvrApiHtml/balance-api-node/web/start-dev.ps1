# Vite dev server; API must be on http://127.0.0.1:5094 (ASCII-only)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Error "npm not found. Install Node.js from https://nodejs.org/"
}

if (-not (Test-Path "node_modules")) {
    Write-Host "npm install ..."
    npm install
}

Write-Host "Starting Vite (Ctrl+C to stop). Ensure API is listening on http://127.0.0.1:5094"
npm run dev
