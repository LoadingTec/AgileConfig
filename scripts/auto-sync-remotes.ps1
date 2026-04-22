#Requires -Version 5.1
<#
.SYNOPSIS
  先 fetch / pull，再提交（提交说明带当前时间），最后推送到 origin 与 gitlab-http。

.DESCRIPTION
  - 依次从 origin、gitlab-http 拉取当前分支（若某远程尚无该分支则跳过该次 pull，避免误失败）。
  - 工作区有变更时 git add -A 并 commit；默认不做空提交。
  - 非交互：设置 GIT_TERMINAL_PROMPT、GIT_MERGE_AUTOEDIT。

.PARAMETER AllowEmptyCommit
  即使无文件变更也执行 git commit --allow-empty（会堆积空提交，一般不建议）。

.EXAMPLE
  # 手动跑一次
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\auto-sync-remotes.ps1

.EXAMPLE
  # 每 15 分钟计划任务见 scripts\register-auto-sync-task.ps1

  若 gitlab-http 因明文 HTTP 被 Git Credential Manager 拒绝，请将本脚本内远程名改为 gitlab-ssh，
  或参见 docs/Git-Config.md §1.1。
#>
[CmdletBinding()]
param(
    [switch] $AllowEmptyCommit
)

$ErrorActionPreference = 'Stop'
$env:GIT_TERMINAL_PROMPT = '0'
$env:GIT_MERGE_AUTOEDIT = 'no'

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $RepoRoot

$ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Write-Host "[$ts] 仓库: $RepoRoot"

$branch = git rev-parse --abbrev-ref HEAD 2>$null
if ([string]::IsNullOrWhiteSpace($branch) -or $branch -eq 'HEAD') {
    Write-Error '当前为 detached HEAD 或不在 git 仓库内，已退出。'
    exit 1
}
Write-Host "[$ts] 当前分支: $branch"

function Test-RemoteHasBranch {
    param(
        [string] $Remote,
        [string] $BranchName
    )
    $out = git ls-remote --heads $Remote "refs/heads/$BranchName" 2>$null
    return -not [string]::IsNullOrWhiteSpace($out)
}

Write-Host 'git fetch origin ...'
git fetch origin
Write-Host 'git fetch gitlab-http ...'
git fetch gitlab-http

if (Test-RemoteHasBranch -Remote 'origin' -BranchName $branch) {
    Write-Host "git pull origin $branch ..."
    git pull origin $branch --no-edit
}
else {
    Write-Warning "origin 上不存在分支 $branch，跳过 pull origin（首次可向空远程 push 创建）。"
}

if (Test-RemoteHasBranch -Remote 'gitlab-http' -BranchName $branch) {
    Write-Host "git pull gitlab-http $branch ..."
    git pull gitlab-http $branch --no-edit
}
else {
    Write-Warning "gitlab-http 上不存在分支 $branch，跳过 pull gitlab-http。"
}

$dirty = git status --porcelain
if ($dirty) {
    git add -A
    $msg = "chore: 定时同步 $ts"
    git commit -m $msg
    Write-Host "已提交: $msg"
}
elseif ($AllowEmptyCommit) {
    $msg = "chore: 定时心跳 $ts"
    git commit --allow-empty -m $msg
    Write-Host "已创建空提交: $msg"
}
else {
    Write-Host '工作区无变更，跳过 commit。'
}

Write-Host "git push origin $branch ..."
git push origin $branch

Write-Host "git push gitlab-http $branch ..."
git push gitlab-http $branch

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] 全部完成。"
