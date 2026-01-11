<#
.SYNOPSIS
    Git operations helper script

.DESCRIPTION
    Simplified Git operations for common tasks like commit, push, pull, branch management.
    Makes Git easier to use for daily development workflow.

.PARAMETER Status
    Show git status and recent commits

.PARAMETER Pull
    Pull latest changes from remote

.PARAMETER Push
    Push changes to remote (commits first if needed)

.PARAMETER Commit
    Create a new commit (will ask for message)

.PARAMETER Message
    Commit message (use with -Commit)

.PARAMETER Branch
    Switch to a different branch

.PARAMETER NewBranch
    Create and switch to a new branch

.PARAMETER List
    List all branches

.PARAMETER Remote
    Show remote information

.PARAMETER Log
    Show commit history

.PARAMETER Sync
    Full sync: pull, commit, push

.EXAMPLE
    .\git-helper.ps1 -Status
    Show current status

.EXAMPLE
    .\git-helper.ps1 -Pull
    Pull latest changes

.EXAMPLE
    .\git-helper.ps1 -Commit -Message "Add new feature"
    Commit with message

.EXAMPLE
    .\git-helper.ps1 -Push
    Push to remote

.EXAMPLE
    .\git-helper.ps1 -Sync -Message "Update documentation"
    Pull, commit, and push in one command

.EXAMPLE
    .\git-helper.ps1 -NewBranch feature/new-feature
    Create and switch to new branch

.EXAMPLE
    .\git-helper.ps1 -Branch main
    Switch to main branch
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$Status,

    [Parameter(Mandatory=$false)]
    [switch]$Pull,

    [Parameter(Mandatory=$false)]
    [switch]$Push,

    [Parameter(Mandatory=$false)]
    [switch]$Commit,

    [Parameter(Mandatory=$false)]
    [string]$Message,

    [Parameter(Mandatory=$false)]
    [string]$Branch,

    [Parameter(Mandatory=$false)]
    [string]$NewBranch,

    [Parameter(Mandatory=$false)]
    [switch]$List,

    [Parameter(Mandatory=$false)]
    [switch]$Remote,

    [Parameter(Mandatory=$false)]
    [switch]$Log,

    [Parameter(Mandatory=$false)]
    [switch]$Sync,

    [Parameter(Mandatory=$false)]
    [string]$RemoteName = "origin"
)

# =====================================
# Helper Functions
# =====================================

function Show-Banner {
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "  Git Helper - Quick Git Operations" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-GitRepo {
    $isGitRepo = Test-Path .git
    if (-not $isGitRepo) {
        Write-Host "✗ This is not a Git repository!" -ForegroundColor Red
        Write-Host "Run 'git init' first or run this script in a Git repository." -ForegroundColor Yellow
        exit 1
    }
}

function Show-Status {
    Write-Host "Current Status" -ForegroundColor Cyan
    Write-Host "==============" -ForegroundColor Cyan
    Write-Host ""

    # Current branch
    $currentBranch = git branch --show-current
    Write-Host "Branch: " -NoNewline -ForegroundColor Yellow
    Write-Host $currentBranch -ForegroundColor White

    # Tracking branch
    $tracking = git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Tracking: " -NoNewline -ForegroundColor Yellow
        Write-Host $tracking -ForegroundColor White
    }

    Write-Host ""

    # Git status
    $status = git status --short
    if ($status) {
        Write-Host "Changes:" -ForegroundColor Yellow
        git status --short | ForEach-Object {
            $color = if ($_ -match '^\?\?') { "Gray" }
                     elseif ($_ -match '^[AM]') { "Green" }
                     elseif ($_ -match '^[DR]') { "Red" }
                     else { "White" }
            Write-Host "  $_" -ForegroundColor $color
        }
    } else {
        Write-Host "✓ Working tree clean" -ForegroundColor Green
    }

    Write-Host ""

    # Recent commits
    Write-Host "Recent commits:" -ForegroundColor Yellow
    git log --oneline --decorate -5 | ForEach-Object {
        Write-Host "  $_" -ForegroundColor White
    }

    Write-Host ""
}

function Do-Pull {
    Write-Host "Pulling from remote..." -ForegroundColor Yellow
    Write-Host ""

    $currentBranch = git branch --show-current
    $tracking = git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ No tracking branch set" -ForegroundColor Red
        Write-Host "Set upstream with: git branch --set-upstream-to=$RemoteName/$currentBranch" -ForegroundColor Yellow
        exit 1
    }

    git pull

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✓ Pull completed successfully!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "✗ Pull failed!" -ForegroundColor Red
        exit 1
    }
}

function Do-Commit {
    param([string]$CommitMessage)

    Write-Host "Creating commit..." -ForegroundColor Yellow
    Write-Host ""

    # Check if there are changes to commit
    $status = git status --short
    if (-not $status) {
        Write-Host "✗ No changes to commit" -ForegroundColor Yellow
        exit 0
    }

    # Show what will be committed
    Write-Host "Files to commit:" -ForegroundColor Yellow
    git status --short | ForEach-Object {
        Write-Host "  $_" -ForegroundColor White
    }
    Write-Host ""

    # Ask for commit message if not provided
    if (-not $CommitMessage) {
        $CommitMessage = Read-Host "Enter commit message"
        if (-not $CommitMessage) {
            Write-Host "✗ Commit message cannot be empty" -ForegroundColor Red
            exit 1
        }
    }

    # Add all changes
    git add .

    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Failed to stage changes" -ForegroundColor Red
        exit 1
    }

    # Commit
    git commit -m $CommitMessage

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✓ Commit created successfully!" -ForegroundColor Green
        Write-Host "Message: $CommitMessage" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "✗ Commit failed!" -ForegroundColor Red
        exit 1
    }
}

function Do-Push {
    param([string]$Remote = "origin")

    Write-Host "Pushing to remote..." -ForegroundColor Yellow
    Write-Host ""

    $currentBranch = git branch --show-current
    $tracking = git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>&1

    # Check if tracking branch exists
    if ($LASTEXITCODE -ne 0) {
        Write-Host "No tracking branch set. Setting up..." -ForegroundColor Yellow
        git push -u $Remote $currentBranch
    } else {
        git push
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✓ Push completed successfully!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "✗ Push failed!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Common issues:" -ForegroundColor Yellow
        Write-Host "  1. Authentication failed - check your credentials" -ForegroundColor White
        Write-Host "  2. No permission - check repository access" -ForegroundColor White
        Write-Host "  3. Remote branch doesn't exist - try: git push -u $Remote $currentBranch" -ForegroundColor White
        exit 1
    }
}

function Do-Sync {
    param([string]$CommitMessage, [string]$Remote = "origin")

    Write-Host "Syncing repository..." -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    Write-Host ""

    # Step 1: Pull
    Write-Host "Step 1/3: Pulling latest changes..." -ForegroundColor Yellow
    Do-Pull
    Write-Host ""

    # Step 2: Commit (if there are changes)
    Write-Host "Step 2/3: Committing changes..." -ForegroundColor Yellow
    $status = git status --short
    if ($status) {
        Do-Commit -CommitMessage $CommitMessage
    } else {
        Write-Host "✓ No changes to commit" -ForegroundColor Green
    }
    Write-Host ""

    # Step 3: Push
    Write-Host "Step 3/3: Pushing to remote..." -ForegroundColor Yellow
    Do-Push -Remote $Remote

    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "  Sync completed successfully!" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host ""
}

function Switch-Branch {
    param([string]$BranchName)

    Write-Host "Switching to branch: $BranchName" -ForegroundColor Yellow
    Write-Host ""

    # Check if branch exists
    $branchExists = git rev-parse --verify $BranchName 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Branch '$BranchName' does not exist" -ForegroundColor Red
        Write-Host ""
        Write-Host "Available branches:" -ForegroundColor Yellow
        git branch -a | ForEach-Object {
            Write-Host "  $_" -ForegroundColor White
        }
        Write-Host ""
        Write-Host "To create a new branch, use: .\git-helper.ps1 -NewBranch $BranchName" -ForegroundColor Cyan
        exit 1
    }

    git checkout $BranchName

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Switched to branch: $BranchName" -ForegroundColor Green
        Write-Host ""
        Show-Status
    } else {
        Write-Host "✗ Failed to switch branch" -ForegroundColor Red
        exit 1
    }
}

function Create-Branch {
    param([string]$BranchName)

    Write-Host "Creating new branch: $BranchName" -ForegroundColor Yellow
    Write-Host ""

    # Check if branch already exists
    $branchExists = git rev-parse --verify $BranchName 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✗ Branch '$BranchName' already exists" -ForegroundColor Red
        $response = Read-Host "Switch to existing branch? (y/n)"
        if ($response -eq 'y' -or $response -eq 'Y') {
            Switch-Branch -BranchName $BranchName
        }
        exit 0
    }

    git checkout -b $BranchName

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Created and switched to branch: $BranchName" -ForegroundColor Green
        Write-Host ""
        Show-Status
    } else {
        Write-Host "✗ Failed to create branch" -ForegroundColor Red
        exit 1
    }
}

function List-Branches {
    Write-Host "All Branches" -ForegroundColor Cyan
    Write-Host "============" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Local branches:" -ForegroundColor Yellow
    git branch | ForEach-Object {
        if ($_ -match '^\*') {
            Write-Host $_ -ForegroundColor Green
        } else {
            Write-Host $_ -ForegroundColor White
        }
    }

    Write-Host ""
    Write-Host "Remote branches:" -ForegroundColor Yellow
    git branch -r | ForEach-Object {
        Write-Host $_ -ForegroundColor Cyan
    }

    Write-Host ""
}

function Show-Remote {
    Write-Host "Remote Information" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    Write-Host ""

    $remotes = git remote -v
    if ($remotes) {
        Write-Host "Configured remotes:" -ForegroundColor Yellow
        $remotes | ForEach-Object {
            Write-Host "  $_" -ForegroundColor White
        }
    } else {
        Write-Host "✗ No remotes configured" -ForegroundColor Red
        Write-Host ""
        Write-Host "To add a remote, use:" -ForegroundColor Yellow
        Write-Host "  .\setup-repo.ps1 -NewRepoUrl <url>" -ForegroundColor White
    }

    Write-Host ""
}

function Show-Log {
    Write-Host "Commit History" -ForegroundColor Cyan
    Write-Host "==============" -ForegroundColor Cyan
    Write-Host ""

    git log --oneline --decorate --graph -20 | ForEach-Object {
        Write-Host $_ -ForegroundColor White
    }

    Write-Host ""
}

# =====================================
# Main Script
# =====================================

Show-Banner
Test-GitRepo

# Handle parameters
if ($Status) {
    Show-Status
    exit 0
}

if ($Pull) {
    Do-Pull
    exit 0
}

if ($Commit) {
    Do-Commit -CommitMessage $Message
    exit 0
}

if ($Push) {
    Do-Push -Remote $RemoteName
    exit 0
}

if ($Sync) {
    if (-not $Message) {
        $Message = Read-Host "Enter commit message"
    }
    Do-Sync -CommitMessage $Message -Remote $RemoteName
    exit 0
}

if ($Branch) {
    Switch-Branch -BranchName $Branch
    exit 0
}

if ($NewBranch) {
    Create-Branch -BranchName $NewBranch
    exit 0
}

if ($List) {
    List-Branches
    exit 0
}

if ($Remote) {
    Show-Remote
    exit 0
}

if ($Log) {
    Show-Log
    exit 0
}

# If no parameters, show status and help
Show-Status

Write-Host "---------------------------------------" -ForegroundColor Cyan
Write-Host ""
Write-Host "Quick Commands:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Status & Info:" -ForegroundColor Yellow
Write-Host "    .\git-helper.ps1 -Status           # Show current status" -ForegroundColor White
Write-Host "    .\git-helper.ps1 -Log              # Show commit history" -ForegroundColor White
Write-Host "    .\git-helper.ps1 -Remote           # Show remote info" -ForegroundColor White
Write-Host ""
Write-Host "  Basic Operations:" -ForegroundColor Yellow
Write-Host "    .\git-helper.ps1 -Pull             # Pull latest changes" -ForegroundColor White
Write-Host "    .\git-helper.ps1 -Commit -Message 'msg'  # Commit changes" -ForegroundColor White
Write-Host "    .\git-helper.ps1 -Push             # Push to remote" -ForegroundColor White
Write-Host ""
Write-Host "  Quick Sync:" -ForegroundColor Yellow
Write-Host "    .\git-helper.ps1 -Sync -Message 'msg'    # Pull + Commit + Push" -ForegroundColor White
Write-Host ""
Write-Host "  Branch Management:" -ForegroundColor Yellow
Write-Host "    .\git-helper.ps1 -List             # List all branches" -ForegroundColor White
Write-Host "    .\git-helper.ps1 -Branch main      # Switch to branch" -ForegroundColor White
Write-Host "    .\git-helper.ps1 -NewBranch feat   # Create new branch" -ForegroundColor White
Write-Host ""
Write-Host "For repository setup, use: .\setup-repo.ps1" -ForegroundColor Cyan
Write-Host ""
