<#
.SYNOPSIS
    Initialize a new Git repository and pull from GitHub

.DESCRIPTION
    This script initializes a Git repository in the current directory and pulls
    content from an existing GitHub repository. Perfect for setting up a local
    copy of a GitHub project.

.PARAMETER RepoUrl
    The GitHub repository URL (HTTPS or SSH)
    Example: https://github.com/username/repo-name

.PARAMETER Branch
    The branch to checkout (default: main)

.PARAMETER Method
    Authentication method: "https" or "ssh" (default: https)

.EXAMPLE
    .\init-from-github.ps1 -RepoUrl "https://github.com/geekp2p/compose-workbench-core"
    Initialize repo and pull from GitHub using HTTPS

.EXAMPLE
    .\init-from-github.ps1 -RepoUrl "git@github.com:geekp2p/compose-workbench-core.git" -Method ssh -Branch main
    Initialize repo and pull from GitHub using SSH
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$RepoUrl,

    [Parameter(Mandatory=$false)]
    [string]$Branch = "main",

    [Parameter(Mandatory=$false)]
    [ValidateSet("https", "ssh")]
    [string]$Method = "https"
)

# =====================================
# Helper Functions
# =====================================

function Show-Banner {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  Initialize Git Repository from GitHub" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-GitInstalled {
    $gitExists = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitExists) {
        Write-Host "✗ Git is not installed!" -ForegroundColor Red
        Write-Host "Please install Git first: https://git-scm.com/downloads" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✓ Git is installed" -ForegroundColor Green
}

function Initialize-GitRepo {
    Write-Host ""
    Write-Host "Step 1: Initializing Git repository..." -ForegroundColor Cyan
    Write-Host "---------------------------------------" -ForegroundColor Cyan

    # Check if already a git repo
    if (Test-Path .git) {
        Write-Host "⚠ This directory is already a Git repository!" -ForegroundColor Yellow
        $response = Read-Host "Do you want to re-initialize? This will not delete your files. (y/n)"

        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }

    # Initialize git repo
    git init
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Git repository initialized" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to initialize Git repository" -ForegroundColor Red
        exit 1
    }
}

function Set-GitUser {
    Write-Host ""
    Write-Host "Step 2: Configuring Git user..." -ForegroundColor Cyan
    Write-Host "---------------------------------------" -ForegroundColor Cyan

    $userName = git config user.name 2>&1
    $userEmail = git config user.email 2>&1

    if (-not $userName -or -not $userEmail) {
        Write-Host "Git user not configured. Please provide your details:" -ForegroundColor Yellow
        Write-Host ""

        if (-not $userName) {
            $name = Read-Host "Enter your name"
            git config user.name $name
            Write-Host "✓ Name set to: $name" -ForegroundColor Green
        } else {
            Write-Host "✓ Name already set to: $userName" -ForegroundColor Green
        }

        if (-not $userEmail) {
            $email = Read-Host "Enter your email"
            git config user.email $email
            Write-Host "✓ Email set to: $email" -ForegroundColor Green
        } else {
            Write-Host "✓ Email already set to: $userEmail" -ForegroundColor Green
        }
    } else {
        Write-Host "✓ Git user already configured:" -ForegroundColor Green
        Write-Host "  Name: $userName" -ForegroundColor White
        Write-Host "  Email: $userEmail" -ForegroundColor White
    }
}

function Add-GitRemote {
    param(
        [string]$Url,
        [string]$AuthMethod
    )

    Write-Host ""
    Write-Host "Step 3: Adding remote repository..." -ForegroundColor Cyan
    Write-Host "---------------------------------------" -ForegroundColor Cyan

    # Validate URL format
    $isHttps = $Url -match '^https://'
    $isSsh = $Url -match '^git@'

    if (-not $isHttps -and -not $isSsh) {
        Write-Host "✗ Invalid URL format!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Valid formats:" -ForegroundColor Yellow
        Write-Host "  HTTPS: https://github.com/username/repo-name" -ForegroundColor White
        Write-Host "  SSH:   git@github.com:username/repo-name.git" -ForegroundColor White
        exit 1
    }

    # Convert HTTPS to proper format if needed
    if ($isHttps -and -not ($Url -match '\.git$')) {
        $Url = "$Url.git"
    }

    Write-Host "Repository URL: $Url" -ForegroundColor Yellow
    Write-Host ""

    # Add remote
    git remote add origin $Url
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Remote 'origin' added successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to add remote" -ForegroundColor Red
        exit 1
    }

    # Configure credential helper for HTTPS
    if ($isHttps) {
        Write-Host ""
        Write-Host "Configuring credential helper..." -ForegroundColor Yellow

        # Check if running on Windows
        if ($IsWindows -or $env:OS -match "Windows") {
            git config --global credential.helper wincred
            Write-Host "✓ Credential helper set to 'wincred'" -ForegroundColor Green
        } else {
            # Linux/Mac
            git config --global credential.helper cache
            Write-Host "✓ Credential helper set to 'cache'" -ForegroundColor Green
        }

        Write-Host ""
        Write-Host "Authentication Info:" -ForegroundColor Cyan
        Write-Host "  When pulling, Git will ask for:" -ForegroundColor White
        Write-Host "    Username: Your GitHub username" -ForegroundColor White
        Write-Host "    Password: Your GitHub Personal Access Token (PAT)" -ForegroundColor White
        Write-Host ""
        Write-Host "  To create a PAT:" -ForegroundColor Yellow
        Write-Host "    1. Go to GitHub -> Settings -> Developer settings" -ForegroundColor White
        Write-Host "    2. Generate new token (classic)" -ForegroundColor White
        Write-Host "    3. Select scopes: repo (full control)" -ForegroundColor White
        Write-Host "    4. Copy the token and use it as password" -ForegroundColor White
        Write-Host ""
    }
}

function Pull-FromGitHub {
    param([string]$BranchName)

    Write-Host ""
    Write-Host "Step 4: Pulling from GitHub..." -ForegroundColor Cyan
    Write-Host "---------------------------------------" -ForegroundColor Cyan
    Write-Host "Branch: $BranchName" -ForegroundColor Yellow
    Write-Host ""

    # Fetch from remote
    Write-Host "Fetching from remote..." -ForegroundColor Yellow
    git fetch origin

    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Failed to fetch from remote" -ForegroundColor Red
        Write-Host ""
        Write-Host "This might be due to authentication issues." -ForegroundColor Yellow
        Write-Host "Please check your credentials and try again." -ForegroundColor Yellow
        exit 1
    }

    Write-Host "✓ Fetched successfully" -ForegroundColor Green
    Write-Host ""

    # Check if branch exists on remote
    $branchExists = git ls-remote --heads origin $BranchName 2>&1

    if (-not $branchExists) {
        Write-Host "⚠ Branch '$BranchName' does not exist on remote" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Available branches:" -ForegroundColor Yellow
        git branch -r | ForEach-Object {
            Write-Host "  $_" -ForegroundColor White
        }
        Write-Host ""
        $newBranch = Read-Host "Enter branch name to checkout (or press Enter to skip)"

        if ($newBranch) {
            $BranchName = $newBranch
        } else {
            Write-Host "Skipping checkout. You can checkout manually later." -ForegroundColor Yellow
            return
        }
    }

    # Checkout branch and track remote
    Write-Host "Checking out branch '$BranchName'..." -ForegroundColor Yellow
    git checkout -b $BranchName origin/$BranchName

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Checked out branch '$BranchName'" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to checkout branch" -ForegroundColor Red
        exit 1
    }
}

function Show-Summary {
    param([string]$BranchName)

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  Setup completed successfully!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""

    Write-Host "Repository Information:" -ForegroundColor Cyan
    Write-Host ""

    # Current branch
    $currentBranch = git branch --show-current
    Write-Host "  Current Branch: $currentBranch" -ForegroundColor Yellow

    # Remote
    $remote = git remote get-url origin
    Write-Host "  Remote Origin: $remote" -ForegroundColor Yellow

    # Files
    Write-Host ""
    Write-Host "Files in repository:" -ForegroundColor Cyan
    git ls-files | ForEach-Object {
        Write-Host "  - $_" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Make changes to your files" -ForegroundColor White
    Write-Host "  2. Stage changes: git add ." -ForegroundColor White
    Write-Host "  3. Commit: git commit -m 'Your message'" -ForegroundColor White
    Write-Host "  4. Push: git push -u origin $currentBranch" -ForegroundColor White
    Write-Host ""
    Write-Host "You can also use the setup-repo.ps1 script to change remote later!" -ForegroundColor Yellow
    Write-Host ""
}

# =====================================
# Main Script
# =====================================

Show-Banner

# Step 0: Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Cyan
Write-Host "---------------------------------------" -ForegroundColor Cyan
Test-GitInstalled

# Step 1: Initialize Git repository
Initialize-GitRepo

# Step 2: Configure Git user
Set-GitUser

# Step 3: Add remote
Add-GitRemote -Url $RepoUrl -AuthMethod $Method

# Step 4: Pull from GitHub
Pull-FromGitHub -BranchName $Branch

# Step 5: Show summary
Show-Summary -BranchName $Branch
