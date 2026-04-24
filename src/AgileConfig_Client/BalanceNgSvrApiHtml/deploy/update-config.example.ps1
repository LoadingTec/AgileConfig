# Copy to update-config.ps1 (gitignored) and edit for your host.
# Dot-sourced by update-from-main.ps1

$DeployBranch = "main"
$DeployRemote = "origin"

# All must return HTTP 200 after deploy, or rollback runs. Remove 5082 if that instance is not running.
$DeployHealthCheckUrls = @(
    "http://127.0.0.1:5081/api/health"
    "http://127.0.0.1:5082/api/health"
    "http://127.0.0.1:8182/api/health"
)
$DeployHealthTimeoutSec = 90
$DeployHealthIntervalSec = 3
$DeployWaitAfterServiceRestartSec = 2

# Windows service names in restart order; @() if none
$DeployWindowsServices = @(
    # "BalanceApi5081"
)

$DeployNginxReloadScript = {
    & "C:\nginx-1.30.0\nginx.exe" -p "C:/nginx-1.30.0/" -c "conf/nginx.conf" -s reload
}

$DeployDotnetPublish = @{
    ProjectPath   = Join-Path $PSScriptRoot "..\BalanceNgSvrApi\BalanceNgSvrApi.csproj"
    Configuration = "Release"
}

# Leave empty to auto-detect repo root via git from deploy\..
$DeployGitRepoRoot = ""
