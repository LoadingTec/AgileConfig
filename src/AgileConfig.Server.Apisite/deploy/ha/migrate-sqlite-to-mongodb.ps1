#Requires -Version 5.1
<#
.SYNOPSIS
  一键调用仓库内迁移工具：SQLite (agile_config.db) -> MongoDB

.DESCRIPTION
  通过 dotnet run 执行 AgileConfig.Tools.MigrateSqliteToMongo。
  脚本位于 deploy/ha/，自动解析仓库根目录。

.PARAMETER Sqlite
  SQLite 连接串，例如: Data Source=C:\publish\agile_config.db

.PARAMETER Mongo
  MongoDB URI，例如: mongodb://user:pass@127.0.0.1:27017/AgileConfig

.PARAMETER Drop
  写入前删除目标 MongoDB 中对应集合同名集合（等价 --drop --yes）

.PARAMETER DryRun
  仅统计行数，不写入

.EXAMPLE
  .\migrate-sqlite-to-mongodb.ps1 -Sqlite 'Data Source=D:\agile_config.db' -Mongo 'mongodb://127.0.0.1:27017/AgileConfig' -DryRun

.EXAMPLE
  .\migrate-sqlite-to-mongodb.ps1 -Sqlite 'Data Source=D:\agile_config.db' -Mongo 'mongodb://127.0.0.1:27017/AgileConfig' -Drop
#>
param(
    [string] $Sqlite,
    [string] $Mongo,
    [switch] $Drop,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$Proj = Join-Path $RepoRoot 'src\AgileConfig.Tools.MigrateSqliteToMongo\AgileConfig.Tools.MigrateSqliteToMongo.csproj'

if (-not (Test-Path $Proj)) {
    throw "未找到迁移项目: $Proj （请从仓库内 deploy/ha 运行本脚本）"
}

if (-not $Sqlite) { $Sqlite = Read-Host 'SQLite 连接串 (例 Data Source=C:\path\agile_config.db)' }
if (-not $Mongo) { $Mongo = Read-Host 'MongoDB URI (例 mongodb://127.0.0.1:27017/AgileConfig)' }

$dotnetArgs = @('run', '-c', 'Release', '--project', $Proj, '--', '--sqlite', $Sqlite, '--mongo', $Mongo)
if ($DryRun) { $dotnetArgs += '--dry-run' }
if ($Drop) {
    $dotnetArgs += @('--drop', '--yes')
}

Write-Host "dotnet $($dotnetArgs -join ' ')"
& dotnet @dotnetArgs
exit $LASTEXITCODE
