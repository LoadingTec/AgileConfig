<#
.SYNOPSIS
    Fast-forward merge origin/main, optional dotnet publish, restart Windows services, optional Nginx reload; rollback on health check failure.

.DESCRIPTION
    Run on a server after code is pushed to origin/main: pull FF -> publish -> restart services -> probe URLs.
    On failure: git reset --hard to pre-deploy commit, publish again, restart, re-probe.
    Copy update-config.example.ps1 to update-config.ps1 to override defaults (see README).

.PARAMETER ConfigPath
    Path to dot-sourced config; default deploy\update-config.ps1 if present.

.PARAMETER SkipGitPull
    Skip fetch/merge; only publish + restart + health.

.PARAMETER DryRun
    Print steps only; no git/dotnet/service/nginx changes.

.EXAMPLE
    .\update-from-main.ps1
.EXAMPLE
    .\update-from-main.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [string] $ConfigPath = "",
    [switch] $SkipGitPull,
    [switch] $DryRun
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string] $Message)
    Write-Host "[$(Get-Date -Format o)] $Message" -ForegroundColor Cyan
}

function Get-GitRepoRoot {
    param([string] $StartDir)
    Push-Location $StartDir
    try {
        $top = git rev-parse --show-toplevel 2>$null
        if (-not $top) { throw "Not a git repository: $StartDir" }
        return (Resolve-Path $top).Path
    }
    finally {
        Pop-Location
    }
}

function Invoke-DeployPublish {
    param([hashtable] $Pub)
    if (-not $Pub -or -not $Pub.ProjectPath) { return }
    $proj = $Pub.ProjectPath
    if (-not (Test-Path -LiteralPath $proj)) { throw "Project file not found: $proj" }
    $cfg = if ($Pub.Configuration) { $Pub.Configuration } else { "Release" }
    Write-Step "dotnet publish -c $cfg `"$proj`""
    if (-not $DryRun) {
        dotnet publish $proj -c $cfg --nologo -v minimal
        if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed (exit $LASTEXITCODE)" }
    }
}

function Restart-DeployWindowsServices {
    param([string[]] $Names)
    foreach ($n in $Names) {
        if ([string]::IsNullOrWhiteSpace($n)) { continue }
        Write-Step "Restart-Service: $n"
        if (-not $DryRun) {
            Restart-Service -Name $n -Force -ErrorAction Stop
        }
    }
}

function Invoke-NginxReloadScript {
    param($ScriptBlock)
    if (-not $ScriptBlock) { return }
    Write-Step "Execute Nginx reload scriptblock"
    if (-not $DryRun) {
        & $ScriptBlock
    }
}

function Test-DeployHealth {
    param(
        [string[]] $Urls,
        [int] $TimeoutSec,
        [int] $IntervalSec
    )
    if (-not $Urls -or $Urls.Count -eq 0) {
        Write-Step "No health URLs configured; skip"
        return $true
    }
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $ok = $true
        foreach ($u in $Urls) {
            if ([string]::IsNullOrWhiteSpace($u)) { continue }
            try {
                $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 10 -Method Get
                if ($r.StatusCode -ne 200) {
                    $ok = $false
                    Write-Warning "Health not 200: $u -> $($r.StatusCode)"
                    break
                }
            }
            catch {
                $ok = $false
                Write-Warning "Health failed: $u -> $($_.Exception.Message)"
                break
            }
        }
        if ($ok) {
            Write-Step "Health check OK"
            return $true
        }
        Start-Sleep -Seconds $IntervalSec
    }
    return $false
}

# --- defaults ---
$DeployBranch = "main"
$DeployRemote = "origin"
$DeployHealthCheckUrls = @(
    "http://127.0.0.1:5081/api/health"
    "http://127.0.0.1:8182/api/health"
)
$DeployHealthTimeoutSec = 90
$DeployHealthIntervalSec = 3
$DeployWaitAfterServiceRestartSec = 2
$DeployWindowsServices = @()
$DeployNginxReloadScript = $null
$DeployDotnetPublish = @{
    ProjectPath     = Join-Path $PSScriptRoot "..\BalanceNgSvrApi\BalanceNgSvrApi.csproj"
    Configuration   = "Release"
}
$DeployGitRepoRoot = ""

$cfgFile = if ($ConfigPath) { $ConfigPath } else { Join-Path $PSScriptRoot "update-config.ps1" }
if (Test-Path -LiteralPath $cfgFile) {
    Write-Step "Load config: $cfgFile"
    . $cfgFile
}

$repoRoot = if ($DeployGitRepoRoot -and (Test-Path -LiteralPath (Join-Path $DeployGitRepoRoot ".git"))) {
    (Resolve-Path $DeployGitRepoRoot).Path
}
else {
    Get-GitRepoRoot -StartDir (Join-Path $PSScriptRoot "..")
}

Write-Step "Git repo root: $repoRoot"

if ($DeployDotnetPublish -and -not $DeployDotnetPublish.ProjectPath) {
    $DeployDotnetPublish["ProjectPath"] = Join-Path $PSScriptRoot "..\BalanceNgSvrApi\BalanceNgSvrApi.csproj"
}

$hadPublish = $false
Push-Location $repoRoot
try {
    $preCommit = git rev-parse HEAD
    Write-Step "Pre-deploy HEAD: $preCommit"

    if (-not $SkipGitPull) {
        Write-Step "git fetch $DeployRemote $DeployBranch"
        if (-not $DryRun) {
            git fetch $DeployRemote $DeployBranch
            if ($LASTEXITCODE -ne 0) { throw "git fetch failed" }
        }

        Write-Step "git merge --ff-only ${DeployRemote}/${DeployBranch}"
        if (-not $DryRun) {
            git merge --ff-only "${DeployRemote}/${DeployBranch}"
            if ($LASTEXITCODE -ne 0) {
                throw "git merge --ff-only failed (not fast-forward or conflicts). Services not restarted."
            }
        }
        Write-Step "Post-pull HEAD: $(git rev-parse HEAD)"
    }
    else {
        Write-Step "-SkipGitPull: skipping pull"
    }

    Invoke-DeployPublish -Pub $DeployDotnetPublish
    if ($DeployDotnetPublish -and $DeployDotnetPublish.ProjectPath) { $script:hadPublish = $true }

    Restart-DeployWindowsServices -Names $DeployWindowsServices
    if ($DeployWaitAfterServiceRestartSec -gt 0 -and $DeployWindowsServices.Count -gt 0) {
        Start-Sleep -Seconds $DeployWaitAfterServiceRestartSec
    }

    Invoke-NginxReloadScript -ScriptBlock $DeployNginxReloadScript

    if ($DryRun) {
        Write-Step "DryRun finished (no git merge/write, no publish/service/nginx side effects, no HTTP probes)."
        exit 0
    }

    $healthy = Test-DeployHealth -Urls $DeployHealthCheckUrls -TimeoutSec $DeployHealthTimeoutSec -IntervalSec $DeployHealthIntervalSec
    if ($healthy) {
        Write-Step "Deploy finished OK."
        exit 0
    }

    Write-Warning "Health check failed; rolling back to $preCommit"
    if ($DryRun) {
        Write-Step "DryRun: would git reset --hard $preCommit then republish/restart"
        exit 2
    }

    git reset --hard $preCommit
    if ($LASTEXITCODE -ne 0) { throw "git reset --hard failed" }
    Write-Step "Rolled back to: $(git rev-parse HEAD)"

    if ($hadPublish) {
        Invoke-DeployPublish -Pub $DeployDotnetPublish
    }
    Restart-DeployWindowsServices -Names $DeployWindowsServices
    if ($DeployWaitAfterServiceRestartSec -gt 0 -and $DeployWindowsServices.Count -gt 0) {
        Start-Sleep -Seconds $DeployWaitAfterServiceRestartSec
    }
    Invoke-NginxReloadScript -ScriptBlock $DeployNginxReloadScript

    if (-not (Test-DeployHealth -Urls $DeployHealthCheckUrls -TimeoutSec $DeployHealthTimeoutSec -IntervalSec $DeployHealthIntervalSec)) {
        Write-Error "Health still failing after rollback; manual intervention required."
        exit 3
    }

    Write-Step "Rollback complete; health OK."
    exit 2
}
catch {
    Write-Error $_
    exit 1
}
finally {
    Pop-Location
}
