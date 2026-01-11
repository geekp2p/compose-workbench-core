<#
.SYNOPSIS
    Setup or change Git repository configuration

.DESCRIPTION
    This script helps you configure this project to push/pull to your own repository.
    Supports both HTTPS and SSH authentication methods.

.PARAMETER NewRepoUrl
    The new repository URL (HTTPS or SSH format)
    Example HTTPS: https://github.com/username/repo-name
    Example SSH: git@github.com:username/repo-name.git

.PARAMETER Method
    Authentication method: "https" or "ssh" (default: https)

.PARAMETER RemoteName
    Name of the remote (default: origin)

.PARAMETER ShowCurrent
    Show current repository configuration

.PARAMETER TestConnection
    Test connection to the repository

.EXAMPLE
    .\setup-repo.ps1 -ShowCurrent
    Show current repository configuration

.EXAMPLE
    .\setup-repo.ps1 -NewRepoUrl "https://github.com/username/compose-workbench-core"
    Change repository to new URL using HTTPS

.EXAMPLE
    .\setup-repo.ps1 -NewRepoUrl "git@github.com:username/compose-workbench-core.git" -Method ssh
    Change repository to new URL using SSH

.EXAMPLE
    .\setup-repo.ps1 -TestConnection
    Test connection to current repository
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$NewRepoUrl,

    [Parameter(Mandatory=$false)]
    [ValidateSet("https", "ssh")]
    [string]$Method = "https",

    [Parameter(Mandatory=$false)]
    [string]$RemoteName = "origin",

    [Parameter(Mandatory=$false)]
    [switch]$ShowCurrent,

    [Parameter(Mandatory=$false)]
    [switch]$TestConnection
)

# =====================================
# Helper Functions
# =====================================

function Show-Banner {
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "  Git Repository Setup Tool" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-CurrentConfig {
    Write-Host "Current Repository Configuration:" -ForegroundColor Green
    Write-Host ""

    # Get current remote
    $remotes = git remote -v 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Remote(s):" -ForegroundColor Yellow
        $remotes | ForEach-Object {
            Write-Host "  $_" -ForegroundColor White
        }
    } else {
        Write-Host "  No remote configured" -ForegroundColor Red
    }

    Write-Host ""

    # Get current branch
    $branch = git branch --show-current 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Current Branch: $branch" -ForegroundColor Yellow
    }

    # Get tracking branch
    $tracking = git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Tracking Branch: $tracking" -ForegroundColor Yellow
    } else {
        Write-Host "Tracking Branch: None" -ForegroundColor Yellow
    }

    Write-Host ""

    # Get git user config
    $userName = git config user.name 2>&1
    $userEmail = git config user.email 2>&1

    Write-Host "Git User Configuration:" -ForegroundColor Yellow
    if ($userName) {
        Write-Host "  Name: $userName" -ForegroundColor White
    } else {
        Write-Host "  Name: Not configured" -ForegroundColor Red
    }

    if ($userEmail) {
        Write-Host "  Email: $userEmail" -ForegroundColor White
    } else {
        Write-Host "  Email: Not configured" -ForegroundColor Red
    }

    Write-Host ""
}

function Test-GitConnection {
    param([string]$Remote = "origin")

    Write-Host "Testing connection to remote '$Remote'..." -ForegroundColor Yellow

    $result = git ls-remote --heads $Remote 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Connection successful!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Available branches:" -ForegroundColor Yellow
        $result | ForEach-Object {
            if ($_ -match 'refs/heads/(.+)$') {
                Write-Host "  - $($matches[1])" -ForegroundColor White
            }
        }
        return $true
    } else {
        Write-Host "✗ Connection failed!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Error details:" -ForegroundColor Red
        Write-Host $result -ForegroundColor Red
        return $false
    }
}

function Set-GitUser {
    Write-Host ""
    Write-Host "Git User Configuration" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    Write-Host ""

    $userName = git config user.name 2>&1
    $userEmail = git config user.email 2>&1

    if (-not $userName -or -not $userEmail) {
        Write-Host "Git user not configured. Please provide your details:" -ForegroundColor Yellow
        Write-Host ""

        if (-not $userName) {
            $name = Read-Host "Enter your name"
            git config user.name $name
            Write-Host "✓ Name set to: $name" -ForegroundColor Green
        }

        if (-not $userEmail) {
            $email = Read-Host "Enter your email"
            git config user.email $email
            Write-Host "✓ Email set to: $email" -ForegroundColor Green
        }

        Write-Host ""
    } else {
        Write-Host "✓ Git user already configured:" -ForegroundColor Green
        Write-Host "  Name: $userName" -ForegroundColor White
        Write-Host "  Email: $userEmail" -ForegroundColor White
        Write-Host ""
    }
}

function Set-GitRemote {
    param(
        [string]$Url,
        [string]$Remote = "origin",
        [string]$AuthMethod = "https"
    )

    Write-Host ""
    Write-Host "Configuring Git Remote" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    Write-Host ""

    # Validate URL format
    $isHttps = $Url -match '^https://'
    $isSsh = $Url -match '^git@'

    if (-not $isHttps -and -not $isSsh) {
        Write-Host "✗ Invalid URL format!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Valid formats:" -ForegroundColor Yellow
        Write-Host "  HTTPS: https://github.com/username/repo-name" -ForegroundColor White
        Write-Host "  SSH:   git@github.com:username/repo-name.git" -ForegroundColor White
        Write-Host ""
        exit 1
    }

    # Convert HTTPS to proper format if needed
    if ($isHttps -and -not ($Url -match '\.git$')) {
        $Url = "$Url.git"
    }

    Write-Host "Repository URL: $Url" -ForegroundColor Yellow
    Write-Host "Authentication Method: $AuthMethod" -ForegroundColor Yellow
    Write-Host "Remote Name: $Remote" -ForegroundColor Yellow
    Write-Host ""

    # Check if remote exists
    $existingRemote = git remote get-url $Remote 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Remote '$Remote' already exists: $existingRemote" -ForegroundColor Yellow
        $response = Read-Host "Do you want to replace it? (y/n)"

        if ($response -eq 'y' -or $response -eq 'Y') {
            git remote set-url $Remote $Url
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✓ Remote '$Remote' updated successfully!" -ForegroundColor Green
            } else {
                Write-Host "✗ Failed to update remote!" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    } else {
        git remote add $Remote $Url
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Remote '$Remote' added successfully!" -ForegroundColor Green
        } else {
            Write-Host "✗ Failed to add remote!" -ForegroundColor Red
            exit 1
        }
    }

    Write-Host ""

    # Configure credential helper for HTTPS
    if ($isHttps) {
        Write-Host "Configuring credential helper for HTTPS..." -ForegroundColor Yellow

        # Check if running on Windows
        if ($IsWindows -or $env:OS -match "Windows") {
            git config --global credential.helper wincred
            Write-Host "✓ Credential helper set to 'wincred'" -ForegroundColor Green
        } else {
            # Linux/Mac
            $credHelperExists = Get-Command git-credential-store -ErrorAction SilentlyContinue
            if ($credHelperExists) {
                git config --global credential.helper store
                Write-Host "✓ Credential helper set to 'store'" -ForegroundColor Green
            } else {
                git config --global credential.helper cache
                Write-Host "✓ Credential helper set to 'cache'" -ForegroundColor Green
            }
        }

        Write-Host ""
        Write-Host "Authentication Info:" -ForegroundColor Cyan
        Write-Host "  When you first push/pull, Git will ask for:" -ForegroundColor White
        Write-Host "    Username: Your GitHub username" -ForegroundColor White
        Write-Host "    Password: Your GitHub Personal Access Token (PAT)" -ForegroundColor White
        Write-Host ""
        Write-Host "  To create a PAT:" -ForegroundColor Yellow
        Write-Host "    1. Go to GitHub → Settings → Developer settings" -ForegroundColor White
        Write-Host "    2. Generate new token (classic)" -ForegroundColor White
        Write-Host "    3. Select scopes: repo (full control)" -ForegroundColor White
        Write-Host "    4. Copy the token and use it as password" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host "SSH Configuration:" -ForegroundColor Cyan
        Write-Host "  Make sure you have added your SSH key to GitHub:" -ForegroundColor White
        Write-Host "    1. Generate key: ssh-keygen -t ed25519 -C 'your_email@example.com'" -ForegroundColor White
        Write-Host "    2. Add to agent: ssh-add ~/.ssh/id_ed25519" -ForegroundColor White
        Write-Host "    3. Copy public key: cat ~/.ssh/id_ed25519.pub" -ForegroundColor White
        Write-Host "    4. Add to GitHub → Settings → SSH and GPG keys" -ForegroundColor White
        Write-Host ""
    }
}

# =====================================
# Main Script
# =====================================

Show-Banner

# Check if git is installed
$gitExists = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitExists) {
    Write-Host "✗ Git is not installed!" -ForegroundColor Red
    Write-Host "Please install Git first: https://git-scm.com/downloads" -ForegroundColor Yellow
    exit 1
}

# Check if we're in a git repository
$isGitRepo = Test-Path .git
if (-not $isGitRepo) {
    Write-Host "✗ This is not a Git repository!" -ForegroundColor Red
    Write-Host "Run 'git init' first to initialize a Git repository." -ForegroundColor Yellow
    exit 1
}

# Handle ShowCurrent flag
if ($ShowCurrent) {
    Show-CurrentConfig
    exit 0
}

# Handle TestConnection flag
if ($TestConnection) {
    Show-CurrentConfig
    Write-Host "---------------------------------------" -ForegroundColor Cyan
    Write-Host ""
    Test-GitConnection -Remote $RemoteName
    exit 0
}

# Handle NewRepoUrl parameter
if ($NewRepoUrl) {
    Set-GitUser
    Set-GitRemote -Url $NewRepoUrl -Remote $RemoteName -AuthMethod $Method

    Write-Host "Testing connection to new repository..." -ForegroundColor Yellow
    Write-Host ""

    $testResult = Test-GitConnection -Remote $RemoteName

    if ($testResult) {
        Write-Host ""
        Write-Host "=====================================" -ForegroundColor Green
        Write-Host "  Setup completed successfully!" -ForegroundColor Green
        Write-Host "=====================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "  1. Make some changes to your project" -ForegroundColor White
        Write-Host "  2. Commit: git add . && git commit -m 'Your message'" -ForegroundColor White
        Write-Host "  3. Push: git push -u $RemoteName main" -ForegroundColor White
        Write-Host ""
        Write-Host "Or use the git-helper.ps1 script for easier git operations!" -ForegroundColor Yellow
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "=====================================" -ForegroundColor Red
        Write-Host "  Connection test failed!" -ForegroundColor Red
        Write-Host "=====================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please check:" -ForegroundColor Yellow
        Write-Host "  1. Repository URL is correct" -ForegroundColor White
        Write-Host "  2. You have access to the repository" -ForegroundColor White
        Write-Host "  3. Your authentication is configured" -ForegroundColor White
        Write-Host ""
    }

    exit 0
}

# If no parameters provided, show interactive menu
Write-Host "No parameters provided. Showing current configuration..." -ForegroundColor Yellow
Write-Host ""
Show-CurrentConfig

Write-Host "---------------------------------------" -ForegroundColor Cyan
Write-Host ""
Write-Host "Usage examples:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Show current config:" -ForegroundColor Yellow
Write-Host "    .\setup-repo.ps1 -ShowCurrent" -ForegroundColor White
Write-Host ""
Write-Host "  Test connection:" -ForegroundColor Yellow
Write-Host "    .\setup-repo.ps1 -TestConnection" -ForegroundColor White
Write-Host ""
Write-Host "  Change to new repository (HTTPS):" -ForegroundColor Yellow
Write-Host "    .\setup-repo.ps1 -NewRepoUrl 'https://github.com/username/repo-name'" -ForegroundColor White
Write-Host ""
Write-Host "  Change to new repository (SSH):" -ForegroundColor Yellow
Write-Host "    .\setup-repo.ps1 -NewRepoUrl 'git@github.com:username/repo-name.git' -Method ssh" -ForegroundColor White
Write-Host ""
Write-Host "For more information, see: REPO-SETUP.md" -ForegroundColor Cyan
Write-Host ""
