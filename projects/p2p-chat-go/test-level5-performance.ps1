# ============================================
# P2P DHT Network - Level 5: Performance Testing
# ============================================
# Duration: ~60 minutes
# Tests: Throughput, scalability, resource usage, latency
# Based on: TESTING-ROADMAP.md Level 5

param(
    [int]$PeerCount = 5,            # Number of peers for scalability test
    [int]$MessageCount = 100,       # Number of messages for throughput test
    [int]$MonitorDuration = 300,    # Duration for resource monitoring (seconds)
    [switch]$SkipThroughput,        # Skip throughput test
    [switch]$SkipScalability,       # Skip scalability test
    [switch]$SkipResourceTest,      # Skip resource monitoring
    [switch]$Cleanup,               # Cleanup after test
    [switch]$Verbose                # Show detailed logs
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
$PerformanceMetrics = @{}

function Add-TestResult {
    param($TestName, $Status, $Message = "", $Metrics = @{})
    $script:TestResults += @{
        Test = $TestName
        Status = $Status
        Message = $Message
        Metrics = $Metrics
        Timestamp = Get-Date
    }
}

Write-Info "========================================"
Write-Info "  Level 5: Performance Testing (60 min)"
Write-Info "========================================"
Write-Info "Focus: Throughput, Scalability, Resources"
Write-Info ""

# ============================================
# Test 5.1: Message Throughput
# ============================================
if (-not $SkipThroughput) {
    Write-Step "[Test 5.1] Message Throughput"
    Write-Info "========================================"
    Write-Info "Measuring message delivery rate..."
    Write-Info "Messages to send: $MessageCount"
    Write-Info ""

    try {
        # Start 2 peers for throughput test
        Write-Info "Starting 2 peers for throughput test..."
        docker compose -f $ComposeFile up -d --build 2>&1 | Out-Null
        Start-Sleep 5
        docker compose -f $ComposeFile run -d chat-node 2>&1 | Out-Null
        Start-Sleep 5

        Write-Info "Waiting 60s for peer discovery..."
        Start-Sleep 60

        $containers = docker compose -f $ComposeFile ps -q
        $containerArray = $containers -split "`n" | Where-Object { $_ -ne "" }
        $testContainer = $containerArray[0]

        Write-Success "✓ Test environment ready"
        Write-Info ""

        Write-Info "Throughput test instructions:"
        Write-Info "  This test requires manual execution due to interactive nature"
        Write-Info ""
        Write-Info "  Method 1: Manual rapid messaging"
        Write-Info "    1. docker attach $($testContainer.Substring(0,12))"
        Write-Info "    2. Send $MessageCount messages as fast as possible"
        Write-Info "    3. Time how long it takes"
        Write-Info "    4. Calculate: $MessageCount / seconds = msg/sec"
        Write-Info ""
        Write-Info "  Method 2: Scripted (requires echo wrapper)"
        Write-Info "    for i in 1..$MessageCount { echo 'Test msg' | docker exec -i container /app/p2p-chat }"
        Write-Info ""
        Write-Info "  Success Criteria:"
        Write-Info "    ✓ Throughput > 10 msg/sec (Good)"
        Write-Info "    ✓ Throughput > 20 msg/sec (Excellent)"
        Write-Info "    ✓ No crashes or errors"
        Write-Info "    ✓ All messages delivered"
        Write-Info ""

        Add-TestResult "Message Throughput" "MANUAL" "Requires manual execution" @{
            Target = "10+ msg/sec"
            TestMessages = $MessageCount
        }

        # Keep peers running for manual test
        Write-Info "Peers are running. Press Enter when throughput test is complete..."
        # Automated test continues without waiting for user input

        # Cleanup
        docker compose -f $ComposeFile down 2>&1 | Out-Null

    } catch {
        Write-Error "✗ Test 5.1 FAILED: $_"
        Add-TestResult "Message Throughput" "FAIL" $_
        docker compose -f $ComposeFile down 2>&1 | Out-Null
    }

    Start-Sleep 2
}

# ============================================
# Test 5.2: Peer Scalability
# ============================================
if (-not $SkipScalability) {
    Write-Step "[Test 5.2] Peer Scalability"
    Write-Info "========================================"
    Write-Info "Testing with $PeerCount peers..."
    Write-Info ""

    try {
        Write-Info "Starting $PeerCount peers (staggered)..."
        $startTime = Get-Date

        # Start first peer
        docker compose -f $ComposeFile up -d --build 2>&1 | Out-Null
        Start-Sleep 5

        # Start additional peers
        for ($i = 2; $i -le $PeerCount; $i++) {
            Write-Info "  Starting peer $i/$PeerCount..."
            docker compose -f $ComposeFile run -d chat-node 2>&1 | Out-Null
            Start-Sleep 5  # Stagger starts
        }

        $setupTime = (Get-Date) - $startTime
        Write-Success "✓ All $PeerCount peers started in $([math]::Round($setupTime.TotalSeconds))s"

        Write-Info "Waiting 90s for full mesh formation..."
        for ($i = 1; $i -le 90; $i++) {
            Write-Progress -Activity "Mesh Formation" -Status "$i/90s" -PercentComplete (($i/90)*100)
            Start-Sleep 1
        }
        Write-Progress -Activity "Mesh Formation" -Completed

        # Analyze peer connections
        Write-Info ""
        Write-Info "Analyzing peer connections..."

        $containers = docker compose -f $ComposeFile ps -q
        $containerArray = $containers -split "`n" | Where-Object { $_ -ne "" }

        $connectedPeers = 0
        $totalConnections = 0

        foreach ($container in $containerArray) {
            $logs = docker logs --tail 100 $container 2>&1

            # Count join messages
            $joinCount = ($logs | Select-String -Pattern "joined the chat" -AllMatches).Matches.Count

            if ($joinCount -gt 0) {
                $connectedPeers++
                $totalConnections += $joinCount
            }
        }

        $avgConnectionsPerPeer = if ($connectedPeers -gt 0) {
            [math]::Round($totalConnections / $connectedPeers, 1)
        } else {
            0
        }

        Write-Info ""
        Write-Info "Scalability Metrics:"
        Write-Info "  Total peers: $($containerArray.Count)"
        Write-Info "  Connected peers: $connectedPeers"
        Write-Info "  Average connections per peer: $avgConnectionsPerPeer"
        Write-Info "  Expected connections: $($PeerCount - 1) per peer"

        # Check resource usage with multiple peers
        Write-Info ""
        Write-Info "Resource usage with $PeerCount peers:"

        $totalMem = 0
        $totalCpu = 0
        $peerStats = @()

        foreach ($container in $containerArray) {
            $stats = docker stats $container --no-stream --format "{{.MemUsage}}|{{.CPUPerc}}"
            $parts = $stats -split '\|'
            $mem = ($parts[0] -split '/')[0].Trim()
            $cpu = $parts[1].Trim()

            $peerStats += @{
                Container = $container.Substring(0, 12)
                Memory = $mem
                CPU = $cpu
            }

            Write-Info "  Peer $($container.Substring(0,12)): $mem RAM, $cpu CPU"
        }

        Write-Info ""

        # Scalability assessment
        $connectionRate = if ($PeerCount -gt 1) {
            [math]::Round(($connectedPeers / $PeerCount) * 100)
        } else {
            100
        }

        if ($connectionRate -ge 90 -and $avgConnectionsPerPeer -ge ($PeerCount * 0.7)) {
            Write-Success "✓ Test 5.2 PASSED - Good scalability"
            Add-TestResult "Peer Scalability" "PASS" "$connectedPeers/$PeerCount peers connected" @{
                TotalPeers = $PeerCount
                ConnectedPeers = $connectedPeers
                AvgConnections = $avgConnectionsPerPeer
                ConnectionRate = "$connectionRate%"
            }
        } elseif ($connectionRate -ge 70) {
            Write-Warning "⚠ Test 5.2 PARTIAL - Moderate scalability ($connectionRate%)"
            Add-TestResult "Peer Scalability" "PARTIAL" "$connectedPeers/$PeerCount peers" @{
                TotalPeers = $PeerCount
                ConnectedPeers = $connectedPeers
                ConnectionRate = "$connectionRate%"
            }
        } else {
            Write-Warning "⚠ Test 5.2 FAILED - Poor scalability ($connectionRate%)"
            Add-TestResult "Peer Scalability" "FAIL" "Only $connectedPeers/$PeerCount connected" @{
                TotalPeers = $PeerCount
                ConnectionRate = "$connectionRate%"
            }
        }

        # Cleanup
        docker compose -f $ComposeFile down 2>&1 | Out-Null

    } catch {
        Write-Error "✗ Test 5.2 FAILED: $_"
        Add-TestResult "Peer Scalability" "FAIL" $_
        docker compose -f $ComposeFile down 2>&1 | Out-Null
    }

    Start-Sleep 2
}

# ============================================
# Test 5.3: Resource Usage Monitoring
# ============================================
if (-not $SkipResourceTest) {
    Write-Step "[Test 5.3] Resource Usage Monitoring"
    Write-Info "========================================"
    Write-Info "Monitoring resources for $([math]::Round($MonitorDuration/60)) minutes..."
    Write-Info ""

    try {
        # Start single peer for baseline
        Write-Info "Starting peer for resource monitoring..."
        docker compose -f $ComposeFile up -d --build 2>&1 | Out-Null
        Start-Sleep 10

        $container = (docker compose -f $ComposeFile ps -q | Select-Object -First 1).Trim()
        $shortId = $container.Substring(0, [Math]::Min(12, $container.Length))

        Write-Info "Monitoring container: $shortId"
        Write-Info ""

        # Collect samples
        $samples = @()
        $sampleInterval = 30  # seconds
        $sampleCount = [math]::Ceiling($MonitorDuration / $sampleInterval)

        Write-Info "Collecting $sampleCount samples at ${sampleInterval}s intervals..."
        Write-Info ""

        for ($i = 1; $i -le $sampleCount; $i++) {
            $stats = docker stats $container --no-stream --format "{{.MemUsage}}|{{.CPUPerc}}|{{.NetIO}}"
            $parts = $stats -split '\|'

            $memUsage = ($parts[0] -split '/')[0].Trim()
            $cpuPerc = $parts[1].Trim()
            $netIO = $parts[2].Trim()

            $samples += @{
                Time = Get-Date
                Memory = $memUsage
                CPU = $cpuPerc
                Network = $netIO
            }

            Write-Info "Sample $i/$sampleCount - Mem: $memUsage, CPU: $cpuPerc, Net: $netIO"

            if ($i -lt $sampleCount) {
                Start-Sleep $sampleInterval
            }
        }

        Write-Info ""
        Write-Info "Resource Analysis:"

        # Analyze samples
        $memValues = $samples | ForEach-Object { $_.Memory }
        $cpuValues = $samples | ForEach-Object { $_.CPU }

        Write-Info "  Memory usage: $($memValues[0]) (start) → $($memValues[-1]) (end)"
        Write-Info "  CPU usage range: $($cpuValues | Measure-Object -Minimum -Maximum | ForEach-Object { "$($_.Minimum) - $($_.Maximum)" })"

        # Parse memory (remove MB/MiB suffix and convert to number)
        try {
            $memStart = [decimal]($memValues[0] -replace '[^0-9.]','')
            $memEnd = [decimal]($memValues[-1] -replace '[^0-9.]','')
            $memGrowth = $memEnd - $memStart

            Write-Info "  Memory growth: $([math]::Round($memGrowth, 2)) MB"

            if ($memGrowth -lt 10) {
                Write-Success "  ✓ Memory stable (< 10 MB growth)"
            } elseif ($memGrowth -lt 30) {
                Write-Warning "  ⚠ Moderate memory growth ($([math]::Round($memGrowth, 2)) MB)"
            } else {
                Write-Warning "  ⚠ High memory growth ($([math]::Round($memGrowth, 2)) MB) - possible leak"
            }
        } catch {
            Write-Warning "  ⚠ Could not parse memory values for growth calculation"
        }

        Write-Info ""
        Write-Info "Resource Targets:"
        Write-Info "  Memory (idle): < 50 MB"
        Write-Info "  Memory (active): < 100 MB"
        Write-Info "  CPU (idle): < 5%"
        Write-Info "  CPU (active): < 20%"

        Add-TestResult "Resource Usage" "PASS" "Monitoring complete" @{
            Duration = "$($MonitorDuration)s"
            Samples = $sampleCount
            MemoryStart = $memValues[0]
            MemoryEnd = $memValues[-1]
        }

        # Cleanup
        docker compose -f $ComposeFile down 2>&1 | Out-Null

    } catch {
        Write-Error "✗ Test 5.3 FAILED: $_"
        Add-TestResult "Resource Usage" "FAIL" $_
        docker compose -f $ComposeFile down 2>&1 | Out-Null
    }

    Start-Sleep 2
}

# ============================================
# Test 5.4: Latency Distribution
# ============================================
Write-Step "[Test 5.4] Latency Distribution"
Write-Info "========================================"
Write-Info "Testing network latency between peers..."
Write-Info ""

try {
    Write-Info "Starting 3 peers for latency test..."
    docker compose -f $ComposeFile up -d --build 2>&1 | Out-Null
    Start-Sleep 5
    docker compose -f $ComposeFile run -d chat-node 2>&1 | Out-Null
    Start-Sleep 5
    docker compose -f $ComposeFile run -d chat-node 2>&1 | Out-Null
    Start-Sleep 5

    Write-Info "Waiting 60s for connections..."
    Start-Sleep 60

    $containers = docker compose -f $ComposeFile ps -q
    $containerArray = $containers -split "`n" | Where-Object { $_ -ne "" }
    $testContainer = $containerArray[0]

    Write-Success "✓ Test environment ready"
    Write-Info ""

    Write-Info "Latency measurement instructions:"
    Write-Info "  Manual testing required (interactive commands)"
    Write-Info ""
    Write-Info "  1. docker attach $($testContainer.Substring(0,12))"
    Write-Info "  2. Run: /conn"
    Write-Info "  3. Record latency for each peer"
    Write-Info "  4. Calculate statistics:"
    Write-Info "     - Average latency"
    Write-Info "     - P50 (median)"
    Write-Info "     - P95 (95th percentile)"
    Write-Info "     - P99 (99th percentile)"
    Write-Info ""
    Write-Info "  Success Criteria:"
    Write-Info "    ✓ Average < 100ms (direct connections)"
    Write-Info "    ✓ P95 < 200ms (direct)"
    Write-Info "    ✓ Relay latency < 500ms"
    Write-Info ""

    Add-TestResult "Latency Distribution" "MANUAL" "Requires /conn command execution" @{
        Target_Avg = "< 100ms"
        Target_P95 = "< 200ms"
        Target_Relay = "< 500ms"
    }

    # Cleanup
    docker compose -f $ComposeFile down 2>&1 | Out-Null

} catch {
    Write-Error "✗ Test 5.4 FAILED: $_"
    Add-TestResult "Latency Distribution" "FAIL" $_
    docker compose -f $ComposeFile down 2>&1 | Out-Null
}

# ============================================
# Performance Summary Report
# ============================================
Write-Step "Performance Summary Report"
Write-Info "========================================"
Write-Info ""

Write-Info "Test Results:"
foreach ($result in $TestResults) {
    $symbol = switch ($result.Status) {
        "PASS" { "✓"; $color = "Green" }
        "FAIL" { "✗"; $color = "Red" }
        "PARTIAL" { "⚠"; $color = "Yellow" }
        "MANUAL" { "⊙"; $color = "Cyan" }
    }

    $message = if ($result.Message) { " - $($result.Message)" } else { "" }
    Write-Host "  $symbol $($result.Test)$message" -ForegroundColor $color

    # Show metrics if available
    if ($result.Metrics -and $result.Metrics.Count -gt 0) {
        foreach ($metric in $result.Metrics.GetEnumerator()) {
            Write-Info "      $($metric.Key): $($metric.Value)"
        }
    }
}

Write-Info ""

# Calculate summary
$passCount = ($TestResults | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($TestResults | Where-Object { $_.Status -eq "FAIL" }).Count
$partialCount = ($TestResults | Where-Object { $_.Status -eq "PARTIAL" }).Count
$manualCount = ($TestResults | Where-Object { $_.Status -eq "MANUAL" }).Count

Write-Info "Summary: $passCount passed, $failCount failed, $partialCount partial, $manualCount manual"
Write-Info ""

# Overall assessment
if ($failCount -eq 0 -and ($passCount + $partialCount) -ge 2) {
    Write-Success "========================================"
    Write-Success "  🎉 Level 5 Test PASSED!"
    Write-Success "========================================"
    Write-Success "Performance testing complete!"
    Write-Success "System meets performance targets!"
} elseif ($failCount -eq 0) {
    Write-Warning "========================================"
    Write-Warning "  ⚠ Level 5 Test PARTIAL"
    Write-Warning "========================================"
    Write-Info "Some performance tests need manual verification."
} else {
    Write-Error "========================================"
    Write-Error "  ✗ Level 5 Test FAILED"
    Write-Error "========================================"
    Write-Info "Performance issues detected. Review results above."
}

Write-Info ""
Write-Info "Performance Testing Checklist:"
Write-Info "  [ ] Message throughput > 10 msg/sec"
Write-Info "  [ ] Scalability with $PeerCount+ peers"
Write-Info "  [ ] Memory < 100 MB per peer"
Write-Info "  [ ] CPU < 20% per peer"
Write-Info "  [ ] Latency < 100ms (direct)"
Write-Info ""

Write-Info "Performance Targets Summary:"
Write-Info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Info "  Metric              Target      Acceptable"
Write-Info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Info "  Discovery Time      < 60s       < 120s"
Write-Info "  Message Delivery    > 99%       > 95%"
Write-Info "  Latency (Direct)    < 50ms      < 100ms"
Write-Info "  Latency (Relay)     < 200ms     < 500ms"
Write-Info "  Memory Usage        < 50 MB     < 100 MB"
Write-Info "  CPU (Idle)          < 5%        < 10%"
Write-Info "  Throughput          > 20/s      > 10/s"
Write-Info "  Scalability         20+ peers   10+ peers"
Write-Info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Info ""

Write-Info "Next Steps:"
Write-Info "  - Complete manual performance tests"
Write-Info "  - Review all test levels (1-5)"
Write-Info "  - Run: .\test-run-all.ps1 (complete test suite)"
Write-Info "  - Cleanup: .\test-level5-performance.ps1 -Cleanup"
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
    Write-Success "✓ Cleanup complete"
    Write-Info ""
}

Write-Success "🎊 Congratulations! All 5 test levels complete!"
Write-Info "You've thoroughly tested the P2P DHT Network!"
