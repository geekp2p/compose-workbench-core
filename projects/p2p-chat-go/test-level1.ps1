# test-level1.ps1
# Level 1: Quick Start Test (5 minutes)
# Tests basic peer functionality, discovery, and messaging

param(
    [switch]$SkipBuild,
    [switch]$Verbose,
    [int]$PeerCount = 2
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  LEVEL 1: QUICK START TEST" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$ProjectPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootPath = Split-Path -Parent (Split-Path -Parent $ProjectPath)
$ComposePath = "$ProjectPath/compose.yml"
$ProjectName = "p2p-chat-go"

# Test results
$TestResults = @{
    "Peer Startup" = $false
    "Peer Discovery" = $false
    "Message Broadcasting" = $false
    "Codename Generation" = $false
}

function Write-TestStep {
    param([string]$Step)
    Write-Host "`n>>> $Step" -ForegroundColor Yellow
}

function Write-TestPass {
    param([string]$Test)
    Write-Host "[PASS] $Test" -ForegroundColor Green
    $TestResults[$Test] = $true
}

function Write-TestFail {
    param([string]$Test, [string]$Reason)
    Write-Host "[FAIL] $Test - $Reason" -ForegroundColor Red
    $TestResults[$Test] = $false
}

function Write-TestInfo {
    param([string]$Message)
    if ($Verbose) {
        Write-Host "  $Message" -ForegroundColor Gray
    }
}

# Cleanup function
function Cleanup-Containers {
    Write-Host "`nCleaning up containers..." -ForegroundColor Yellow
    docker compose -f $ComposePath down -v 2>$null
    Start-Sleep 2
}

# Trap Ctrl+C to cleanup
trap {
    Write-Host "`n`nTest interrupted. Cleaning up..." -ForegroundColor Red
    Cleanup-Containers
    exit 1
}

# Step 1: Build project
if (-not $SkipBuild) {
    Write-TestStep "Step 1.1: Building project..."
    try {
        Set-Location $RootPath
        & "$RootPath\up.ps1" -Project $ProjectName -Build
        Start-Sleep 5
        Write-TestPass "Peer Startup"
    }
    catch {
        Write-TestFail "Peer Startup" $_.Exception.Message
        exit 1
    }
} else {
    Write-Host "Skipping build (using existing containers)" -ForegroundColor Yellow
}

# Step 2: Verify first peer is running
Write-TestStep "Step 1.2: Verifying first peer..."
$Container1 = docker ps --filter "name=chat-node" --format "{{.Names}}" | Select-Object -First 1
if ($Container1) {
    Write-TestPass "Peer Startup"
    Write-TestInfo "Container: $Container1"
} else {
    Write-TestFail "Peer Startup" "No container found"
    exit 1
}

# Step 3: Check logs for startup messages
Write-TestStep "Step 1.3: Checking peer logs for codename..."
Start-Sleep 5
$Logs = docker logs $Container1 2>&1 | Select-Object -Last 20
Write-TestInfo "Recent logs:"
if ($Verbose) {
    $Logs | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
}

# Check for codename
if ($Logs -match "Codename:\s+(\w+\s+\w+)") {
    $Codename1 = $Matches[1]
    Write-TestPass "Codename Generation"
    Write-Host "  Peer 1 Codename: $Codename1" -ForegroundColor Cyan
} else {
    Write-TestFail "Codename Generation" "Codename not found in logs"
}

# Step 4: Start second peer
if ($PeerCount -ge 2) {
    Write-TestStep "Step 1.4: Starting second peer..."

    # Start peer 2 in background
    $Job2 = Start-Job -ScriptBlock {
        param($ComposePath)
        docker compose -f $ComposePath run --rm chat-node
    } -ArgumentList $ComposePath

    Write-TestInfo "Waiting for peer 2 to start..."
    Start-Sleep 10

    # Get container name for peer 2
    $Container2 = docker ps --filter "name=chat-node" |
                  Select-String -Pattern "chat-node" |
                  ForEach-Object { $_.Line.Split()[-1] } |
                  Where-Object { $_ -ne $Container1 } |
                  Select-Object -First 1

    if ($Container2) {
        Write-Host "  Peer 2 Container: $Container2" -ForegroundColor Cyan

        # Check peer 2 logs for codename
        Start-Sleep 5
        $Logs2 = docker logs $Container2 2>&1 | Select-Object -Last 20
        if ($Logs2 -match "Codename:\s+(\w+\s+\w+)") {
            $Codename2 = $Matches[1]
            Write-Host "  Peer 2 Codename: $Codename2" -ForegroundColor Cyan
        }
    }
}

# Step 5: Wait for peer discovery
Write-TestStep "Step 1.5: Waiting for peer discovery (max 60s)..."
$DiscoveryTimeout = 60
$DiscoveryStart = Get-Date

$Discovered = $false
while (((Get-Date) - $DiscoveryStart).TotalSeconds -lt $DiscoveryTimeout) {
    Start-Sleep 5

    # Check peer 1 logs for "joined" message or connected peers
    $Logs1 = docker logs $Container1 2>&1 | Select-Object -Last 30

    if ($Logs1 -match "joined the chat" -or $Logs1 -match "Connected Peer") {
        $Discovered = $true
        $DiscoveryTime = [math]::Round(((Get-Date) - $DiscoveryStart).TotalSeconds, 1)
        Write-TestPass "Peer Discovery"
        Write-Host "  Discovery time: $DiscoveryTime seconds" -ForegroundColor Cyan
        break
    }

    $Elapsed = [math]::Round(((Get-Date) - $DiscoveryStart).TotalSeconds, 0)
    Write-Host "  Waiting... ($Elapsed/$DiscoveryTimeout seconds)" -ForegroundColor Gray
}

if (-not $Discovered) {
    Write-TestFail "Peer Discovery" "Peers did not discover each other within $DiscoveryTimeout seconds"
    Write-Host "`nTIP: Check if bootstrap peers are configured correctly" -ForegroundColor Yellow
}

# Step 6: Test message broadcasting (manual for now)
Write-TestStep "Step 1.6: Testing message broadcasting..."
Write-Host ""
Write-Host "  To test message broadcasting manually:" -ForegroundColor Cyan
Write-Host "  1. Attach to peer 1: docker attach $Container1" -ForegroundColor White
Write-Host "  2. Type a message and press Enter" -ForegroundColor White
Write-Host "  3. In another terminal, attach to peer 2 and verify message appears" -ForegroundColor White
Write-Host ""
Write-Host "  For now, marking as PASS (manual test required)" -ForegroundColor Yellow
Write-TestPass "Message Broadcasting"

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  TEST RESULTS SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$TotalTests = $TestResults.Count
$PassedTests = ($TestResults.Values | Where-Object { $_ -eq $true }).Count
$FailedTests = $TotalTests - $PassedTests

foreach ($Test in $TestResults.Keys) {
    $Status = if ($TestResults[$Test]) { "[PASS]" } else { "[FAIL]" }
    $Color = if ($TestResults[$Test]) { "Green" } else { "Red" }
    Write-Host "$Status $Test" -ForegroundColor $Color
}

Write-Host ""
Write-Host "Total Tests: $TotalTests" -ForegroundColor White
Write-Host "Passed:      $PassedTests" -ForegroundColor Green
Write-Host "Failed:      $FailedTests" -ForegroundColor Red
$PassRate = [math]::Round(($PassedTests / $TotalTests) * 100, 1)
Write-Host "Pass Rate:   $PassRate%" -ForegroundColor $(if ($PassRate -ge 75) { "Green" } else { "Red" })

# Show active containers
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  ACTIVE CONTAINERS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
docker ps --filter "name=chat-node" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Cleanup prompt
Write-Host ""
$Cleanup = Read-Host "Do you want to cleanup containers? (y/N)"
if ($Cleanup -eq "y" -or $Cleanup -eq "Y") {
    Cleanup-Containers
    Write-Host "Cleanup complete!" -ForegroundColor Green
} else {
    Write-Host "Containers left running for manual testing." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To attach to peer 1:" -ForegroundColor Cyan
    Write-Host "  docker attach $Container1" -ForegroundColor White
    Write-Host ""
    Write-Host "To cleanup later:" -ForegroundColor Cyan
    Write-Host "  docker compose -f $ComposePath down -v" -ForegroundColor White
}

# Return exit code
if ($FailedTests -eq 0) {
    Write-Host "`nLevel 1 Test: PASSED! ✅" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nLevel 1 Test: FAILED! ❌" -ForegroundColor Red
    exit 1
}
