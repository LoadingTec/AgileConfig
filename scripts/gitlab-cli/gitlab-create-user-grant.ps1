# Creates a GitLab user (admin API) and adds them to a project with a role.
# Requires: GITLAB_TOKEN with admin create_user (or full admin) + api scope; project Maintainer+ to add members.
# Usage: see README.md

param(
    [Parameter(Mandatory = $true)]
    [string] $Email,
    [Parameter(Mandatory = $true)]
    [string] $Username,
    [Parameter(Mandatory = $true)]
    [string] $Name,
    [Parameter(Mandatory = $true)]
    [string] $Project,
    [string] $Group = "MaxGp",
    [ValidateSet('Guest', 'Reporter', 'Developer', 'Maintainer')]
    [string] $AccessLevel = 'Developer',
    [string] $Password,
    [string] $ApiBase = "https://ako.le1e.com/gitlab/api/v4"
)

$Token = $env:GITLAB_TOKEN
if (-not $Token) { Write-Error "Set GITLAB_TOKEN."; exit 1 }

if (-not $Password) { $Password = $env:GITLAB_NEW_USER_PASSWORD }

$accessMap = @{ Guest = 10; Reporter = 20; Developer = 30; Maintainer = 40 }
$accessId = $accessMap[$AccessLevel]

$headers = @{ "PRIVATE-TOKEN" = $Token }

# --- resolve project id: short name -> Group/slug; if Project contains "/" use as full path_with_namespace ---
$pathWithNs = $null
if ($Project -match '/') {
    $pathWithNs = $Project.Trim().Trim('/')
}
else {
    $projectSlug = $Project.ToLower() -replace '[^a-z0-9_-]', '-' -replace '-+', '-' -replace '^-|-$', ''
    $pathWithNs = "$Group/$projectSlug"
}
$encProject = [uri]::EscapeDataString($pathWithNs)
try {
    $proj = Invoke-RestMethod -Uri "$ApiBase/projects/$encProject" -Headers $headers -Method Get
}
catch {
    Write-Error @"
Project not found or no access: $pathWithNs
  - In GitLab open the project: Settings -> General -> copy path (path with namespace), e.g. 'MyGroup/dksys'.
  - If it is NOT under '$Group', pass the full path: -Project 'ActualNamespace/dksys' (slashes; -Group is ignored for lookup).
  - GitLab often returns 404 when the token cannot see the project; use a token that can read the project (Maintainer+ to add members).
  Details: $_
"@
    exit 1
}
$projectId = $proj.id

# --- create user or reuse if exists ---
$userBody = @{
    email      = $Email
    username   = $Username
    name       = $Name
    reset_password = $false
}
if ($Password) {
    $userBody.password = $Password
    $userBody.force_random_password = $false
    $userBody.skip_confirmation = $true
}
else {
    $userBody.force_random_password = $true
    $userBody.skip_confirmation = $true
}

$userJson = $userBody | ConvertTo-Json
$userId = $null
try {
    $newUser = Invoke-RestMethod -Uri "$ApiBase/users" -Headers $headers -Method Post -Body $userJson -ContentType "application/json; charset=utf-8"
    $userId = $newUser.id
    Write-Host "Created user: $Username (id=$userId)"
    if (-not $Password) {
        Write-Host "Note: force_random_password was used; set a password via Admin UI or reset email, or set GITLAB_NEW_USER_PASSWORD and re-run with a new username if you need a known password."
    }
}
catch {
    try {
        $found = Invoke-RestMethod -Uri "$ApiBase/users?username=$([uri]::EscapeDataString($Username))" -Headers $headers -Method Get
        $arr = @($found)
        if ($arr.Count -ge 1) { $userId = $arr[0].id }
    }
    catch { }

    if (-not $userId) {
        Write-Error "Create user failed and could not resolve by username: $_"
        exit 1
    }
    Write-Host "User already exists: $Username (id=$userId); skipping create."
}

# --- add project member ---
$memberBody = @{ user_id = $userId; access_level = $accessId } | ConvertTo-Json
try {
    $mem = Invoke-RestMethod -Uri "$ApiBase/projects/$projectId/members" -Headers $headers -Method Post -Body $memberBody -ContentType "application/json; charset=utf-8"
    Write-Host "Granted on $pathWithNs : $AccessLevel (member id=$($mem.id))"
}
catch {
    Write-Error "Add member failed: $_"
    exit 1
}
