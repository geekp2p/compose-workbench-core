#!/usr/bin/env pwsh
<#
.SYNOPSIS
    ย้าย repo ไป GitHub repo ใหม่ได้ง่ายๆ

.DESCRIPTION
    Script นี้ช่วยให้คุณย้าย code ไป repo ใหม่ได้ง่ายๆ
    แค่ระบุชื่อ repo ใหม่ แล้ว script จะจัดการทุกอย่างให้

.PARAMETER NewRepo
    ชื่อ repo ใหม่ (เช่น compose-workbench-core-2)

.PARAMETER Owner
    GitHub owner/organization (default: geekp2p)

.PARAMETER Token
    GitHub Personal Access Token (ถ้าไม่ใส่ จะถามตอน run)

.PARAMETER Force
    บังคับย้ายโดยไม่ถามยืนยัน

.EXAMPLE
    .\migrate-repo.ps1 -NewRepo compose-workbench-core-2
    ย้ายไป repo ใหม่ชื่อ compose-workbench-core-2

.EXAMPLE
    .\migrate-repo.ps1 -NewRepo my-fork -Owner myusername
    ย้ายไป repo ของคุณเอง

.EXAMPLE
    .\migrate-repo.ps1 -NewRepo test-repo -Force
    ย้ายโดยไม่ถามยืนยัน
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="ชื่อ repo ใหม่ที่ต้องการย้ายไป")]
    [string]$NewRepo,

    [Parameter(Mandatory=$false)]
    [string]$Owner = "geekp2p",

    [Parameter(Mandatory=$false)]
    [string]$Token = "",

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Colors
function Write-Info($msg) { Write-Host $msg -ForegroundColor Cyan }
function Write-Success($msg) { Write-Host $msg -ForegroundColor Green }
function Write-Warn($msg) { Write-Host $msg -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host $msg -ForegroundColor Red }

# Header
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  🚀 Repo Migration Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get current branch
try {
    $currentBranch = git rev-parse --abbrev-ref HEAD
    Write-Info "Current branch: $currentBranch"
} catch {
    Write-Err "❌ Error: Not a git repository"
    exit 1
}

# Construct new repo URL
$newRepoUrl = "https://github.com/$Owner/$NewRepo.git"

Write-Host ""
Write-Info "Migration Info:"
Write-Host "  From: " -NoNewline -ForegroundColor Gray
Write-Host "compose-workbench-core" -ForegroundColor White
Write-Host "  To:   " -NoNewline -ForegroundColor Gray
Write-Host "$Owner/$NewRepo" -ForegroundColor White
Write-Host "  Branch: " -NoNewline -ForegroundColor Gray
Write-Host "$currentBranch" -ForegroundColor White
Write-Host ""

# Confirm
if (-not $Force) {
    Write-Warn "⚠️  This will:"
    Write-Host "  1. Add new remote 'new-repo'" -ForegroundColor Yellow
    Write-Host "  2. Push current branch to new repo" -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "Continue? (y/n)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Info "Cancelled."
        exit 0
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Step 1: Authentication" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get token if not provided
if ([string]::IsNullOrWhiteSpace($Token)) {
    Write-Info "Choose authentication method:"
    Write-Host "  1) HTTPS with Personal Access Token" -ForegroundColor White
    Write-Host "  2) SSH (requires SSH key setup)" -ForegroundColor White
    Write-Host ""

    $choice = Read-Host "Enter choice (1-2)"

    if ($choice -eq "2") {
        # SSH
        $remoteUrl = "git@github.com:$Owner/$NewRepo.git"

        Write-Info "Testing SSH connection..."
        $sshTest = ssh -T git@github.com 2>&1 | Out-String
        if ($sshTest -match "successfully authenticated") {
            Write-Success "✅ SSH authentication working"
        } else {
            Write-Err "❌ SSH authentication failed"
            Write-Host ""
            Write-Warn "Please setup SSH key first:"
            Write-Host "  https://docs.github.com/en/authentication/connecting-to-github-with-ssh"
            exit 1
        }
    } else {
        # HTTPS with token
        Write-Host ""
        Write-Info "Get your token from: https://github.com/settings/tokens"
        Write-Warn "Token needs 'repo' scope"
        Write-Host ""

        $secureToken = Read-Host "Enter your GitHub Personal Access Token" -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
        $Token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

        $remoteUrl = "https://$Token@github.com/$Owner/$NewRepo.git"
    }
} else {
    $remoteUrl = "https://$Token@github.com/$Owner/$NewRepo.git"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Step 2: Update Git Remotes" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Add or update new-repo remote
try {
    git remote remove new-repo 2>$null
} catch {
    # Remote doesn't exist, that's ok
}

git remote add new-repo $remoteUrl
Write-Success "✅ Remote 'new-repo' added"

# Show remotes
Write-Info "Current remotes:"
git remote -v | Where-Object { $_ -match "new-repo" } | ForEach-Object {
    Write-Host "  $_" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Step 3: Push to New Repo" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Info "Pushing branch '$currentBranch' to $Owner/$NewRepo..."
Write-Host ""

# Push with retry logic (exponential backoff)
$maxRetries = 4
$retryDelay = 2

for ($i = 0; $i -le $maxRetries; $i++) {
    if ($i -gt 0) {
        Write-Warn "Retry $i/$maxRetries (waiting ${retryDelay}s...)"
        Start-Sleep -Seconds $retryDelay
        $retryDelay = $retryDelay * 2  # Exponential backoff
    }

    try {
        git push -u new-repo $currentBranch

        # Success!
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  ✅ SUCCESS!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""

        Write-Success "Branch pushed to:"
        Write-Host "  https://github.com/$Owner/$NewRepo/tree/$currentBranch" -ForegroundColor White
        Write-Host ""

        Write-Info "Next steps:"
        Write-Host "  1. Check the new repo on GitHub" -ForegroundColor Yellow
        Write-Host "  2. Create PR if needed" -ForegroundColor Yellow
        Write-Host "  3. Update repo URL: " -NoNewline -ForegroundColor Yellow
        Write-Host "git remote set-url origin $newRepoUrl" -ForegroundColor White
        Write-Host ""

        Write-Success "🎉 Migration complete!"
        Write-Host ""

        exit 0
    } catch {
        if ($i -lt $maxRetries) {
            Write-Warn "Push failed: $_"
            Write-Info "Retrying..."
        }
    }
}

# Failed after all retries
Write-Host ""
Write-Host "========================================" -ForegroundColor Red
Write-Host "  ❌ FAILED after $maxRetries retries" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""

Write-Err "Please check:"
Write-Host "  1. Repo '$Owner/$NewRepo' exists on GitHub" -ForegroundColor Yellow
Write-Host "  2. You have push access to the repo" -ForegroundColor Yellow
Write-Host "  3. Your token/SSH key is valid" -ForegroundColor Yellow
Write-Host "  4. Network connection is stable" -ForegroundColor Yellow
Write-Host ""

Write-Info "Create repo at: https://github.com/new"
Write-Host ""

exit 1
