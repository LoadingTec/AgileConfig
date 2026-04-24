# Shared: discover JDK (javac), set JAVA_HOME + PATH; optional winget install. ASCII-only.
$ErrorActionPreference = "Stop"

# java -version writes to stderr; under $ErrorActionPreference Stop, PowerShell treats that as a terminating error.
function Get-JavaVersionText {
    param([Parameter(Mandatory)][string]$JavaExe)
    if (-not (Test-Path -LiteralPath $JavaExe)) { return "" }
    return (cmd.exe /c "`"$JavaExe`" -version 2>&1" | Out-String)
}

function Parse-JavaMajorFromVersionText {
    param([string]$Txt)
    if ($Txt -match 'version "1\.(\d+)\.') { return [int]$Matches[1] }
    if ($Txt -match 'version "(\d+)\.') { return [int]$Matches[1] }
    return 0
}

function Get-JavaMajorFromHome {
    param([string]$JavaHome)
    $javaExe = Join-Path $JavaHome "bin\java.exe"
    if (-not (Test-Path $javaExe)) { return 0 }
    $txt = Get-JavaVersionText -JavaExe $javaExe
    return Parse-JavaMajorFromVersionText $txt
}

function Get-CurrentJavaMajor {
    if (-not (Test-JavaOnPath)) { return 0 }
    $exe = (Get-Command java.exe -ErrorAction SilentlyContinue).Source
    if (-not $exe) { return 0 }
    $txt = Get-JavaVersionText -JavaExe $exe
    return Parse-JavaMajorFromVersionText $txt
}

function Get-JdkHomesWithJavac {
    $homes = [System.Collections.Generic.List[string]]::new()
    if ($env:JAVA_HOME) {
        $jh = $env:JAVA_HOME.TrimEnd('\')
        if ((Test-Path (Join-Path $jh "bin\javac.exe"))) { [void]$homes.Add($jh) }
    }
    $msRoot = Join-Path $env:ProgramFiles "Microsoft"
    if (Test-Path $msRoot) {
        Get-ChildItem -Path (Join-Path $msRoot "jdk*") -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $javac = Join-Path $_.FullName "bin\javac.exe"
            if (Test-Path $javac) { [void]$homes.Add($_.FullName) }
        }
    }
    foreach ($base in @(
            "$env:ProgramFiles\Eclipse Adoptium",
            "$env:ProgramFiles\Java",
            "${env:ProgramFiles(x86)}\Java"
        )) {
        if (-not (Test-Path $base)) { continue }
        Get-ChildItem $base -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $javac = Join-Path $_.FullName "bin\javac.exe"
            if (Test-Path $javac) { [void]$homes.Add($_.FullName) }
        }
    }
    return $homes | Select-Object -Unique
}

function Apply-JdkHome {
    param([string]$JavaHome)
    $bin = Join-Path $JavaHome "bin"
    $env:JAVA_HOME = $JavaHome
    $env:Path = "$bin;$env:Path"
}

function Try-DiscoverAndApplyJdk {
    param([int]$MinimumMajor)
    $homes = Get-JdkHomesWithJavac
    $best = $null
    $bestMaj = -1
    foreach ($h in $homes) {
        $m = Get-JavaMajorFromHome $h
        if ($m -ge $MinimumMajor -and $m -gt $bestMaj) {
            $best = $h
            $bestMaj = $m
        }
    }
    if ($best) {
        Apply-JdkHome $best
        return $best
    }
    return $null
}

function Test-JavaOnPath {
    return $null -ne (Get-Command java.exe -ErrorAction SilentlyContinue)
}

function Test-JavacOnPath {
    return $null -ne (Get-Command javac.exe -ErrorAction SilentlyContinue)
}

function Try-WingetInstall {
    param([ValidateSet("17", "8")][string]$Major)
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) { return $false }
    $id = if ($Major -eq "17") { "EclipseAdoptium.Temurin.17.JDK" } else { "EclipseAdoptium.Temurin.8.JDK" }
    # --source winget: skip msstore when it fails TLS (0x8a15005e certificate mismatch).
    Write-Host "winget install $id --source winget (may need admin approval) ..."
    $p = Start-Process -FilePath "winget.exe" -ArgumentList @(
        "install", "-e", "--id", $id, "--source", "winget",
        "--accept-package-agreements", "--accept-source-agreements", "--disable-interactivity"
    ) -Wait -PassThru -NoNewWindow
    $code = $p.ExitCode
    # 0 = success; 3010 = MSI success reboot pending
    return ($code -eq 0 -or $code -eq 3010)
}

function Refresh-PathFromRegistry {
    $m = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $u = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if ($m -or $u) { $env:Path = "$m;$u" }
}

# Print where the API will listen (matches application.properties server.port / PORT).
function Write-BalanceApiUrls {
    param([Parameter(Mandatory)][string]$ProjectRoot)
    $port = $env:PORT
    if (-not $port) {
        $props = Join-Path $ProjectRoot "src\main\resources\application.properties"
        if (Test-Path -LiteralPath $props) {
            foreach ($line in Get-Content -LiteralPath $props) {
                if ($line -match '^\s*server\.port\s*=\s*\$\{PORT:([^}]+)\}\s*$') {
                    $port = $Matches[1].Trim()
                    break
                }
                if ($line -match '^\s*server\.port\s*=\s*(\S+)\s*$') {
                    $port = $Matches[1].Trim()
                    break
                }
            }
        }
    }
    if (-not $port) { $port = "5092" }
    $base = "http://127.0.0.1:$port"
    Write-Host ""
    Write-Host "---- Balance API (this process) --------------------------------"
    Write-Host " Base URL:    $base"
    Write-Host " Health:      $base/api/health"
    Write-Host " Submit POST: $base/api/submit  (multipart/form-data)"
    Write-Host "----------------------------------------------------------------"
    Write-Host ""
}
