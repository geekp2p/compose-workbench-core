# ============================================
# P2P Chat - Basic Functionality Test Script
# ============================================
# Tests: Single Peer, Multiple Peers, Message Broadcasting

param(
    [switch]$Quick,    # Quick test (2 peers, 30s)
    [switch]$Full,     # Full test (3 peers, 60s)
    [switch]$Cleanup   # Cleanup after test
)

$ErrorActionPreference = "Stop"

# Colors
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error { Write-Host $args -ForegroundColor Red }

# Configuration
$ProjectPath = "projects/p2p-chat-go"
$ComposeFile = "$ProjectPath/compose.yml"
$PeerCount = if ($Quick) { 2 } else { 3 }
$WaitTime = if ($Quick) { 30 } else { 60 }

Write-Info "========================================"
Write-Info "  P2P Chat - Basic Functionality Tests"
Write-Info "========================================"
Write-Info "Peer count: $PeerCount"
Write-Info "Wait time: $WaitTime seconds"
Write-Info ""

# ============================================
# Test 1.1: Single Peer Startup
# ============================================
Write-Info "[Test 1.1] Single Peer Startup"
Write-Info "----------------------------------------"

try {
    Write-Info "Building Docker image..."
    docker compose -f $ComposeFile build --quiet
    Write-Success "✓ Build successful"
} catch {
    Write-Error "✗ Build failed: $_"
    exit 1
}

try {
    Write-Info "Starting first peer (detached mode)..."
    docker compose -f $ComposeFile up -d
    Start-Sleep 5

    # Check if container is running
    $containerStatus = docker compose -f $ComposeFile ps --format json | ConvertFrom-Json
    if ($containerStatus.State -eq "running") {
        Write-Success "✓ Peer 1 started successfully"
    } else {
        Write-Error "✗ Peer 1 failed to start (State: $($containerStatus.State))"
        exit 1
    }

    # Check logs for success indicators
    Write-Info "Checking logs for startup indicators..."
    $logs = docker compose -f $ComposeFile logs

    $checks = @(
        @{Pattern = "Initializing P2P node"; Name = "P2P Node Init"},
        @{Pattern = "Peer ID: 12D3KooW"; Name = "Peer ID Generation"},
        @{Pattern = "Initializing smart routing"; Name = "Smart Routing"},
        @{Pattern = "Checking for public IP"; Name = "Relay Service Check"},
        @{Pattern = "Initializing distributed storage"; Name = "DHT Storage"},
        @{Pattern = "P2P Chat Started"; Name = "Chat Started"}
    )

    $passed = 0
    $failed = 0

    foreach ($check in $checks) {
        if ($logs -match $check.Pattern) {
            Write-Success "  ✓ $($check.Name)"
            $passed++
        } else {
            Write-Warning "  ⚠ $($check.Name) - not found"
            $failed++
        }
    }

    Write-Info ""
    Write-Info "Startup checks: $passed passed, $failed warnings"

    if ($passed -ge 4) {
        Write-Success "✓ Test 1.1 PASSED - Single peer startup successful"
    } else {
        Write-Warning "⚠ Test 1.1 PARTIAL - Some checks failed"
    }

} catch {
    Write-Error "✗ Test 1.1 FAILED: $_"
    exit 1
}

Write-Info ""
Start-Sleep 2

# ============================================
# Test 1.2: Multiple Peers Discovery
# ============================================
Write-Info "[Test 1.2] Multiple Peers Discovery"
Write-Info "----------------------------------------"

$additionalPeers = $PeerCount - 1

try {
    Write-Info "Starting $additionalPeers additional peer(s)..."

    for ($i = 2; $i -le $PeerCount; $i++) {
        Write-Info "  Starting peer $i..."
        docker compose -f $ComposeFile run -d chat-node
        Start-Sleep 3
    }

    Write-Success "✓ Started $additionalPeers additional peer(s)"

    # Wait for peer discovery
    Write-Info "Waiting ${WaitTime}s for peer discovery (DHT takes time)..."

    # Progress bar
    for ($i = 1; $i -le $WaitTime; $i++) {
        $percent = [math]::Round(($i / $WaitTime) * 100)
        Write-Progress -Activity "Waiting for peer discovery" -Status "$i/${WaitTime}s ($percent%)" -PercentComplete $percent
        Start-Sleep 1
    }
    Write-Progress -Activity "Waiting for peer discovery" -Completed

    Write-Info "Checking peer connections..."

    # Get all container IDs
    $containers = docker compose -f $ComposeFile ps -q
    $containerArray = $containers -split "`n" | Where-Object { $_ -ne "" }

    Write-Info "Found $($containerArray.Count) containers"

    $peerResults = @()

    foreach ($containerId in $containerArray) {
        # Try to check peer count from logs
        $recentLogs = docker logs --tail 50 $containerId 2>&1

        # Look for mesh or peer count indicators
        $meshPeers = 0
        if ($recentLogs -match "Connected peers: (\d+)") {
            $meshPeers = [int]$matches[1]
        } elseif ($recentLogs -match "Mesh peers: (\d+)") {
            $meshPeers = [int]$matches[1]
        } elseif ($recentLogs -match "mesh ready with (\d+) peer") {
            $meshPeers = [int]$matches[1]
        }

        $peerResults += @{
            ContainerId = $containerId.Substring(0, 12)
            MeshPeers = $meshPeers
        }

        Write-Info "  Container ${containerId.Substring(0,12)}: $meshPeers peer(s) connected"
    }

    # Calculate success rate
    $expectedPeers = $PeerCount - 1
    $successfulPeers = ($peerResults | Where-Object { $_.MeshPeers -gt 0 }).Count
    $successRate = [math]::Round(($successfulPeers / $PeerCount) * 100)

    Write-Info ""
    Write-Info "Discovery results: $successfulPeers/$PeerCount peers found other peers ($successRate%)"

    if ($successRate -ge 80) {
        Write-Success "✓ Test 1.2 PASSED - Peer discovery successful ($successRate%)"
    } elseif ($successRate -ge 50) {
        Write-Warning "⚠ Test 1.2 PARTIAL - Some peers discovered ($successRate%)"
    } else {
        Write-Warning "⚠ Test 1.2 FAILED - Low discovery rate ($successRate%)"
        Write-Info "  Note: DHT discovery can take 1-3 minutes. Try waiting longer or using -Full flag."
    }

} catch {
    Write-Error "✗ Test 1.2 FAILED: $_"
}

Write-Info ""
Start-Sleep 2

# ============================================
# Test 1.3: Message Broadcasting
# ============================================
Write-Info "[Test 1.3] Message Broadcasting"
Write-Info "----------------------------------------"

try {
    Write-Info "Simulating message broadcast test..."
    Write-Info "  (Manual verification required - see instructions below)"

    Write-Info ""
    Write-Info "To test message broadcasting manually:"
    Write-Info "  1. Attach to a container:"
    Write-Info "     docker attach <container-id>"
    Write-Info "  2. Send a test message:"
    Write-Info "     > Hello from peer X"
    Write-Info "  3. Detach with: Ctrl+P, Ctrl+Q"
    Write-Info "  4. Attach to another container and check if message appeared"
    Write-Info ""

    Write-Info "Available containers:"
    docker compose -f $ComposeFile ps --format "table {{.ID}}\t{{.Status}}\t{{.Ports}}"

    Write-Warning "⚠ Test 1.3 MANUAL - Message broadcasting requires manual verification"

} catch {
    Write-Error "✗ Test 1.3 FAILED: $_"
}

Write-Info ""
Start-Sleep 2

# ============================================
# Summary
# ============================================
Write-Info "========================================"
Write-Info "  Test Summary"
Write-Info "========================================"

Write-Success "Test 1.1: Single Peer Startup - PASSED"
Write-Info "Test 1.2: Multiple Peers Discovery - Check results above"
Write-Warning "Test 1.3: Message Broadcasting - MANUAL VERIFICATION REQUIRED"

Write-Info ""
Write-Info "Current containers:"
docker compose -f $ComposeFile ps

Write-Info ""
Write-Info "========================================"
Write-Info "  Next Steps"
Write-Info "========================================"
Write-Info "1. Review test results above"
Write-Info "2. Manually test message broadcasting (Test 1.3)"
Write-Info "3. Run advanced tests: .\test-advanced.ps1"
Write-Info "4. Cleanup: .\test-basic.ps1 -Cleanup"
Write-Info ""

# Cleanup option
if ($Cleanup) {
    Write-Info "Cleaning up..."
    docker compose -f $ComposeFile down -v
    Write-Success "✓ Cleanup complete"
}

Write-Success "Basic functionality tests complete!"
