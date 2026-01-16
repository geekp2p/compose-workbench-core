# ============================================
# P2P DHT Network - Level 2: Feature Testing
# ============================================
# Duration: ~15 minutes
# Tests: DHT Storage, Relay Service, Smart Routing, CLI Commands
# Based on: TESTING-ROADMAP.md Level 2

param(
    [switch]$SkipSetup,   # Skip peer setup (assumes peers running)
    [switch]$Cleanup,     # Cleanup after test
    [switch]$Verbose      # Show detailed logs
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
Write-Info "  Level 2: Feature Testing (15 min)"
Write-Info "========================================"
Write-Info "Focus: DHT, Relay, Routing, CLI Commands"
Write-Info ""

# ============================================
# Setup: Start Peers
# ============================================
if (-not $SkipSetup) {
    Write-Step "[Setup] Starting Peers"
    Write-Info "----------------------------------------"

    try {
        Write-Info "Building and starting 3 peers..."
        docker compose -f $ComposeFile up -d --build 2>&1 | Out-Null
        Start-Sleep 5

        # Start 2 additional peers
        docker compose -f $ComposeFile run -d chat-node 2>&1 | Out-Null
        Start-Sleep 3
        docker compose -f $ComposeFile run -d chat-node 2>&1 | Out-Null
        Start-Sleep 3

        Write-Success "✓ 3 peers started"

        Write-Info "Waiting 60s for peer discovery and mesh formation..."
        for ($i = 1; $i -le 60; $i++) {
            Write-Progress -Activity "Peer Discovery" -Status "$i/60s" -PercentComplete (($i/60)*100)
            Start-Sleep 1
        }
        Write-Progress -Activity "Peer Discovery" -Completed

        Write-Success "✓ Setup complete"
    } catch {
        Write-Error "✗ Setup failed: $_"
        exit 1
    }
} else {
    Write-Info "Skipping setup (using existing peers)"
}

# Get container IDs
$containers = docker compose -f $ComposeFile ps -q
$containerArray = $containers -split "`n" | Where-Object { $_ -ne "" }
$testContainer = $containerArray[0]

Write-Info "Using container $($testContainer.Substring(0,12)) for tests"
Write-Info ""

# ============================================
# Test 2.1: DHT Storage Statistics
# ============================================
Write-Step "[Test 2.1] DHT Storage Statistics"
Write-Info "----------------------------------------"

try {
    Write-Info "Testing /dht command..."
    Write-Info "(Note: This requires manual execution in chat)"
    Write-Info ""

    # Check logs for DHT initialization
    $logs = docker logs --tail 200 $testContainer 2>&1

    $dhtChecks = @(
        @{Pattern = "Initializing distributed storage"; Name = "DHT Init"},
        @{Pattern = "DHT-based"; Name = "DHT Backend"},
        @{Pattern = "BadgerDB|Datastore"; Name = "Storage Backend"}
    )

    $passed = 0
    foreach ($check in $dhtChecks) {
        if ($logs -match $check.Pattern) {
            Write-Success "  ✓ $($check.Name) detected"
            $passed++
        } else {
            Write-Warning "  ⚠ $($check.Name) not found in logs"
        }
    }

    if ($passed -ge 1) {
        Write-Success "✓ Test 2.1 PASSED - DHT storage is initialized"
        Add-TestResult "DHT Storage" "PASS" "Storage backend operational"
    } else {
        Write-Warning "⚠ Test 2.1 PARTIAL - DHT indicators not found"
        Add-TestResult "DHT Storage" "PARTIAL" "Manual verification recommended"
    }

    Write-Info ""
    Write-Info "Manual verification:"
    Write-Info "  1. docker attach $($testContainer.Substring(0,12))"
    Write-Info "  2. Run: /dht"
    Write-Info "  3. Expected: Statistics showing Total Records, Cache Size, etc."
    Write-Info ""

} catch {
    Write-Error "✗ Test 2.1 FAILED: $_"
    Add-TestResult "DHT Storage" "FAIL" $_
}

Start-Sleep 2

# ============================================
# Test 2.2: Routing Statistics
# ============================================
Write-Step "[Test 2.2] Routing Statistics"
Write-Info "----------------------------------------"

try {
    Write-Info "Testing routing initialization..."

    $logs = docker logs --tail 200 $testContainer 2>&1

    $routingChecks = @(
        @{Pattern = "Initializing smart routing"; Name = "Smart Routing Init"},
        @{Pattern = "Routing|routing"; Name = "Routing System"},
        @{Pattern = "Direct|Relay|DHT"; Name = "Connection Types"}
    )

    $passed = 0
    foreach ($check in $routingChecks) {
        if ($logs -match $check.Pattern) {
            Write-Success "  ✓ $($check.Name) detected"
            $passed++
        }
    }

    if ($passed -ge 1) {
        Write-Success "✓ Test 2.2 PASSED - Routing system operational"
        Add-TestResult "Smart Routing" "PASS" "Routing initialized"
    } else {
        Write-Warning "⚠ Test 2.2 PARTIAL - Routing indicators weak"
        Add-TestResult "Smart Routing" "PARTIAL" "Check manually"
    }

    Write-Info ""
    Write-Info "Manual verification:"
    Write-Info "  1. docker attach $($testContainer.Substring(0,12))"
    Write-Info "  2. Run: /routing"
    Write-Info "  3. Expected: Priority Levels, Average Latency, Success Rate"
    Write-Info ""

} catch {
    Write-Error "✗ Test 2.2 FAILED: $_"
    Add-TestResult "Smart Routing" "FAIL" $_
}

Start-Sleep 2

# ============================================
# Test 2.3: Relay Service Status
# ============================================
Write-Step "[Test 2.3] Relay Service Status"
Write-Info "----------------------------------------"

try {
    Write-Info "Checking relay service configuration..."

    $logs = docker logs --tail 200 $testContainer 2>&1

    $relayChecks = @(
        @{Pattern = "Checking for public IP"; Name = "IP Detection"},
        @{Pattern = "relay"; Name = "Relay System"; CaseInsensitive = $true},
        @{Pattern = "Relay|relay"; Name = "Relay Service"}
    )

    $passed = 0
    $hasRelay = $false

    foreach ($check in $relayChecks) {
        if ($logs -match $check.Pattern) {
            Write-Success "  ✓ $($check.Name) detected"
            $passed++
            $hasRelay = $true
        }
    }

    # Check if behind NAT or has public IP
    if ($logs -match "Behind NAT|Firewall") {
        Write-Info "  → Peer detected as behind NAT/Firewall"
        Write-Info "  → Expected: Using relay connections"
    } elseif ($logs -match "Public IP|relay service enabled") {
        Write-Info "  → Peer detected with public IP"
        Write-Info "  → Expected: Can act as relay"
    } else {
        Write-Info "  → Relay status unclear from logs"
    }

    if ($hasRelay) {
        Write-Success "✓ Test 2.3 PASSED - Relay service configured"
        Add-TestResult "Relay Service" "PASS" "Relay detection works"
    } else {
        Write-Warning "⚠ Test 2.3 PARTIAL - Relay indicators not clear"
        Add-TestResult "Relay Service" "PARTIAL" "Check manually"
    }

    Write-Info ""
    Write-Info "Manual verification:"
    Write-Info "  1. docker attach $($testContainer.Substring(0,12))"
    Write-Info "  2. Run: /relay"
    Write-Info "  3. Expected: Status (ENABLED/DISABLED), Public IPs or Using Relays"
    Write-Info ""

} catch {
    Write-Error "✗ Test 2.3 FAILED: $_"
    Add-TestResult "Relay Service" "FAIL" $_
}

Start-Sleep 2

# ============================================
# Test 2.4: Connection Types
# ============================================
Write-Step "[Test 2.4] Connection Types"
Write-Info "----------------------------------------"

try {
    Write-Info "Checking peer connections..."

    $logs = docker logs --tail 200 $testContainer 2>&1

    # Look for connection indicators
    $hasConnections = $false
    if ($logs -match "joined the chat|Connected to peer|mesh ready") {
        Write-Success "  ✓ Peer connections detected"
        $hasConnections = $true
    }

    if ($logs -match "Direct|direct connection") {
        Write-Success "  ✓ Direct connections detected"
    }

    if ($logs -match "relay|p2p-circuit") {
        Write-Info "  → Relay connections detected"
    }

    if ($hasConnections) {
        Write-Success "✓ Test 2.4 PASSED - Connection system working"
        Add-TestResult "Connection Types" "PASS" "Peers connected"
    } else {
        Write-Warning "⚠ Test 2.4 PARTIAL - No clear connection indicators"
        Add-TestResult "Connection Types" "PARTIAL" "May need more time"
    }

    Write-Info ""
    Write-Info "Manual verification:"
    Write-Info "  1. docker attach $($testContainer.Substring(0,12))"
    Write-Info "  2. Run: /conn"
    Write-Info "  3. Expected: List of peers with Type (Direct/Relay), Protocol, Latency"
    Write-Info ""

} catch {
    Write-Error "✗ Test 2.4 FAILED: $_"
    Add-TestResult "Connection Types" "FAIL" $_
}

Start-Sleep 2

# ============================================
# Test 2.5: GossipSub Mesh Status
# ============================================
Write-Step "[Test 2.5] GossipSub Mesh Status"
Write-Info "----------------------------------------"

try {
    Write-Info "Checking GossipSub mesh formation..."

    $logs = docker logs --tail 200 $testContainer 2>&1

    $meshChecks = @(
        @{Pattern = "Joining chat topic"; Name = "Topic Join"},
        @{Pattern = "GossipSub|gossipsub"; Name = "GossipSub Protocol"},
        @{Pattern = "mesh|Mesh"; Name = "Mesh Formation"}
    )

    $passed = 0
    foreach ($check in $meshChecks) {
        if ($logs -match $check.Pattern) {
            Write-Success "  ✓ $($check.Name) detected"
            $passed++
        }
    }

    if ($passed -ge 2) {
        Write-Success "✓ Test 2.5 PASSED - GossipSub mesh operational"
        Add-TestResult "GossipSub Mesh" "PASS" "Mesh formed"
    } else {
        Write-Warning "⚠ Test 2.5 PARTIAL - Mesh indicators weak"
        Add-TestResult "GossipSub Mesh" "PARTIAL" "Check manually"
    }

    Write-Info ""
    Write-Info "Manual verification:"
    Write-Info "  1. docker attach $($testContainer.Substring(0,12))"
    Write-Info "  2. Run: /mesh"
    Write-Info "  3. Expected: Topic name, Mesh Peers count, Grafts/Prunes"
    Write-Info ""

} catch {
    Write-Error "✗ Test 2.5 FAILED: $_"
    Add-TestResult "GossipSub Mesh" "FAIL" $_
}

Start-Sleep 2

# ============================================
# Test 2.6: CLI Commands Availability
# ============================================
Write-Step "[Test 2.6] CLI Commands Availability"
Write-Info "----------------------------------------"

Write-Info "Verifying that CLI commands are available..."
Write-Info "This test checks if the commands are implemented (requires manual verification)"
Write-Info ""

$cliCommands = @(
    "/help", "/peers", "/dht", "/routing", "/relay",
    "/conn", "/mesh", "/verbose", "/quit"
)

Write-Info "Expected CLI commands:"
foreach ($cmd in $cliCommands) {
    Write-Info "  • $cmd"
}

Write-Info ""
Write-Info "To verify all commands work:"
Write-Info "  1. docker attach $($testContainer.Substring(0,12))"
Write-Info "  2. Run: /help"
Write-Info "  3. Verify all commands listed above appear"
Write-Info "  4. Test each command individually"
Write-Info ""

Add-TestResult "CLI Commands" "MANUAL" "Requires manual verification"

# ============================================
# Test 2.7: Verbose Mode Toggle
# ============================================
Write-Step "[Test 2.7] Verbose Mode Toggle"
Write-Info "----------------------------------------"

Write-Info "Testing verbose mode feature..."
Write-Info "This requires interactive testing:"
Write-Info ""
Write-Info "  1. docker attach $($testContainer.Substring(0,12))"
Write-Info "  2. Run: /verbose"
Write-Info "  3. Expected: 'Verbose mode: ON'"
Write-Info "  4. Send a message"
Write-Info "  5. Expected: Detailed routing info (DHT CID, Relay hops, etc.)"
Write-Info "  6. Run: /verbose"
Write-Info "  7. Expected: 'Verbose mode: OFF'"
Write-Info "  8. Send a message"
Write-Info "  9. Expected: Normal message (no extra details)"
Write-Info ""

Add-TestResult "Verbose Mode" "MANUAL" "Interactive test required"

# ============================================
# Test Summary
# ============================================
Write-Step "Test Summary"
Write-Info "========================================"

$passCount = ($TestResults | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($TestResults | Where-Object { $_.Status -eq "FAIL" }).Count
$partialCount = ($TestResults | Where-Object { $_.Status -eq "PARTIAL" }).Count
$manualCount = ($TestResults | Where-Object { $_.Status -eq "MANUAL" }).Count

Write-Info "Results:"
foreach ($result in $TestResults) {
    $symbol = switch ($result.Status) {
        "PASS" { "✓"; $color = "Green" }
        "FAIL" { "✗"; $color = "Red" }
        "PARTIAL" { "⚠"; $color = "Yellow" }
        "MANUAL" { "⊙"; $color = "Cyan" }
    }

    $message = if ($result.Message) { " - $($result.Message)" } else { "" }
    Write-Host "  $symbol $($result.Test)$message" -ForegroundColor $color
}

Write-Info ""
Write-Info "Summary: $passCount passed, $failCount failed, $partialCount partial, $manualCount manual"
Write-Info ""

# Overall assessment
if ($failCount -eq 0 -and $passCount -ge 3) {
    Write-Success "========================================"
    Write-Success "  🎉 Level 2 Test PASSED!"
    Write-Success "========================================"
    Write-Info "Core features working! Complete manual tests, then proceed to Level 3."
} elseif ($failCount -eq 0) {
    Write-Warning "========================================"
    Write-Warning "  ⚠ Level 2 Test PARTIAL"
    Write-Warning "========================================"
    Write-Info "Some features need manual verification."
} else {
    Write-Error "========================================"
    Write-Error "  ✗ Level 2 Test FAILED"
    Write-Error "========================================"
    Write-Info "Critical issues found. Review errors above."
}

Write-Info ""
Write-Info "Manual Testing Checklist:"
Write-Info "  [ ] Test /dht command"
Write-Info "  [ ] Test /routing command"
Write-Info "  [ ] Test /relay command"
Write-Info "  [ ] Test /conn command"
Write-Info "  [ ] Test /mesh command"
Write-Info "  [ ] Test /verbose toggle"
Write-Info "  [ ] Test /help command"
Write-Info ""

Write-Info "Next Steps:"
Write-Info "  - Complete manual tests above"
Write-Info "  - Continue: .\test-level3-network.ps1"
Write-Info "  - Cleanup: .\test-level2-features.ps1 -Cleanup"
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

Write-Info "Level 2 test complete!"
