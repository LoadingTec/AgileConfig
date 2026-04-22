#Requires -RunAsAdministrator
<#
.SYNOPSIS
  注册 Windows 计划任务：每 15 分钟执行 auto-sync-remotes.ps1（需管理员权限）。

.DESCRIPTION
  任务名默认 AgileConfig.AutoSyncPush。卸载：Unregister-ScheduledTask -TaskName AgileConfig.AutoSyncPush -Confirm:$false

.PARAMETER TaskName
  计划任务名称。

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\register-auto-sync-task.ps1
#>
[CmdletBinding()]
param(
    [string] $TaskName = 'AgileConfig.AutoSyncPush'
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$ScriptPath = Join-Path $RepoRoot 'scripts\auto-sync-remotes.ps1'
if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "未找到脚本: $ScriptPath"
}

$ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""

$action = New-ScheduledTaskAction -Execute $ps -Argument $arg -WorkingDirectory $RepoRoot
# 每 15 分钟重复一次；持续期用足够长的时间代替“无限”（避免部分系统对 MaxValue 报错）
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description 'AgileConfig: 每15分钟 pull、有变更则 commit（带时间）、push origin + gitlab-http' | Out-Null

Write-Host "已注册计划任务: $TaskName"
Write-Host "脚本: $ScriptPath"
Write-Host '查看: taskschd.msc 或 Get-ScheduledTask -TaskName' $TaskName
