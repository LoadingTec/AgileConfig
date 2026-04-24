# Creates a GitLab project under a group via REST API v4.
# Usage: see README.md in this directory.

param(
    [Parameter(Position = 0)]
    [string] $Arg0,
    [Parameter(Position = 1)]
    [string] $Arg1,
    [string] $Group,
    [string] $Project,
    [string] $ApiBase = "https://ako.le1e.com/gitlab/api/v4"
)

$Token = $env:GITLAB_TOKEN
if (-not $Token) { Write-Error "Set environment variable GITLAB_TOKEN (Personal/Project Access Token with api scope)."; exit 1 }

if (-not $Project -and $Arg0 -and -not $Arg1) { $Project = $Arg0 }
if (-not $Project -and $Arg0 -and $Arg1) { $Group = $Arg0; $Project = $Arg1 }

if (-not $Project) {
    Write-Error "Usage: .\gitlab-create-project.ps1 [-Group name] -Project name | .\gitlab-create-project.ps1 [group] project"
    exit 1
}
if (-not $Group) { $Group = "MaxGp" }

$headers = @{ "PRIVATE-TOKEN" = $Token }

$groupPath = [uri]::EscapeDataString($Group)
try {
    $grp = Invoke-RestMethod -Uri "$ApiBase/groups/$groupPath" -Headers $headers -Method Get
}
catch {
    Write-Error "Cannot load group '$Group': $_ (check group path, token api permission)"
    exit 1
}

$namespaceId = $grp.id
$slug = $Project.ToLower() -replace '[^a-z0-9_-]', '-'
$slug = $slug -replace '-+', '-' -replace '^-|-$', ''

$bodyObj = @{
    name         = $Project
    path         = $slug
    namespace_id = $namespaceId
}
$json = $bodyObj | ConvertTo-Json

try {
    $proj = Invoke-RestMethod -Uri "$ApiBase/projects" -Headers $headers -Method Post -Body $json -ContentType "application/json; charset=utf-8"
    Write-Host "Created: $($proj.path_with_namespace) (id=$($proj.id))"
    if ($proj.ssh_url_to_repo) { Write-Host "SSH:   $($proj.ssh_url_to_repo)" }
    if ($proj.http_url_to_repo) { Write-Host "HTTPS: $($proj.http_url_to_repo)" }
}
catch {
    Write-Error "Create project failed: $_"
    exit 1
}
