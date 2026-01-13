#!/usr/bin/env pwsh
# P2P Chat Multi-Platform Build Script for Windows
# Builds binaries for Linux, Windows, and macOS (amd64 & arm64)
# Compatible with PowerShell 5.1+ and PowerShell Core 7+

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Version = ""
)

# Set strict mode
$ErrorActionPreference = "Stop"

# Configuration
$APP_NAME = "p2p-chat"
$DIST_DIR = "..\..\dist"
$GO_MODULE = "github.com/geekp2p/p2p-chat-go"

# Platforms to build
$PLATFORMS = @(
    @{ OS = "linux"; Arch = "amd64" },
    @{ OS = "linux"; Arch = "arm64" },
    @{ OS = "windows"; Arch = "amd64" },
    @{ OS = "windows"; Arch = "arm64" },
    @{ OS = "darwin"; Arch = "amd64" },
    @{ OS = "darwin"; Arch = "arm64" }
)

# Color functions for output
function Write-ColorOutput {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Red", "Green", "Yellow", "Blue", "Cyan", "White")]
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Print banner
Write-Host ""
Write-ColorOutput "====================================================" -Color Blue
Write-ColorOutput "    P2P Chat Multi-Platform Build System           " -Color Blue
Write-ColorOutput "    Windows PowerShell Version                     " -Color Blue
Write-ColorOutput "====================================================" -Color Blue
Write-Host ""

# Get version from argument or extract from updater.go
if ([string]::IsNullOrEmpty($Version)) {
    try {
        $updaterFile = "internal\updater\updater.go"
        if (Test-Path $updaterFile) {
            $content = Get-Content $updaterFile -Raw
            if ($content -match 'var Version = "(.+?)"') {
                $Version = $Matches[1]
                Write-ColorOutput "No version specified, using version from updater.go: $Version" -Color Yellow
            } else {
                $Version = "0.1.0"
                Write-ColorOutput "Could not extract version from updater.go, using default: $Version" -Color Yellow
            }
        } else {
            $Version = "0.1.0"
            Write-ColorOutput "updater.go not found, using default version: $Version" -Color Yellow
        }
    }
    catch {
        $Version = "0.1.0"
        Write-ColorOutput "Error reading version, using default: $Version" -Color Yellow
    }
} else {
    Write-ColorOutput "Building version: $Version" -Color Green
}

Write-ColorOutput "Building v$Version" -Color Cyan
Write-Host ""

# Check if Go is installed
try {
    $goVersion = & go version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "Error: Go is not installed or not in PATH" -Color Red
        exit 1
    }
    Write-ColorOutput "✓ Go version: $goVersion" -Color Green
    Write-Host ""
}
catch {
    Write-ColorOutput "Error: Go is not installed or not in PATH" -Color Red
    exit 1
}

# Create dist directory
Write-ColorOutput "Creating distribution directory..." -Color Blue
if (Test-Path $DIST_DIR) {
    Remove-Item -Path $DIST_DIR -Recurse -Force
}
New-Item -ItemType Directory -Path $DIST_DIR -Force | Out-Null
Write-ColorOutput "✓ Created: $DIST_DIR" -Color Green
Write-Host ""

# Build for each platform
Write-ColorOutput "Building binaries for $($PLATFORMS.Count) platforms..." -Color Blue
Write-Host ""

$buildSuccess = 0
$buildFailed = 0

foreach ($platform in $PLATFORMS) {
    $GOOS = $platform.OS
    $GOARCH = $platform.Arch

    # Determine output filename
    $OUTPUT_NAME = "${APP_NAME}-${GOOS}-${GOARCH}"
    if ($GOOS -eq "windows") {
        $OUTPUT_NAME = "${OUTPUT_NAME}.exe"
    }

    $OUTPUT_PATH = Join-Path $DIST_DIR $OUTPUT_NAME

    # Build
    Write-ColorOutput "Building ${GOOS}/${GOARCH}..." -Color Yellow

    # Set build flags
    $LDFLAGS = "-s -w -X ${GO_MODULE}/internal/updater.Version=${Version}"

    # Set environment variables and build
    $env:GOOS = $GOOS
    $env:GOARCH = $GOARCH
    $env:CGO_ENABLED = "0"

    try {
        $buildOutput = & go build -ldflags="$LDFLAGS" -o $OUTPUT_PATH . 2>&1

        if ($LASTEXITCODE -eq 0 -and (Test-Path $OUTPUT_PATH)) {
            $fileSize = (Get-Item $OUTPUT_PATH).Length
            $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
            $fileSizeKB = [math]::Round($fileSize / 1KB, 2)

            if ($fileSizeMB -ge 1) {
                $sizeStr = "${fileSizeMB}MB"
            } else {
                $sizeStr = "${fileSizeKB}KB"
            }

            Write-ColorOutput "✓ Built: $OUTPUT_NAME ($sizeStr)" -Color Green
            Write-Host ""
            $buildSuccess++
        } else {
            Write-ColorOutput "✗ Failed to build $OUTPUT_NAME" -Color Red
            Write-ColorOutput "Error: $buildOutput" -Color Red
            Write-Host ""
            $buildFailed++
        }
    }
    catch {
        Write-ColorOutput "✗ Failed to build $OUTPUT_NAME" -Color Red
        Write-ColorOutput "Error: $_" -Color Red
        Write-Host ""
        $buildFailed++
    }
}

# Check if any builds failed
if ($buildFailed -gt 0) {
    Write-ColorOutput "Warning: $buildFailed build(s) failed" -Color Yellow
    if ($buildSuccess -eq 0) {
        Write-ColorOutput "Error: All builds failed" -Color Red
        exit 1
    }
}

# Generate checksums
Write-ColorOutput "Generating SHA256 checksums..." -Color Blue

$CHECKSUM_FILE = Join-Path $DIST_DIR "checksums.txt"
if (Test-Path $CHECKSUM_FILE) {
    Remove-Item $CHECKSUM_FILE -Force
}

$checksumContent = @()
Get-ChildItem -Path $DIST_DIR -Filter "p2p-chat-*" -File | ForEach-Object {
    try {
        $hash = Get-FileHash -Path $_.FullName -Algorithm SHA256
        $checksumLine = "$($hash.Hash.ToLower())  $($_.Name)"
        $checksumContent += $checksumLine
    }
    catch {
        Write-ColorOutput "Warning: Could not generate checksum for $($_.Name)" -Color Yellow
    }
}

if ($checksumContent.Count -gt 0) {
    $checksumContent | Out-File -FilePath $CHECKSUM_FILE -Encoding utf8
    Write-ColorOutput "✓ Checksums generated: checksums.txt" -Color Green
    Write-Host ""
}

# Summary
Write-ColorOutput "====================================================" -Color Blue
Write-ColorOutput "              Build Summary                         " -Color Blue
Write-ColorOutput "====================================================" -Color Blue
Write-ColorOutput "Version:     $Version" -Color Green
Write-ColorOutput "Directory:   $DIST_DIR" -Color Green
Write-ColorOutput "Binaries:    $buildSuccess successful, $buildFailed failed" -Color Green
Write-Host ""

Write-ColorOutput "Binaries created:" -Color Yellow
Get-ChildItem -Path $DIST_DIR -File | ForEach-Object {
    $size = $_.Length
    $sizeMB = [math]::Round($size / 1MB, 2)
    $sizeKB = [math]::Round($size / 1KB, 2)

    if ($sizeMB -ge 1) {
        $sizeStr = "${sizeMB}MB"
    } else {
        $sizeStr = "${sizeKB}KB"
    }

    Write-Host "  $($_.Name) - $sizeStr"
}

Write-Host ""
Write-ColorOutput "✓ Build completed successfully!" -Color Green
Write-Host ""

Write-ColorOutput "To test binaries:" -Color Blue
Write-Host "  Windows: $DIST_DIR\p2p-chat-windows-amd64.exe"
Write-Host "  Linux:   $DIST_DIR\p2p-chat-linux-amd64"
Write-Host "  macOS:   $DIST_DIR\p2p-chat-darwin-amd64"
Write-Host ""

Write-ColorOutput "To create a GitHub release:" -Color Blue
Write-Host "  git tag p2p-chat-v$Version"
Write-Host "  git push origin p2p-chat-v$Version"
Write-Host ""

# Reset environment variables
Remove-Item Env:\GOOS -ErrorAction SilentlyContinue
Remove-Item Env:\GOARCH -ErrorAction SilentlyContinue
Remove-Item Env:\CGO_ENABLED -ErrorAction SilentlyContinue
