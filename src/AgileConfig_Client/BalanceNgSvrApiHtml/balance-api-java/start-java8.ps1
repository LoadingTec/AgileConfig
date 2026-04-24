# Spring Boot 2.7 + Java 8 bytecode: discover JDK (8+ OK) / optional winget, then mvn -f pom-java8.xml (ASCII-only)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
. (Join-Path $PSScriptRoot "_ensure-jdk.ps1")

if (-not (Test-Path "pom-java8.xml")) {
    Write-Error "pom-java8.xml missing in this folder."
}

Refresh-PathFromRegistry
if (-not (Test-JavaOnPath) -or -not (Test-JavacOnPath)) {
    $null = Try-DiscoverAndApplyJdk -MinimumMajor 8
}
if (-not (Test-JavaOnPath) -or -not (Test-JavacOnPath)) {
    Write-Host "No JDK on PATH; trying winget Temurin 8 ..."
    $null = Try-WingetInstall -Major "8"
    Refresh-PathFromRegistry
    $null = Try-DiscoverAndApplyJdk -MinimumMajor 8
}
if (-not (Test-JavaOnPath) -or -not (Test-JavacOnPath)) {
    Write-Host "Trying winget Temurin 17 (can compile Java 8 target) ..."
    $null = Try-WingetInstall -Major "17"
    Refresh-PathFromRegistry
    $null = Try-DiscoverAndApplyJdk -MinimumMajor 8
}

if (-not (Test-JavaOnPath)) {
    Write-Error "java.exe still not found. Install a JDK or add JAVA_HOME/bin to PATH."
}
if (-not (Test-JavacOnPath)) {
    Write-Error "javac.exe still not found. Install a full JDK."
}

$maj = Get-CurrentJavaMajor
if ($maj -lt 8) {
    Write-Error "Need at least Java 8 (detected $maj)."
}

if (-not (Get-Command mvn -ErrorAction SilentlyContinue)) {
    Write-Error "mvn not found. Install Maven 3.6+."
}

Write-Host "Using JAVA_HOME=$env:JAVA_HOME"
Write-BalanceApiUrls -ProjectRoot $PSScriptRoot
Write-Host "Starting API: mvn -f pom-java8.xml spring-boot:run (Ctrl+C to stop) ..."
mvn -f pom-java8.xml -DskipTests spring-boot:run
