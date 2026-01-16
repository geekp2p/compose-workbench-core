# ============================================
# P2P DHT Network - Level 1: Quick Start Test
# ============================================
# Duration: ~5 minutes
# Tests: Single peer startup, peer discovery, message broadcasting, codename verification
# Based on: TESTING-ROADMAP.md Level 1

param(
    [switch]$SkipBuild,  # Skip docker build
    [switch]$Cleanup,    # Cleanup after test
    [switch]$Verbose     # Show detailed logs
)

$ErrorActionPreference = "Stop"

# Colors
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error { Write-Host $args -ForegroundColor Red }
function Write-Step { Write-Host "`n$args" -ForegroundColor Magenta }

# Configuration
$ProjectPath = "projects/p2p-chat-go"
$ComposeFile = "$ProjectPath/compose.yml"
$TestResults = @()

function Add-TestResult {
    param($TestName, $Status, $Message = "")
    $script:TestResults += @{
        Test = $TestName
        Status = $Status
        Message = $Message
    }
}

Write-Info "========================================"
Write-Info "  Level 1: Quick Start Test (5 min)"
Write-Info "========================================"
Write-Info "Focus: Basic connectivity and peer discovery"
Write-Info ""

# ============================================
# Step 1.1: Build Project
# ============================================
Write-Step "[Step 1.1] Build Project"
Write-Info "----------------------------------------"

if (-not $SkipBuild) {
    try {
        Write-Info "Building Docker image..."
        if ($Verbose) {
            docker compose -f $ComposeFile build
        } else {
            docker compose -f $ComposeFile build --quiet 2>&1 | Out-Null
        }
        Write-Success "✓ Build successful"
        Add-TestResult "Build Project" "PASS"
    } catch {
        Write-Error "✗ Build failed: $_"
        Add-TestResult "Build Project" "FAIL" $_
        exit 1
    }
} else {
    Write-Info "Skipping build (using existing image)"
    Add-TestResult "Build Project" "SKIP"
}

# ============================================
# Step 1.2: Start First Peer
# ============================================
Write-Step "[Step 1.2] Start First Peer"
Write-Info "----------------------------------------"

try {
    Write-Info "Starting first peer (detached mode)..."
    docker compose -f $ComposeFile up -d 2>&1 | Out-Null
    Start-Sleep 5

    # Check container status
    $containerStatus = docker compose -f $ComposeFile ps --format json | ConvertFrom-Json
    if ($containerStatus.State -eq "running") {
        Write-Success "✓ Peer 1 container running"
    } else {
        throw "Container state: $($containerStatus.State)"
    }

    # Check logs for startup indicators
    Write-Info "Checking startup logs..."
    $logs = docker compose -f $ComposeFile logs

    $startupChecks = @(
        @{Pattern = "P2P Chat v"; Name = "Version Info"; Critical = $true},
        @{Pattern = "Initializing P2P node"; Name = "P2P Node Init"; Critical = $true},
        @{Pattern = "Peer ID: 12D3KooW"; Name = "Peer ID Generation"; Critical = $true},
        @{Pattern = "Codename:"; Name = "Codename Generation"; Critical = $true},
        @{Pattern = "Listening on:"; Name = "Network Listening"; Critical = $true},
        @{Pattern = "P2P Chat Started"; Name = "Chat Started"; Critical = $true}
    )

    $passed = 0
    $failed = 0

    foreach ($check in $startupChecks) {
        if ($logs -match $check.Pattern) {
            Write-Success "  ✓ $($check.Name)"
            $passed++
        } else {
            if ($check.Critical) {
                Write-Error "  ✗ $($check.Name) - MISSING (Critical)"
                $failed++
            } else {
                Write-Warning "  ⚠ $($check.Name) - not found"
            }
        }
    }

    # Extract codename from logs
    $codename = "Unknown"
    if ($logs -match "Codename:\s+(.+)") {
        $codename = $matches[1].Trim()
        Write-Info "  Codename detected: $codename"
    }

    Write-Info ""
    Write-Info "Startup checks: $passed passed, $failed failed"

    if ($failed -eq 0) {
        Write-Success "✓ Step 1.2 PASSED - First peer started successfully"
        Add-TestResult "Single Peer Startup" "PASS" "Codename: $codename"
    } else {
        throw "Critical startup checks failed"
    }

} catch {
    Write-Error "✗ Step 1.2 FAILED: $_"
    Add-TestResult "Single Peer Startup" "FAIL" $_
    Write-Info "`nShowing container logs:"
    docker compose -f $ComposeFile logs --tail 50
    exit 1
}

Start-Sleep 2

# ============================================
# Step 1.3: Start Second Peer
# ============================================
Write-Step "[Step 1.3] Start Second Peer"
Write-Info "----------------------------------------"

try {
    Write-Info "Starting second peer..."
    $peer2Id = docker compose -f $ComposeFile run -d chat-node
    Start-Sleep 5

    Write-Info "Checking peer 2 startup..."
    $peer2Logs = docker logs $peer2Id 2>&1

    if ($peer2Logs -match "P2P Chat Started") {
        Write-Success "✓ Peer 2 started successfully"

        # Extract codename from peer 2
        $codename2 = "Unknown"
        if ($peer2Logs -match "Codename:\s+(.+)") {
            $codename2 = $matches[1].Trim()
            Write-Info "  Peer 2 Codename: $codename2"
        }

        Add-TestResult "Second Peer Startup" "PASS" "Codename: $codename2"
    } else {
        throw "Peer 2 did not start properly"
    }

} catch {
    Write-Error "✗ Step 1.3 FAILED: $_"
    Add-TestResult "Second Peer Startup" "FAIL" $_
    exit 1
}

Start-Sleep 2

# ============================================
# Step 1.4: Wait for Peer Discovery
# ============================================
Write-Step "[Step 1.4] Waiting for Peer Discovery"
Write-Info "----------------------------------------"

$discoveryWaitTime = 60
Write-Info "Waiting ${discoveryWaitTime}s for automatic peer discovery..."

# Progress bar
for ($i = 1; $i -le $discoveryWaitTime; $i++) {
    $percent = [math]::Round(($i / $discoveryWaitTime) * 100)
    Write-Progress -Activity "Peer Discovery" -Status "$i/${discoveryWaitTime}s ($percent%)" -PercentComplete $percent
    Start-Sleep 1
}
Write-Progress -Activity "Peer Discovery" -Completed

Write-Success "✓ Discovery wait period complete"

# ============================================
# Step 1.5: Verify Peer Connections
# ============================================
Write-Step "[Step 1.5] Verify Peer Connections"
Write-Info "----------------------------------------"

try {
    Write-Info "Checking peer connections..."

    # Get all container IDs
    $containers = docker compose -f $ComposeFile ps -q
    $containerArray = $containers -split "`n" | Where-Object { $_ -ne "" }

    Write-Info "Found $($containerArray.Count) running containers"

    $discoveredPeers = 0
    $totalContainers = $containerArray.Count

    foreach ($containerId in $containerArray) {
        $shortId = $containerId.Substring(0, [Math]::Min(12, $containerId.Length))
        $logs = docker logs --tail 100 $containerId 2>&1

        # Check for various peer discovery indicators
        $peerCount = 0

        if ($logs -match "joined the chat") {
            $joinMessages = ($logs | Select-String -Pattern "joined the chat" -AllMatches).Matches.Count
            $peerCount = $joinMessages
        } elseif ($logs -match "Connected peers:\s+(\d+)") {
            $peerCount = [int]$matches[1]
        } elseif ($logs -match "mesh ready with (\d+) peer") {
            $peerCount = [int]$matches[1]
        }

        if ($peerCount -gt 0) {
            Write-Success "  ✓ Container $shortId: $peerCount peer(s) discovered"
            $discoveredPeers++
        } else {
            Write-Warning "  ⚠ Container $shortId: No peers discovered yet"
        }
    }

    $discoveryRate = if ($totalContainers -gt 0) {
        [math]::Round(($discoveredPeers / $totalContainers) * 100)
    } else {
        0
    }

    Write-Info ""
    Write-Info "Discovery Summary: $discoveredPeers/$totalContainers containers found peers ($discoveryRate%)"

    if ($discoveryRate -ge 80) {
        Write-Success "✓ Step 1.5 PASSED - Peer discovery successful ($discoveryRate%)"
        Add-TestResult "Peer Discovery" "PASS" "$discoveredPeers/$totalContainers peers connected"
    } elseif ($discoveryRate -ge 50) {
        Write-Warning "⚠ Step 1.5 PARTIAL - Some peers discovered ($discoveryRate%)"
        Add-TestResult "Peer Discovery" "PARTIAL" "$discoveredPeers/$totalContainers peers connected"
    } else {
        Write-Warning "⚠ Step 1.5 FAILED - Low discovery rate ($discoveryRate%)"
        Add-TestResult "Peer Discovery" "FAIL" "Only $discoveredPeers/$totalContainers peers connected"
        Write-Info "  Note: DHT discovery can take 1-3 minutes. Consider waiting longer."
    }

} catch {
    Write-Error "✗ Step 1.5 FAILED: $_"
    Add-TestResult "Peer Discovery" "FAIL" $_
}

Start-Sleep 2

# ============================================
# Step 1.6: Verify Codenames
# ============================================
Write-Step "[Step 1.6] Verify Codename Feature"
Write-Info "----------------------------------------"

try {
    Write-Info "Extracting and verifying codenames..."

    $codenames = @()
    $containers = docker compose -f $ComposeFile ps -q
    $containerArray = $containers -split "`n" | Where-Object { $_ -ne "" }

    foreach ($containerId in $containerArray) {
        $logs = docker logs $containerId 2>&1
        if ($logs -match "Codename:\s+(.+)") {
            $name = $matches[1].Trim()
            $codenames += $name
            Write-Success "  ✓ Found codename: $name"
        }
    }

    if ($codenames.Count -eq $containerArray.Count) {
        Write-Success "✓ All peers have codenames ($($codenames.Count)/$($containerArray.Count))"

        # Check for uniqueness
        $uniqueNames = $codenames | Select-Object -Unique
        if ($uniqueNames.Count -eq $codenames.Count) {
            Write-Success "✓ All codenames are unique"
            Add-TestResult "Codename Generation" "PASS" "All unique: $($codenames -join ', ')"
        } else {
            Write-Warning "⚠ Some codenames are duplicated"
            Add-TestResult "Codename Generation" "PARTIAL" "Duplicates found"
        }
    } else {
        Write-Warning "⚠ Not all peers have codenames ($($codenames.Count)/$($containerArray.Count))"
        Add-TestResult "Codename Generation" "PARTIAL" "$($codenames.Count)/$($containerArray.Count) codenames"
    }

} catch {
    Write-Error "✗ Step 1.6 FAILED: $_"
    Add-TestResult "Codename Generation" "FAIL" $_
}

Start-Sleep 2

# ============================================
# Manual Test Instructions
# ============================================
Write-Step "[Manual Test] Message Broadcasting"
Write-Info "----------------------------------------"

Write-Info "To manually verify message broadcasting:"
Write-Info ""
Write-Info "  1. Get container IDs:"
$containers = docker compose -f $ComposeFile ps -q
$containerArray = $containers -split "`n" | Where-Object { $_ -ne "" }
$containerArray | ForEach-Object {
    $shortId = $_.Substring(0, [Math]::Min(12, $_.Length))
    Write-Info "     Container: $shortId"
}

Write-Info ""
Write-Info "  2. Attach to first container:"
Write-Info "     docker attach $($containerArray[0].Substring(0, [Math]::Min(12, $containerArray[0].Length)))"
Write-Info ""
Write-Info "  3. Send a test message:"
Write-Info "     > Hello from Peer 1!"
Write-Info ""
Write-Info "  4. Detach with: Ctrl+P, Ctrl+Q"
Write-Info ""
Write-Info "  5. Check logs of other containers:"
Write-Info "     docker logs $($containerArray[1].Substring(0, [Math]::Min(12, $containerArray[1].Length)))"
Write-Info ""
Write-Info "  Expected: Message should appear in all peer logs"
Write-Info ""

Add-TestResult "Message Broadcasting" "MANUAL" "Requires manual verification"

# ============================================
# Test Summary
# ============================================
Write-Step "Test Summary"
Write-Info "========================================"

$passCount = ($TestResults | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($TestResults | Where-Object { $_.Status -eq "FAIL" }).Count
$partialCount = ($TestResults | Where-Object { $_.Status -eq "PARTIAL" }).Count
$manualCount = ($TestResults | Where-Object { $_.Status -eq "MANUAL" }).Count
$skipCount = ($TestResults | Where-Object { $_.Status -eq "SKIP" }).Count

Write-Info "Results:"
foreach ($result in $TestResults) {
    $symbol = switch ($result.Status) {
        "PASS" { "✓"; $color = "Green" }
        "FAIL" { "✗"; $color = "Red" }
        "PARTIAL" { "⚠"; $color = "Yellow" }
        "MANUAL" { "⊙"; $color = "Cyan" }
        "SKIP" { "○"; $color = "Gray" }
    }

    $message = if ($result.Message) { " - $($result.Message)" } else { "" }
    Write-Host "  $symbol $($result.Test)$message" -ForegroundColor $color
}

Write-Info ""
Write-Info "Summary: $passCount passed, $failCount failed, $partialCount partial, $manualCount manual, $skipCount skipped"
Write-Info ""

# Overall result
$criticalFailed = ($TestResults | Where-Object { $_.Status -eq "FAIL" }).Count
if ($criticalFailed -eq 0 -and $passCount -ge 3) {
    Write-Success "========================================"
    Write-Success "  🎉 Level 1 Test PASSED!"
    Write-Success "========================================"
    Write-Info "Basic connectivity works! Ready for Level 2."
} elseif ($criticalFailed -eq 0) {
    Write-Warning "========================================"
    Write-Warning "  ⚠ Level 1 Test PARTIAL"
    Write-Warning "========================================"
    Write-Info "Some tests need attention. Review results above."
} else {
    Write-Error "========================================"
    Write-Error "  ✗ Level 1 Test FAILED"
    Write-Error "========================================"
    Write-Info "Critical issues found. Review errors above."
}

Write-Info ""
Write-Info "Next Steps:"
Write-Info "  - Manual test: Verify message broadcasting (see instructions above)"
Write-Info "  - Continue: .\test-level2-features.ps1"
Write-Info "  - Cleanup: .\test-level1-quickstart.ps1 -Cleanup"
Write-Info ""

# ============================================
# Cleanup
# ============================================
if ($Cleanup) {
    Write-Info "========================================"
    Write-Info "  Cleaning Up"
    Write-Info "========================================"
    Write-Info "Stopping and removing containers..."
    docker compose -f $ComposeFile down -v 2>&1 | Out-Null
    Write-Success "✓ Cleanup complete"
    Write-Info ""
}

Write-Info "Level 1 test complete!"
Write-Info "Test results saved in: \$TestResults variable"
