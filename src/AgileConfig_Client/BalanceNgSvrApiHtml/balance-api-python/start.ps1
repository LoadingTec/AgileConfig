# Create .venv, pip install, run API on http://127.0.0.1:5091 (ASCII-only for Windows PowerShell)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Find-PythonLauncher {
    if (Get-Command py -ErrorAction SilentlyContinue) { return @{ Cmd = "py"; Args = @("-3") } }
    if (Get-Command python3 -ErrorAction SilentlyContinue) { return @{ Cmd = "python3"; Args = @() } }
    if (Get-Command python -ErrorAction SilentlyContinue) { return @{ Cmd = "python"; Args = @() } }
    return $null
}

$launcher = Find-PythonLauncher
if (-not $launcher) {
    Write-Error "Python 3.10+ not found. Install from https://www.python.org/downloads/ and add to PATH."
}

$venvPy = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPy)) {
    Write-Host "Creating .venv ..."
    & $launcher.Cmd ($launcher.Args + @("-m", "venv", ".venv"))
    if (-not (Test-Path $venvPy)) { Write-Error "Failed to create .venv" }
}

$pip = Join-Path $PSScriptRoot ".venv\Scripts\pip.exe"
Write-Host "pip install -r requirements.txt ..."
& $pip install -r (Join-Path $PSScriptRoot "requirements.txt")

Write-Host "Starting API (Ctrl+C to stop) ..."
$mainPy = Join-Path $PSScriptRoot "main.py"
& $venvPy $mainPy
