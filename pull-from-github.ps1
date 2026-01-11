#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Syncs the local branch with its remote counterpart.

.DESCRIPTION
    Fetches from remote and resets local branch to match the remote branch exactly.
    Discards all local changes and uncommitted work.

.PARAMETER Remote
    The remote name (default: origin)

.PARAMETER Branch
    The branch name (default: current branch)

.PARAMETER RemoteUrl
    URL to use if the remote doesn't exist yet

.EXAMPLE
    .\pull-from-github.ps1
    Syncs current branch with origin/<current-branch>

.EXAMPLE
    .\pull-from-github.ps1 -Remote origin -Branch main
    Syncs with origin/main

.EXAMPLE
    .\pull-from-github.ps1 -Remote upstream -RemoteUrl https://github.com/user/repo.git
    Adds upstream remote if it doesn't exist, then syncs
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Remote = "origin",

    [Parameter(Mandatory=$false)]
    [string]$Branch = "",

    [Parameter(Mandatory=$false)]
    [string]$RemoteUrl = ""
)

$ErrorActionPreference = "Stop"

# Default remote URL for this repository
$DEFAULT_REMOTE_URL = "https://github.com/geekp2p/multi-compose-labV2.git"

# Check if we're in a git repository
try {
    git rev-parse --is-inside-work-tree 2>&1 | Out-Null
}
catch {
    Write-Error "This folder is not a git repository."
    exit 1
}

# Detect current branch if not specified
if ([string]::IsNullOrEmpty($Branch)) {
    try {
        $Branch = git rev-parse --abbrev-ref HEAD 2>&1
        if ($LASTEXITCODE -ne 0) {
            $Branch = "main"
        }
    }
    catch {
        $Branch = "main"
    }
}

Write-Host "Syncing local branch with $Remote/$Branch ..." -ForegroundColor Cyan

# Check if remote exists, add it if it doesn't
try {
    git remote get-url $Remote 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Remote not found"
    }
}
catch {
    # Remote doesn't exist, try to add it
    if ([string]::IsNullOrEmpty($RemoteUrl)) {
        if ($env:GIT_REMOTE_URL) {
            $RemoteUrl = $env:GIT_REMOTE_URL
        }
        elseif ($DEFAULT_REMOTE_URL) {
            $RemoteUrl = $DEFAULT_REMOTE_URL
        }
        else {
            $RemoteUrl = Read-Host "Enter URL for remote $Remote (e.g., https://github.com/user/repo.git)"
        }
    }

    if ([string]::IsNullOrEmpty($RemoteUrl)) {
        Write-Error "Remote $Remote is not configured and no URL was provided."
        exit 1
    }

    Write-Host "Adding remote $Remote with $RemoteUrl ..." -ForegroundColor Yellow
    git remote add $Remote $RemoteUrl
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to add remote $Remote"
        exit 1
    }
}

# Save current commit hash for comparison
try {
    $oldCommit = git rev-parse HEAD 2>&1
    if ($LASTEXITCODE -ne 0) {
        $oldCommit = ""
    }
}
catch {
    $oldCommit = ""
}

# Fetch from remote
Write-Host "Fetching from $Remote ..." -ForegroundColor Cyan
git fetch $Remote
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to fetch from $Remote"
    exit 1
}

# Check if remote branch exists
try {
    $newCommit = git rev-parse "$Remote/$Branch" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Remote branch $Remote/$Branch does not exist."
        Write-Host "`nAvailable remote branches:" -ForegroundColor Yellow
        git branch -r --list "$Remote/*"
        exit 1
    }
}
catch {
    Write-Error "Remote branch $Remote/$Branch does not exist."
    Write-Host "`nAvailable remote branches:" -ForegroundColor Yellow
    git branch -r --list "$Remote/*"
    exit 1
}

# Show what's changing if there are updates
if ($oldCommit -ne $newCommit) {
    Write-Host "`n=== UPDATE SUMMARY ===" -ForegroundColor Green
    Write-Host "From: $($oldCommit.Substring(0, 7))" -ForegroundColor Yellow
    Write-Host "To:   $($newCommit.Substring(0, 7))" -ForegroundColor Yellow
    Write-Host "`nNew commits:" -ForegroundColor Cyan
    git log --oneline "$oldCommit..$newCommit"
    Write-Host "`nFiles changed:" -ForegroundColor Cyan
    git diff --stat "$oldCommit..$newCommit"
    Write-Host "`n======================" -ForegroundColor Green
    Write-Host ""
}
else {
    Write-Host "Already up to date - no changes detected." -ForegroundColor Green
    exit 0
}

# Reset to match remote
Write-Host "Resetting local branch to match $Remote/$Branch ..." -ForegroundColor Yellow
git reset --hard "$Remote/$Branch"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to reset to $Remote/$Branch"
    exit 1
}

# Clean untracked files
git clean -fd
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to clean untracked files, but branch was synced."
}

Write-Host "`nDone: local tree now matches $Remote/$Branch." -ForegroundColor Green
exit 0