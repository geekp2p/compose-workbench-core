#!/usr/bin/env pwsh
<#
.SYNOPSIS
    จัดการหลาย repos พร้อมกัน (compose-workbench-core-1, -2, -3, etc.)

.DESCRIPTION
    Script นี้ช่วยให้คุณจัดการหลาย repos พร้อมกันได้ง่ายๆ
    - Auto detect repos ทั้งหมด
    - Run commands ทุก repos พร้อมกัน
    - Git operations (pull, push, status)

.PARAMETER List
    แสดงรายการ repos ทั้งหมด

.PARAMETER Command
    รันคำสั่งใน repos ทั้งหมด

.PARAMETER Path
    Path ที่เก็บ repos (default: parent directory)

.PARAMETER Pattern
    Pattern สำหรับหา repos (default: compose-workbench-core*)

.PARAMETER GitPull
    Git pull ทุก repos

.PARAMETER GitStatus
    Git status ทุก repos

.PARAMETER GitPush
    Git push ทุก repos

.EXAMPLE
    .\repos-manager.ps1 -List
    แสดง repos ทั้งหมด

.EXAMPLE
    .\repos-manager.ps1 -GitStatus
    Git status ทุก repos

.EXAMPLE
    .\repos-manager.ps1 -GitPull
    Git pull ทุก repos

.EXAMPLE
    .\repos-manager.ps1 -Command "git status"
    รันคำสั่ง git status ใน repos ทั้งหมด

.EXAMPLE
    .\repos-manager.ps1 -Command "docker compose ps" -Pattern "compose-*"
    รันคำสั่งใน repos ที่ match pattern
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$List,

    [Parameter(Mandatory=$false)]
    [string]$Command = "",

    [Parameter(Mandatory=$false)]
    [string]$Path = "",

    [Parameter(Mandatory=$false)]
    [string]$Pattern = "compose-workbench-core*",

    [Parameter(Mandatory=$false)]
    [switch]$GitPull,

    [Parameter(Mandatory=$false)]
    [switch]$GitStatus,

    [Parameter(Mandatory=$false)]
    [switch]$GitPush
)

$ErrorActionPreference = "Stop"

# Colors
function Write-Header($msg) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  $msg" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-RepoHeader($repo) {
    Write-Host ""
    Write-Host "📁 $repo" -ForegroundColor Yellow
    Write-Host ("─" * 50) -ForegroundColor Gray
}

function Write-Success($msg) { Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Err($msg) { Write-Host "❌ $msg" -ForegroundColor Red }
function Write-Info($msg) { Write-Host $msg -ForegroundColor Cyan }

# Get base path
if ([string]::IsNullOrWhiteSpace($Path)) {
    # Use parent directory of current location
    $basePath = Split-Path -Parent $PWD
} else {
    $basePath = $Path
}

if (-not (Test-Path $basePath)) {
    Write-Err "Path not found: $basePath"
    exit 1
}

# Find all repos
Write-Info "🔍 Searching for repos in: $basePath"
Write-Info "   Pattern: $Pattern"
Write-Host ""

$repos = Get-ChildItem -Path $basePath -Directory -Filter $Pattern | Where-Object {
    Test-Path (Join-Path $_.FullName ".git")
}

if ($repos.Count -eq 0) {
    Write-Err "No repos found matching pattern: $Pattern"
    Write-Host ""
    Write-Info "Try:"
    Write-Host "  .\repos-manager.ps1 -List -Pattern '*'" -ForegroundColor Yellow
    exit 1
}

Write-Success "Found $($repos.Count) repo(s)"

# List repos
if ($List -or (-not $Command -and -not $GitPull -and -not $GitStatus -and -not $GitPush)) {
    Write-Header "📋 Repositories"

    foreach ($repo in $repos) {
        $repoPath = $repo.FullName
        Push-Location $repoPath

        try {
            $branch = git rev-parse --abbrev-ref HEAD 2>$null
            $status = git status --short 2>$null

            Write-Host "📁 " -NoNewline -ForegroundColor Yellow
            Write-Host $repo.Name -NoNewline -ForegroundColor White
            Write-Host " [$branch]" -ForegroundColor Cyan

            if ($status) {
                Write-Host "   └─ " -NoNewline -ForegroundColor Gray
                Write-Host "$($status.Count) changes" -ForegroundColor Yellow
            } else {
                Write-Host "   └─ " -NoNewline -ForegroundColor Gray
                Write-Host "clean" -ForegroundColor Green
            }

            Write-Host "   Path: $repoPath" -ForegroundColor DarkGray
        } catch {
            Write-Host "📁 " -NoNewline -ForegroundColor Yellow
            Write-Host $repo.Name -ForegroundColor White
            Write-Host "   └─ " -NoNewline -ForegroundColor Gray
            Write-Host "Error reading git info" -ForegroundColor Red
        } finally {
            Pop-Location
        }
    }

    Write-Host ""
    Write-Info "Total: $($repos.Count) repo(s)"
    Write-Host ""
    exit 0
}

# Git Status
if ($GitStatus) {
    Write-Header "📊 Git Status - All Repos"

    foreach ($repo in $repos) {
        Write-RepoHeader $repo.Name

        Push-Location $repo.FullName
        try {
            git status
        } catch {
            Write-Err "Failed: $_"
        } finally {
            Pop-Location
        }
    }

    Write-Host ""
    exit 0
}

# Git Pull
if ($GitPull) {
    Write-Header "⬇️  Git Pull - All Repos"

    $successCount = 0
    $failCount = 0

    foreach ($repo in $repos) {
        Write-RepoHeader $repo.Name

        Push-Location $repo.FullName
        try {
            $branch = git rev-parse --abbrev-ref HEAD
            Write-Info "Branch: $branch"

            git pull origin $branch

            Write-Success "Pulled successfully"
            $successCount++
        } catch {
            Write-Err "Failed: $_"
            $failCount++
        } finally {
            Pop-Location
        }
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Success "Success: $successCount"
    if ($failCount -gt 0) {
        Write-Err "Failed: $failCount"
    }
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    exit 0
}

# Git Push
if ($GitPush) {
    Write-Header "⬆️  Git Push - All Repos"

    Write-Host "⚠️  " -NoNewline -ForegroundColor Yellow
    Write-Host "This will push ALL repos!" -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "Continue? (y/n)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Info "Cancelled."
        exit 0
    }

    $successCount = 0
    $failCount = 0

    foreach ($repo in $repos) {
        Write-RepoHeader $repo.Name

        Push-Location $repo.FullName
        try {
            $branch = git rev-parse --abbrev-ref HEAD
            Write-Info "Branch: $branch"

            # Check if there are changes
            $status = git status --short
            if (-not $status) {
                Write-Info "No changes to push"
                continue
            }

            # Push with retry logic
            $maxRetries = 4
            $retryDelay = 2
            $pushed = $false

            for ($i = 0; $i -le $maxRetries; $i++) {
                if ($i -gt 0) {
                    Write-Host "Retry $i/$maxRetries (waiting ${retryDelay}s...)" -ForegroundColor Yellow
                    Start-Sleep -Seconds $retryDelay
                    $retryDelay = $retryDelay * 2
                }

                try {
                    git push -u origin $branch
                    $pushed = $true
                    break
                } catch {
                    if ($i -lt $maxRetries) {
                        Write-Host "Push failed, retrying..." -ForegroundColor Yellow
                    }
                }
            }

            if ($pushed) {
                Write-Success "Pushed successfully"
                $successCount++
            } else {
                Write-Err "Failed after $maxRetries retries"
                $failCount++
            }
        } catch {
            Write-Err "Failed: $_"
            $failCount++
        } finally {
            Pop-Location
        }
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Success "Success: $successCount"
    if ($failCount -gt 0) {
        Write-Err "Failed: $failCount"
    }
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    exit 0
}

# Custom Command
if ($Command) {
    Write-Header "🚀 Running Command - All Repos"

    Write-Info "Command: $Command"
    Write-Host ""

    foreach ($repo in $repos) {
        Write-RepoHeader $repo.Name

        Push-Location $repo.FullName
        try {
            Invoke-Expression $Command
        } catch {
            Write-Err "Failed: $_"
        } finally {
            Pop-Location
        }
    }

    Write-Host ""
    exit 0
}

# Show help if no parameters
Write-Header "📚 Repos Manager Help"

Write-Info "Usage:"
Write-Host "  .\repos-manager.ps1 -List" -ForegroundColor Yellow
Write-Host "  .\repos-manager.ps1 -GitStatus" -ForegroundColor Yellow
Write-Host "  .\repos-manager.ps1 -GitPull" -ForegroundColor Yellow
Write-Host "  .\repos-manager.ps1 -GitPush" -ForegroundColor Yellow
Write-Host "  .\repos-manager.ps1 -Command `"git status`"" -ForegroundColor Yellow
Write-Host ""

Write-Info "Examples:"
Write-Host "  List all repos:" -ForegroundColor Cyan
Write-Host "    .\repos-manager.ps1 -List" -ForegroundColor Gray
Write-Host ""
Write-Host "  Git status all repos:" -ForegroundColor Cyan
Write-Host "    .\repos-manager.ps1 -GitStatus" -ForegroundColor Gray
Write-Host ""
Write-Host "  Pull all repos:" -ForegroundColor Cyan
Write-Host "    .\repos-manager.ps1 -GitPull" -ForegroundColor Gray
Write-Host ""
Write-Host "  Custom command:" -ForegroundColor Cyan
Write-Host "    .\repos-manager.ps1 -Command `"docker compose ps`"" -ForegroundColor Gray
Write-Host ""

exit 0
