#Requires -RunAsAdministrator
<#
.SYNOPSIS
  一键安装 AgileConfig 配置中心为 Windows 服务（支持主节点 / 从节点角色）。

.DESCRIPTION
  - 主节点：adminConsole=true（管理后台）
  - 从节点：adminConsole=false，默认 cluster=true（同网段自动注册；跨网段请选 cluster=false 并在主节点手动添加节点）
  会修改部署目录下 appsettings.json 中的 urls、adminConsole、cluster、db.provider、db.conn（正则替换，请备份）。

.PARAMETER Role
  Primary | Secondary。未指定时在控制台询问。

.EXAMPLE
  .\install-windows-service.ps1
.EXAMPLE
  .\install-windows-service.ps1 -Role Secondary -DeployDir "D:\AgileConfig" -Port 8050 -SkipPublish
#>
[CmdletBinding()]
param(
    [ValidateSet('Primary', 'Secondary')]
    [string] $Role,
    [ValidateSet('true', 'false')]
    [string] $Cluster,
    [string] $DeployDir,
    [int] $Port = 0,
    [string] $DbProvider,
    [string] $DbConn,
    [string] $ServiceName = 'AgileConfigServer',
    [string] $DisplayName = 'AgileConfig Server',
    [string] $PublishSource,
    [switch] $SkipPublish,
    [switch] $SelfContained
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$ProjectFile = Join-Path $ProjectRoot 'AgileConfig.Server.Apisite.csproj'

function Read-LineOrDefault([string] $Prompt, [string] $Default) {
    if ([string]::IsNullOrWhiteSpace($Default)) { $v = Read-Host $Prompt; return $v }
    $v = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($v)) { return $Default }
    return $v
}

function Patch-Appsettings {
    param(
        [string] $Path,
        [string] $PortStr,
        [bool] $AdminConsole,
        [bool] $ClusterVal,
        [string] $Prov,
        [string] $Conn
    )
    $raw = [IO.File]::ReadAllText($Path)
    $raw = $raw -replace '"urls"\s*:\s*"http://\*:\d+"', "`"urls`": `"http://*:$PortStr`""
    $raw = $raw -replace '"adminConsole"\s*:\s*(true|false)', "`"adminConsole`": $(if ($AdminConsole) { 'true' } else { 'false' })"
    $raw = $raw -replace '"cluster"\s*:\s*(true|false)', "`"cluster`": $(if ($ClusterVal) { 'true' } else { 'false' })"
    $raw = $raw -replace '"provider"\s*:\s*"[^"]*"', "`"provider`": `"$Prov`""
    $connEsc = $Conn.Replace('\', '\\').Replace('"', '\"')
    $raw = [regex]::Replace($raw, '"conn"\s*:\s*"[^"]*"', "`"conn`": `"$connEsc`"", 1)
    [IO.File]::WriteAllText($Path, $raw)
}

Write-Host '=========================================='
Write-Host '  AgileConfig - Windows 服务安装'
Write-Host '=========================================='

if (-not $Role) {
    Write-Host ''
    Write-Host '选择节点角色:'
    Write-Host '  1) 主节点 - 带管理后台 (adminConsole=true)'
    Write-Host '  2) 从节点 - 无管理界面，加入集群 (adminConsole=false)'
    $c = Read-Host '请输入 1 或 2'
    $Role = if ($c -eq '2') { 'Secondary' } else { 'Primary' }
}

$isPrimary = ($Role -eq 'Primary')
$adminConsole = $isPrimary

if (-not $Cluster) {
    if ($isPrimary) {
        $cc = Read-LineOrDefault '主节点是否开启 cluster 自动注册? (y/n)' 'y'
        $ClusterVal = $cc -notmatch '^[Nn]'
    }
    else {
        $cc = Read-LineOrDefault '从节点 cluster 自动注册? 同网段选 y；跨网段选 n 并在主节点手动添加节点 (y/n)' 'y'
        $ClusterVal = $cc -notmatch '^[Nn]'
    }
}
else {
    $ClusterVal = ($Cluster -eq 'true')
}

if (-not $DeployDir) {
    $DeployDir = Read-LineOrDefault '部署目录（将复制/发布到此路径）' (Join-Path $env:ProgramFiles 'AgileConfig')
}
$DeployDir = $DeployDir.TrimEnd('\')

if ($Port -le 0) {
    $p = Read-LineOrDefault '监听端口' '8050'
    [void][int]::TryParse($p, [ref]$Port)
    if ($Port -le 0) { $Port = 8050 }
}

if (-not $DbProvider) {
    $DbProvider = Read-LineOrDefault '数据库 provider (sqlite/mysql/npgsql/sqlserver/mongodb 等)' 'sqlite'
}
if (-not $DbConn) {
    $defaultConn = if ($DbProvider -eq 'sqlite') { 'Data Source=agile_config.db' } else { 'Server=127.0.0.1;Database=agileconfig;User=root;Password=;Port=3306' }
    $DbConn = Read-LineOrDefault '数据库连接串 db.conn' $defaultConn
}

if ($isPrimary -and $DbProvider -eq 'sqlite') {
    Write-Host '提示: 多节点高可用请勿使用 SQLite；请改用共享 MySQL/PostgreSQL 等。' -ForegroundColor Yellow
}

$existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "停止并删除现有服务: $ServiceName"
    if ($existing.Status -eq 'Running') { Stop-Service -Name $ServiceName -Force }
    & sc.exe delete $ServiceName | Out-Null
    Start-Sleep -Seconds 2
}

if (-not (Test-Path $DeployDir)) {
    New-Item -ItemType Directory -Path $DeployDir -Force | Out-Null
}
$logsDir = Join-Path $DeployDir 'logs'
if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir -Force | Out-Null }

if (-not $SkipPublish) {
    if ($PublishSource) {
        if (-not (Test-Path $PublishSource)) { throw "PublishSource 不存在: $PublishSource" }
        Write-Host "从 $PublishSource 复制到 $DeployDir ..."
        Copy-Item -Path (Join-Path $PublishSource '*') -Destination $DeployDir -Recurse -Force
    }
    else {
        if (-not (Test-Path $ProjectFile)) { throw "未找到项目文件: $ProjectFile" }
        Write-Host '正在 dotnet publish ...'
        if ($SelfContained) {
            & dotnet publish $ProjectFile -c Release -o $DeployDir -r win-x64 --self-contained true -p:PublishSingleFile=false
        }
        else {
            & dotnet publish $ProjectFile -c Release -o $DeployDir
        }
        if ($LASTEXITCODE -ne 0) { throw 'dotnet publish 失败' }
    }
}
else {
    Write-Host '已跳过发布（SkipPublish）；请确认部署目录中已有 AgileConfig.Server.Apisite.dll 或自包含 exe。'
}

$dllPath = Join-Path $DeployDir 'AgileConfig.Server.Apisite.dll'
$exePath = Join-Path $DeployDir 'AgileConfig.Server.Apisite.exe'
$appsettingsPath = Join-Path $DeployDir 'appsettings.json'
if (-not (Test-Path $appsettingsPath)) { throw "未找到 appsettings.json: $appsettingsPath" }

Write-Host '正在写入 appsettings.json（urls / adminConsole / cluster / db）...'
Patch-Appsettings -Path $appsettingsPath -PortStr "$Port" -AdminConsole:$adminConsole -ClusterVal:$ClusterVal -Prov $DbProvider -Conn $DbConn

$binaryPathName = $null
if ($SelfContained) {
    if (-not (Test-Path $exePath)) { throw "自包含发布未找到 exe: $exePath（请使用 -SelfContained 发布）" }
    $binaryPathName = "`"$exePath`""
}
else {
    if (-not (Test-Path $dllPath)) { throw "未找到: $dllPath" }
    $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
    $dotnet = if ($dotnetCmd) { $dotnetCmd.Source } else { $null }
    if (-not $dotnet) { $dotnet = Join-Path $env:ProgramFiles 'dotnet\dotnet.exe' }
    if (-not (Test-Path $dotnet)) { throw '未找到 dotnet.exe，请安装 .NET 10 或使用 -SelfContained' }
    $binaryPathName = "`"$dotnet`" `"$dllPath`""
}

Write-Host "注册服务 $ServiceName ..."
New-Service -Name $ServiceName -BinaryPathName $binaryPathName -DisplayName $DisplayName -StartupType Automatic | Out-Null
& sc.exe description $ServiceName "AgileConfig configuration center ($Role)" | Out-Null

Write-Host '启动服务...'
try {
    Start-Service -Name $ServiceName
}
catch {
    Write-Warning "启动失败: $_ 请查看事件查看器或执行 Get-EventLog -LogName Application -Newest 20"
}

Write-Host ''
Write-Host '=========================================='
Write-Host '  安装完成'
Write-Host "  角色: $Role  adminConsole=$adminConsole  cluster=$ClusterVal"
Write-Host "  目录: $DeployDir"
Write-Host "  地址: http://localhost:$Port"
Write-Host '  管理: services.msc 或 sc stop/start ' $ServiceName
Write-Host '=========================================='
