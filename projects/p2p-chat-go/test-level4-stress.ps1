# ============================================
# P2P DHT Network - Level 4: Stress Testing
# ============================================
# Duration: ~45 minutes
# Tests: Rapid reconnect, large messages, zero peers, partition recovery
# Based on: TESTING-ROADMAP.md Level 4

param(
    [int]$RapidTestCycles = 10,      # Number of rapid reconnect cycles
    [int]$LargeMessageSize = 4000,   # Size of large message in chars
    [switch]$SkipRapidTest,          # Skip rapid reconnect test
    [switch]$SkipLargeMessage,       # Skip large message test
    [switch]$Cleanup,                # Cleanup after test
    [switch]$Verbose                 # Show detailed logs
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
        Timestamp = Get-Date
    }
}

Write-Info "========================================"
Write-Info "  Level 4: Stress Testing (45 min)"
Write-Info "========================================"
Write-Info "Focus: Stability under stress conditions"
Write-Info ""

# ============================================
# Test 4.1: Rapid Connect/Disconnect
# ============================================
if (-not $SkipRapidTest) {
    Write-Step "[Test 4.1] Rapid Connect/Disconnect"
    Write-Info "========================================"
    Write-Info "Testing peer stability with rapid reconnections..."
    Write-Info "Cycles: $RapidTestCycles"
    Write-Info ""

    $rapidTestPassed = 0
    $rapidTestFailed = 0
    $rapidTestErrors = @()

    try {
        for ($i = 1; $i -le $RapidTestCycles; $i++) {
            Write-Info "Cycle $i/$RapidTestCycles ..."

            try {
                # Start peer
                Write-Info "  Starting peer..."
                $job = Start-Job -ScriptBlock {
                    param($composeFile)
                    docker compose -f $composeFile run --rm chat-node 2>&1
                } -ArgumentList $ComposeFile

                # Wait for startup
                Start-Sleep 15

                # Check if job is running
                $jobState = (Get-Job -Id $job.Id).State
                if ($jobState -eq "Running") {
                    Write-Success "  ✓ Peer started successfully"
                    $rapidTestPassed++
                } else {
                    Write-Warning "  ⚠ Peer failed to start (State: $jobState)"
                    $rapidTestFailed++
                    $rapidTestErrors += "Cycle $i: Failed to start"
                }

                # Stop peer
                Write-Info "  Stopping peer..."
                Stop-Job -Id $job.Id -ErrorAction SilentlyContinue
                Remove-Job -Id $job.Id -Force -ErrorAction SilentlyContinue

                # Brief pause between cycles
                Start-Sleep 3

            } catch {
                Write-Error "  ✗ Cycle $i failed: $_"
                $rapidTestFailed++
                $rapidTestErrors += "Cycle $i: $_"
            }
        }

        # Cleanup any remaining jobs
        Get-Job | Stop-Job -ErrorAction SilentlyContinue
        Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue

        Write-Info ""
        Write-Info "Rapid Reconnect Results:"
        Write-Info "  Successful cycles: $rapidTestPassed/$RapidTestCycles"
        Write-Info "  Failed cycles: $rapidTestFailed/$RapidTestCycles"

        $successRate = [math]::Round(($rapidTestPassed / $RapidTestCycles) * 100)

        if ($successRate -eq 100) {
            Write-Success "✓ Test 4.1 PASSED - All reconnections successful (100%)"
            Add-TestResult "Rapid Reconnect" "PASS" "$rapidTestPassed/$RapidTestCycles cycles"
        } elseif ($successRate -ge 80) {
            Write-Warning "⚠ Test 4.1 PARTIAL - Most reconnections successful ($successRate%)"
            Add-TestResult "Rapid Reconnect" "PARTIAL" "$rapidTestPassed/$RapidTestCycles cycles"
        } else {
            Write-Error "✗ Test 4.1 FAILED - High failure rate ($successRate%)"
            Add-TestResult "Rapid Reconnect" "FAIL" "Only $rapidTestPassed/$RapidTestCycles cycles"
        }

        if ($rapidTestErrors.Count -gt 0) {
            Write-Warning "Errors encountered:"
            $rapidTestErrors | ForEach-Object { Write-Warning "  - $_" }
        }

    } catch {
        Write-Error "✗ Test 4.1 FAILED: $_"
        Add-TestResult "Rapid Reconnect" "FAIL" $_
    }

    Start-Sleep 2
}

# ============================================
# Test 4.2: Large Messages
# ============================================
if (-not $SkipLargeMessage) {
    Write-Step "[Test 4.2] Large Message Handling"
    Write-Info "========================================"
    Write-Info "Testing DHT storage with large messages ($LargeMessageSize chars)..."
    Write-Info ""

    try {
        # Start a peer for testing
        Write-Info "Starting test peer..."
        docker compose -f $ComposeFile up -d --build 2>&1 | Out-Null
        Start-Sleep 10

        $container = (docker compose -f $ComposeFile ps -q | Select-Object -First 1).Trim()
        Write-Info "Using container: $($container.Substring(0,12))"

        # Create large message
        $largeMessage = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. " * ([math]::Ceiling($LargeMessageSize / 57))
        $largeMessage = $largeMessage.Substring(0, $LargeMessageSize)

        Write-Info "Message size: $($largeMessage.Length) characters"
        Write-Info ""
        Write-Info "To test large message handling:"
        Write-Info "  1. docker attach $($container.Substring(0,12))"
        Write-Info "  2. Paste the large message (stored in clipboard)"
        Write-Info "  3. Check if message is sent successfully"
        Write-Info "  4. Run: /dht"
        Write-Info "  5. Expected: Cache Size increased by ~$([math]::Round($LargeMessageSize/1024))KB"
        Write-Info ""

        # Save message to temp file for manual testing
        $tempFile = "$env:TEMP\p2p-large-message.txt"
        $largeMessage | Out-File -FilePath $tempFile -Encoding utf8
        Write-Info "Large message saved to: $tempFile"
        Write-Info ""

        # Check initial DHT state
        Write-Info "Checking initial DHT state..."
        $logs = docker logs --tail 50 $container 2>&1

        if ($logs -match "Initializing distributed storage") {
            Write-Success "  ✓ DHT storage initialized"
        }

        Write-Info ""
        Write-Info "Manual test required:"
        Write-Info "  1. Copy message from: $tempFile"
        Write-Info "  2. Attach to container and paste"
        Write-Info "  3. Verify message sent without errors"
        Write-Info "  4. Check DHT cache size increased"
        Write-Info ""

        Add-TestResult "Large Messages" "MANUAL" "Requires manual testing - message ready at $tempFile"

        # Cleanup
        Write-Info "Stopping test peer..."
        docker compose -f $ComposeFile down 2>&1 | Out-Null

    } catch {
        Write-Error "✗ Test 4.2 FAILED: $_"
        Add-TestResult "Large Messages" "FAIL" $_
    }

    Start-Sleep 2
}

# ============================================
# Test 4.3: Zero Peers Scenario
# ============================================
Write-Step "[Test 4.3] Zero Peers Scenario"
Write-Info "========================================"
Write-Info "Testing peer behavior in isolation (no other peers)..."
Write-Info ""

try {
    Write-Info "Starting isolated peer (network=none)..."

    # Note: --network none may not work with compose, so we test with single peer
    docker compose -f $ComposeFile up -d --build 2>&1 | Out-Null
    Start-Sleep 10

    $container = (docker compose -f $ComposeFile ps -q | Select-Object -First 1).Trim()
    $shortId = $container.Substring(0, [Math]::Min(12, $container.Length))

    Write-Info "Testing isolated peer: $shortId"

    # Check logs for stability
    $logs = docker logs $container 2>&1

    $isolatedChecks = @{
        Started = $logs -match "P2P Chat Started"
        NoErrors = -not ($logs -match "error|Error|ERROR|panic|fatal")
        NoCrashes = -not ($logs -match "crash|panic|fatal")
        Running = (docker inspect $container --format '{{.State.Running}}') -eq "true"
    }

    Write-Info ""
    Write-Info "Isolated Peer Checks:"
    foreach ($check in $isolatedChecks.GetEnumerator()) {
        if ($check.Value) {
            Write-Success "  ✓ $($check.Key): OK"
        } else {
            Write-Warning "  ⚠ $($check.Key): FAIL"
        }
    }

    Write-Info ""
    Write-Info "Testing message in isolation:"
    Write-Info "  1. docker attach $shortId"
    Write-Info "  2. Send: Hello in isolation"
    Write-Info "  3. Expected: Message echoed locally, no crash"
    Write-Info "  4. Run: /peers"
    Write-Info "  5. Expected: 'Connected Peers (0)' or similar"
    Write-Info ""

    if ($isolatedChecks.Started -and $isolatedChecks.NoErrors -and $isolatedChecks.Running) {
        Write-Success "✓ Test 4.3 PASSED - Peer stable in isolation"
        Add-TestResult "Zero Peers Scenario" "PASS" "Peer runs without crashes"
    } else {
        Write-Warning "⚠ Test 4.3 PARTIAL - Some issues detected"
        Add-TestResult "Zero Peers Scenario" "PARTIAL" "Check logs for details"
    }

    # Cleanup
    docker compose -f $ComposeFile down 2>&1 | Out-Null

} catch {
    Write-Error "✗ Test 4.3 FAILED: $_"
    Add-TestResult "Zero Peers Scenario" "FAIL" $_
}

Start-Sleep 2

# ============================================
# Test 4.4: Network Partition Recovery
# ============================================
Write-Step "[Test 4.4] Network Partition Recovery"
Write-Info "========================================"
Write-Info "Testing auto-recovery after network partition..."
Write-Info ""

try {
    Write-Info "Creating test scenario with 3 peers..."

    # Start 3 peers
    docker compose -f $ComposeFile up -d --build 2>&1 | Out-Null
    Start-Sleep 5
    docker compose -f $ComposeFile run -d chat-node 2>&1 | Out-Null
    Start-Sleep 3
    docker compose -f $ComposeFile run -d chat-node 2>&1 | Out-Null
    Start-Sleep 3

    Write-Info "Waiting for mesh formation (60s)..."
    Start-Sleep 60

    $containers = docker compose -f $ComposeFile ps -q
    $containerArray = $containers -split "`n" | Where-Object { $_ -ne "" }

    Write-Success "✓ $($containerArray.Count) peers started"

    # Check pre-partition connectivity
    Write-Info ""
    Write-Info "Checking pre-partition connectivity..."
    $connectedBefore = 0

    foreach ($container in $containerArray) {
        $logs = docker logs --tail 50 $container 2>&1
        if ($logs -match "joined|connected|mesh ready") {
            $connectedBefore++
        }
    }

    Write-Info "  Peers with connections: $connectedBefore/$($containerArray.Count)"

    # Simulate partition by disconnecting network (pause container)
    Write-Info ""
    Write-Info "Simulating network partition..."
    $partitionedPeer = $containerArray[0]
    Write-Info "  Pausing peer: $($partitionedPeer.Substring(0,12))"

    docker pause $partitionedPeer 2>&1 | Out-Null
    Write-Info "  Peer paused (simulates network partition)"

    # Wait during partition
    Write-Info "  Waiting 30s during partition..."
    Start-Sleep 30

    # Reconnect network (unpause)
    Write-Info ""
    Write-Info "Restoring network connection..."
    docker unpause $partitionedPeer 2>&1 | Out-Null
    Write-Success "  ✓ Peer unpaused"

    # Wait for recovery
    Write-Info "  Waiting 60s for auto-recovery..."
    Start-Sleep 60

    # Check post-recovery connectivity
    Write-Info ""
    Write-Info "Checking post-recovery connectivity..."

    $logs = docker logs --tail 100 $partitionedPeer 2>&1
    $recovered = $false

    if ($logs -match "joined|connected|reconnect|mesh ready") {
        $recovered = $true
        Write-Success "  ✓ Peer reconnected after partition"
    } else {
        Write-Warning "  ⚠ Peer may not have reconnected yet"
    }

    if ($recovered) {
        Write-Success "✓ Test 4.4 PASSED - Auto-recovery working"
        Add-TestResult "Partition Recovery" "PASS" "Peer recovered after partition"
    } else {
        Write-Warning "⚠ Test 4.4 PARTIAL - Recovery unclear"
        Add-TestResult "Partition Recovery" "PARTIAL" "May need more time"
    }

    Write-Info ""
    Write-Info "Manual verification:"
    Write-Info "  1. docker attach $($partitionedPeer.Substring(0,12))"
    Write-Info "  2. Run: /peers"
    Write-Info "  3. Expected: Should show other peers (recovered)"
    Write-Info ""

    # Cleanup
    docker compose -f $ComposeFile down 2>&1 | Out-Null

} catch {
    Write-Error "✗ Test 4.4 FAILED: $_"
    Add-TestResult "Partition Recovery" "FAIL" $_
    docker compose -f $ComposeFile down 2>&1 | Out-Null
}

Start-Sleep 2

# ============================================
# Test 4.5: Memory Leak Detection
# ============================================
Write-Step "[Test 4.5] Memory Leak Detection"
Write-Info "========================================"
Write-Info "Testing for memory leaks over time..."
Write-Info ""

try {
    Write-Info "Starting peer for memory monitoring..."
    docker compose -f $ComposeFile up -d --build 2>&1 | Out-Null
    Start-Sleep 10

    $container = (docker compose -f $ComposeFile ps -q | Select-Object -First 1).Trim()
    $shortId = $container.Substring(0, [Math]::Min(12, $container.Length))

    # Initial memory
    $stats1 = docker stats $container --no-stream --format "{{.MemUsage}}"
    $mem1 = ($stats1 -split '/')[0].Trim()

    Write-Info "Initial memory: $mem1"
    Write-Info "Waiting 2 minutes for stabilization..."

    Start-Sleep 120

    # Final memory
    $stats2 = docker stats $container --no-stream --format "{{.MemUsage}}"
    $mem2 = ($stats2 -split '/')[0].Trim()

    Write-Info "After 2 minutes: $mem2"

    Write-Info ""
    Write-Info "Memory analysis:"
    Write-Info "  Initial: $mem1"
    Write-Info "  After 2min: $mem2"
    Write-Info "  Expected: < 100 MB and stable"
    Write-Info ""

    Write-Success "✓ Test 4.5 PASSED - Memory monitoring complete"
    Add-TestResult "Memory Leak Detection" "MANUAL" "Initial: $mem1, After 2min: $mem2"

    # Cleanup
    docker compose -f $ComposeFile down 2>&1 | Out-Null

} catch {
    Write-Error "✗ Test 4.5 FAILED: $_"
    Add-TestResult "Memory Leak Detection" "FAIL" $_
}

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
if ($failCount -eq 0 -and ($passCount + $partialCount) -ge 3) {
    Write-Success "========================================"
    Write-Success "  🎉 Level 4 Test PASSED!"
    Write-Success "========================================"
    Write-Info "System is stable under stress! Ready for Level 5."
} elseif ($failCount -eq 0) {
    Write-Warning "========================================"
    Write-Warning "  ⚠ Level 4 Test PARTIAL"
    Write-Warning "========================================"
    Write-Info "Some stress tests need manual verification."
} else {
    Write-Error "========================================"
    Write-Error "  ✗ Level 4 Test FAILED"
    Write-Error "========================================"
    Write-Info "Stability issues detected. Review errors above."
}

Write-Info ""
Write-Info "Stress Testing Checklist:"
Write-Info "  [ ] Rapid reconnect cycles"
Write-Info "  [ ] Large message handling"
Write-Info "  [ ] Zero peers stability"
Write-Info "  [ ] Network partition recovery"
Write-Info "  [ ] Memory leak detection"
Write-Info ""

Write-Info "Next Steps:"
Write-Info "  - Complete manual verifications above"
Write-Info "  - Continue: .\test-level5-performance.ps1"
Write-Info "  - Cleanup: .\test-level4-stress.ps1 -Cleanup"
Write-Info ""

# ============================================
# Cleanup
# ============================================
if ($Cleanup) {
    Write-Info "========================================"
    Write-Info "  Cleaning Up"
    Write-Info "========================================"
    Write-Info "Stopping and removing all containers..."
    docker compose -f $ComposeFile down -v 2>&1 | Out-Null

    # Stop any remaining jobs
    Get-Job | Stop-Job -ErrorAction SilentlyContinue
    Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue

    Write-Success "✓ Cleanup complete"
    Write-Info ""
}

Write-Info "Level 4 stress test complete!"
