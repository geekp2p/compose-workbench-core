#!/usr/bin/env pwsh
# P2P Chat GitHub Release Upload Script
# Automatically creates tags and uploads release binaries
# Compatible with PowerShell 5.1+ and PowerShell Core 7+

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Version = "",

    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false
)

# Set strict mode
$ErrorActionPreference = "Stop"

# Configuration
$APP_NAME = "p2p-chat"
$DIST_DIR = "..\..\dist"
$REPO = "geekp2p/compose-workbench-core"

# Color functions for output
function Write-ColorOutput {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Red", "Green", "Yellow", "Blue", "Cyan", "White", "Magenta")]
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Print banner
Write-Host ""
Write-ColorOutput "+===================================================+" -Color Blue
Write-ColorOutput "|     P2P Chat GitHub Release Uploader             |" -Color Blue
Write-ColorOutput "+===================================================+" -Color Blue
Write-Host ""

# Get version from argument or extract from updater.go
if ([string]::IsNullOrEmpty($Version)) {
    try {
        $updaterFile = "internal\updater\updater.go"
        if (Test-Path $updaterFile) {
            $content = Get-Content $updaterFile -Raw
            $versionPattern = 'var Version = "([^"]+)"'
            if ($content -match $versionPattern) {
                $Version = $Matches[1]
                Write-ColorOutput "Using version from updater.go: $Version" -Color Cyan
            } else {
                Write-ColorOutput "Error: Could not extract version from updater.go" -Color Red
                exit 1
            }
        } else {
            Write-ColorOutput "Error: updater.go not found at $updaterFile" -Color Red
            exit 1
        }
    }
    catch {
        Write-ColorOutput "Error reading version: $_" -Color Red
        exit 1
    }
} else {
    Write-ColorOutput "Using specified version: $Version" -Color Green
}

$TAG_NAME = "${APP_NAME}-v${Version}"
Write-Host ""

# Check if gh CLI is installed
try {
    $ghVersion = & gh version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "Error: GitHub CLI (gh) is not installed" -Color Red
        Write-ColorOutput "Install from: https://cli.github.com/" -Color Yellow
        exit 1
    }
    Write-ColorOutput "[OK] GitHub CLI is installed" -Color Green
    Write-Host ""
}
catch {
    Write-ColorOutput "Error: GitHub CLI (gh) is not installed" -Color Red
    Write-ColorOutput "Install from: https://cli.github.com/" -Color Yellow
    exit 1
}

# Check if authenticated
try {
    $authStatus = & gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "Error: Not authenticated with GitHub" -Color Red
        Write-ColorOutput "Run: gh auth login" -Color Yellow
        exit 1
    }
    Write-ColorOutput "[OK] Authenticated with GitHub" -Color Green
    Write-Host ""
}
catch {
    Write-ColorOutput "Error: Not authenticated with GitHub" -Color Red
    Write-ColorOutput "Run: gh auth login" -Color Yellow
    exit 1
}

# Check if dist directory exists
if (-not (Test-Path $DIST_DIR)) {
    Write-ColorOutput "Error: Distribution directory not found: $DIST_DIR" -Color Red
    Write-ColorOutput "Run build-release.ps1 or build-release.cmd first" -Color Yellow
    exit 1
}

# Count binaries
$binaries = Get-ChildItem -Path $DIST_DIR -Filter "${APP_NAME}-*" -File
if ($binaries.Count -eq 0) {
    Write-ColorOutput "Error: No binaries found in $DIST_DIR" -Color Red
    Write-ColorOutput "Run build-release.ps1 or build-release.cmd first" -Color Yellow
    exit 1
}

Write-ColorOutput "Found $($binaries.Count) binaries to upload:" -Color Green
foreach ($binary in $binaries) {
    $size = $binary.Length
    $sizeMB = [math]::Round($size / 1MB, 2)
    Write-Host "  - $($binary.Name) ($sizeMB MB)"
}
Write-Host ""

# Check for checksums file
$checksumFile = Join-Path $DIST_DIR "checksums.txt"
if (Test-Path $checksumFile) {
    Write-ColorOutput "[OK] Checksums file found" -Color Green
} else {
    Write-ColorOutput "Warning: checksums.txt not found" -Color Yellow
}
Write-Host ""

# Check if tag already exists
Write-ColorOutput "Checking if tag $TAG_NAME exists..." -Color Blue
$tagExists = $false
try {
    $null = & git rev-parse $TAG_NAME 2>&1
    if ($LASTEXITCODE -eq 0) {
        $tagExists = $true
        Write-ColorOutput "Tag $TAG_NAME already exists locally" -Color Yellow
    }
}
catch {
    # Tag doesn't exist, that's fine
}

# Check remote tag
try {
    $remoteTags = & git ls-remote --tags origin $TAG_NAME 2>&1
    if ($remoteTags -and $remoteTags.Length -gt 0) {
        Write-ColorOutput "Tag $TAG_NAME already exists on remote" -Color Yellow
        Write-ColorOutput "Error: Release tag already exists. Increment version or delete the tag first." -Color Red
        exit 1
    }
}
catch {
    # Tag doesn't exist on remote, that's fine
}

if (-not $tagExists) {
    Write-ColorOutput "Creating tag $TAG_NAME..." -Color Blue

    if ($DryRun) {
        Write-ColorOutput "[DRY RUN] Would create tag: $TAG_NAME" -Color Magenta
    } else {
        try {
            & git tag -a $TAG_NAME -m "Release v${Version}"
            if ($LASTEXITCODE -ne 0) {
                Write-ColorOutput "Error: Failed to create tag" -Color Red
                exit 1
            }
            Write-ColorOutput "[OK] Tag created: $TAG_NAME" -Color Green
        }
        catch {
            Write-ColorOutput "Error creating tag: $_" -Color Red
            exit 1
        }
    }
    Write-Host ""
}

# Push tag to remote
Write-ColorOutput "Pushing tag to remote..." -Color Blue
if ($DryRun) {
    Write-ColorOutput "[DRY RUN] Would push tag to origin" -Color Magenta
} else {
    try {
        & git push origin $TAG_NAME
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Error: Failed to push tag" -Color Red
            exit 1
        }
        Write-ColorOutput "[OK] Tag pushed to remote" -Color Green
    }
    catch {
        Write-ColorOutput "Error pushing tag: $_" -Color Red
        exit 1
    }
}
Write-Host ""

# Create GitHub release
Write-ColorOutput "Creating GitHub release..." -Color Blue

$releaseNotes = @"
# P2P Chat v${Version}

Cross-platform P2P chat application built with libp2p.

## Features
- Decentralized peer-to-peer messaging
- Auto-discovery on local network
- Topic-based chat rooms
- Cross-platform support (Linux, Windows, macOS)
- Multi-architecture support (amd64, arm64)

## Installation

Download the appropriate binary for your platform:

**Linux (amd64):**
``````bash
wget https://github.com/${REPO}/releases/download/${TAG_NAME}/p2p-chat-linux-amd64
chmod +x p2p-chat-linux-amd64
./p2p-chat-linux-amd64
``````

**Linux (arm64):**
``````bash
wget https://github.com/${REPO}/releases/download/${TAG_NAME}/p2p-chat-linux-arm64
chmod +x p2p-chat-linux-arm64
./p2p-chat-linux-arm64
``````

**Windows (amd64):**
Download and run: [p2p-chat-windows-amd64.exe](https://github.com/${REPO}/releases/download/${TAG_NAME}/p2p-chat-windows-amd64.exe)

**macOS (Intel):**
``````bash
wget https://github.com/${REPO}/releases/download/${TAG_NAME}/p2p-chat-darwin-amd64
chmod +x p2p-chat-darwin-amd64
./p2p-chat-darwin-amd64
``````

**macOS (Apple Silicon):**
``````bash
wget https://github.com/${REPO}/releases/download/${TAG_NAME}/p2p-chat-darwin-arm64
chmod +x p2p-chat-darwin-arm64
./p2p-chat-darwin-arm64
``````

## Verification

Verify the downloaded binary using SHA256 checksums:

``````bash
sha256sum -c checksums.txt
``````

## What's New in v${Version}
- Initial release
- Basic P2P chat functionality
- Support for 6 platforms (Linux, Windows, macOS on amd64 and arm64)
"@

if ($DryRun) {
    Write-ColorOutput "[DRY RUN] Would create release with:" -Color Magenta
    Write-Host "  Tag: $TAG_NAME"
    Write-Host "  Title: P2P Chat v${Version}"
    Write-Host "  Files: $($binaries.Count) binaries + checksums.txt"
} else {
    try {
        # Create release with gh CLI
        $releaseNotesFile = [System.IO.Path]::GetTempFileName()
        $releaseNotes | Out-File -FilePath $releaseNotesFile -Encoding utf8

        & gh release create $TAG_NAME `
            --repo $REPO `
            --title "P2P Chat v${Version}" `
            --notes-file $releaseNotesFile

        Remove-Item $releaseNotesFile -Force

        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Error: Failed to create GitHub release" -Color Red
            exit 1
        }
        Write-ColorOutput "[OK] GitHub release created" -Color Green
    }
    catch {
        Write-ColorOutput "Error creating release: $_" -Color Red
        exit 1
    }
}
Write-Host ""

# Upload binaries
Write-ColorOutput "Uploading binaries to release..." -Color Blue
Write-Host ""

$uploadSuccess = 0
$uploadFailed = 0

foreach ($binary in $binaries) {
    Write-ColorOutput "Uploading $($binary.Name)..." -Color Yellow

    if ($DryRun) {
        Write-ColorOutput "[DRY RUN] Would upload: $($binary.Name)" -Color Magenta
        $uploadSuccess++
    } else {
        try {
            & gh release upload $TAG_NAME $binary.FullName --repo $REPO --clobber
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "[OK] Uploaded: $($binary.Name)" -Color Green
                $uploadSuccess++
            } else {
                Write-ColorOutput "[FAIL] Failed to upload: $($binary.Name)" -Color Red
                $uploadFailed++
            }
        }
        catch {
            Write-ColorOutput "[FAIL] Failed to upload: $($binary.Name) - $_" -Color Red
            $uploadFailed++
        }
    }
}

# Upload checksums
if (Test-Path $checksumFile) {
    Write-Host ""
    Write-ColorOutput "Uploading checksums.txt..." -Color Yellow

    if ($DryRun) {
        Write-ColorOutput "[DRY RUN] Would upload: checksums.txt" -Color Magenta
    } else {
        try {
            & gh release upload $TAG_NAME $checksumFile --repo $REPO --clobber
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "[OK] Uploaded: checksums.txt" -Color Green
            } else {
                Write-ColorOutput "[FAIL] Failed to upload checksums.txt" -Color Red
                $uploadFailed++
            }
        }
        catch {
            Write-ColorOutput "[FAIL] Failed to upload checksums.txt - $_" -Color Red
            $uploadFailed++
        }
    }
}

Write-Host ""

# Summary
Write-ColorOutput "+===================================================+" -Color Blue
Write-ColorOutput "|              Upload Summary                       |" -Color Blue
Write-ColorOutput "+===================================================+" -Color Blue
Write-ColorOutput "Version:     $Version" -Color Green
Write-ColorOutput "Tag:         $TAG_NAME" -Color Green
Write-ColorOutput "Uploaded:    $uploadSuccess files" -Color Green
if ($uploadFailed -gt 0) {
    Write-ColorOutput "Failed:      $uploadFailed files" -Color Red
}
Write-Host ""

if ($DryRun) {
    Write-ColorOutput "[DRY RUN] No actual changes were made" -Color Magenta
    Write-ColorOutput "Run without -DryRun to perform the upload" -Color Yellow
} else {
    Write-ColorOutput "[OK] Release upload completed!" -Color Green
    Write-Host ""
    Write-ColorOutput "View release at:" -Color Blue
    Write-Host "  https://github.com/${REPO}/releases/tag/${TAG_NAME}"
}

Write-Host ""
