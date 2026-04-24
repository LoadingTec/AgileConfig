# Spring Boot 3 + JDK 17: discover JDK / optional winget, then mvn spring-boot:run (ASCII-only)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
. (Join-Path $PSScriptRoot "_ensure-jdk.ps1")

Refresh-PathFromRegistry
if (-not (Test-JavaOnPath) -or -not (Test-JavacOnPath)) {
    $null = Try-DiscoverAndApplyJdk -MinimumMajor 8
}
if (-not (Test-JavaOnPath) -or -not (Test-JavacOnPath)) {
    Write-Host "No JDK on PATH; trying winget Temurin 17 ..."
    $null = Try-WingetInstall -Major "17"
    Refresh-PathFromRegistry
    $null = Try-DiscoverAndApplyJdk -MinimumMajor 8
}

if (-not (Test-JavaOnPath)) {
    Write-Error "java.exe still not found. Install JDK 17+ (Temurin) or add JAVA_HOME/bin to PATH."
}
if (-not (Test-JavacOnPath)) {
    Write-Error "javac.exe still not found. Install a full JDK (not JRE-only)."
}

$maj = Get-CurrentJavaMajor
if ($maj -lt 17) {
    Write-Host "Current Java major=$maj (need 17 for default pom). Trying winget Temurin 17 ..."
    $null = Try-WingetInstall -Major "17"
    Refresh-PathFromRegistry
    $null = Try-DiscoverAndApplyJdk -MinimumMajor 17
    $maj = Get-CurrentJavaMajor
}

if ($maj -lt 17) {
    Write-Error "Need JDK 17+ for default build (detected $maj). Use: .\start-java8.ps1 for Boot 2.7 / Java 8 bytecode."
}

if (-not (Get-Command mvn -ErrorAction SilentlyContinue)) {
    Write-Error "mvn not found. Install Maven 3.6+ https://maven.apache.org/download.cgi"
}

Write-Host "Using JAVA_HOME=$env:JAVA_HOME"
Write-BalanceApiUrls -ProjectRoot $PSScriptRoot
Write-Host "Starting API: mvn spring-boot:run (Ctrl+C to stop) ..."
mvn -DskipTests spring-boot:run
