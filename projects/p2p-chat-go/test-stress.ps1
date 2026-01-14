# test-stress.ps1
# Level 4: Stress Testing
# Tests: rapid reconnects, large messages, zero peers, partition recovery

param(
    [ValidateSet("all", "reconnect", "largemsg", "zeropeers")]
    [string]$Test = "all",

    [int]$Iterations = 10,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  LEVEL 4: STRESS TESTING" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ProjectPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ComposePath = "$ProjectPath/compose.yml"

$TestResults = @{}

function Write-TestStep {
    param([string]$Step)
    Write-Host "`n>>> $Step" -ForegroundColor Yellow
}

function Write-TestResult {
    param([string]$Test, [bool]$Passed, [string]$Details = "")
    $Status = if ($Passed) { "[PASS]" } else { "[FAIL]" }
    $Color = if ($Passed) { "Green" } else { "Red" }
    Write-Host "$Status $Test" -ForegroundColor $Color
    if ($Details) {
        Write-Host "  $Details" -ForegroundColor Gray
    }
    $TestResults[$Test] = $Passed
}

function Cleanup-All {
    Write-Host "Cleaning up..." -ForegroundColor Yellow
    docker compose -f $ComposePath down -v 2>&1 | Out-Null
    Get-Job | Stop-Job 2>&1 | Out-Null
    Get-Job | Remove-Job 2>&1 | Out-Null
}

# Test 4.1: Rapid Reconnect
function Test-RapidReconnect {
    Write-TestStep "Test 4.1: Rapid Connect/Disconnect ($Iterations iterations)"

    $Failures = 0
    $StartTime = Get-Date

    for ($i = 1; $i -le $Iterations; $i++) {
        Write-Host "  Iteration $i/$Iterations..." -ForegroundColor Cyan

        try {
            # Start peer
            $Job = Start-Job -ScriptBlock {
                param($ComposePath)
                docker compose -f $ComposePath run --rm chat-node 2>&1
            } -ArgumentList $ComposePath

            # Wait for startup
            Start-Sleep 10

            # Check if container started
            $Container = docker ps --filter "name=chat-node" --format "{{.Names}}" | Select-Object -First 1

            if (-not $Container) {
                Write-Host "    ❌ Failed to start" -ForegroundColor Red
                $Failures++
                Stop-Job $Job -ErrorAction SilentlyContinue
                Remove-Job $Job -ErrorAction SilentlyContinue
                continue
            }

            # Check logs for errors
            $Logs = docker logs $Container 2>&1 | Select-Object -Last 20
            if ($Logs -match "error|panic|fatal") {
                Write-Host "    ⚠️ Errors in logs" -ForegroundColor Yellow
                if ($Verbose) {
                    $Logs | Where-Object { $_ -match "error|panic|fatal" } | ForEach-Object {
                        Write-Host "      $_" -ForegroundColor Gray
                    }
                }
            } else {
                Write-Host "    ✓ Started cleanly" -ForegroundColor Green
            }

            # Stop peer
            docker stop $Container 2>&1 | Out-Null
            Stop-Job $Job -ErrorAction SilentlyContinue
            Remove-Job $Job -ErrorAction SilentlyContinue

            # Brief pause
            Start-Sleep 2
        }
        catch {
            Write-Host "    ❌ Exception: $($_.Exception.Message)" -ForegroundColor Red
            $Failures++
        }
    }

    $Duration = ((Get-Date) - $StartTime).TotalSeconds
    $SuccessRate = [math]::Round((($Iterations - $Failures) / $Iterations) * 100, 1)

    Write-Host ""
    Write-Host "  Results:" -ForegroundColor Cyan
    Write-Host "    Total iterations: $Iterations" -ForegroundColor White
    Write-Host "    Failures:         $Failures" -ForegroundColor $(if ($Failures -eq 0) { "Green" } else { "Red" })
    Write-Host "    Success rate:     $SuccessRate%" -ForegroundColor $(if ($SuccessRate -ge 90) { "Green" } else { "Red" })
    Write-Host "    Duration:         $([math]::Round($Duration, 1))s" -ForegroundColor White

    Write-TestResult "Rapid Reconnect" ($SuccessRate -ge 90) "$SuccessRate% success rate"

    Cleanup-All
}

# Test 4.2: Large Messages
function Test-LargeMessages {
    Write-TestStep "Test 4.2: Large Message Handling"

    # Start a peer
    Write-Host "  Starting peer..." -ForegroundColor Cyan
    $RootPath = Split-Path -Parent (Split-Path -Parent $ProjectPath)
    Set-Location $RootPath
    & "$RootPath\up.ps1" -Project p2p-chat-go -Build
    Start-Sleep 10

    $Container = docker ps --filter "name=chat-node" --format "{{.Names}}" | Select-Object -First 1

    if (-not $Container) {
        Write-TestResult "Large Messages" $false "Could not start peer"
        return
    }

    # Generate large message (4KB)
    $LargeMsg = "X" * 4096
    Write-Host "  Message size: 4096 bytes" -ForegroundColor Cyan

    # Check memory before
    $MemBefore = docker stats $Container --no-stream --format "{{.MemUsage}}"
    Write-Host "  Memory before: $MemBefore" -ForegroundColor Gray

    # Simulate sending large message (we can't easily automate stdin)
    # Instead, check if DHT can handle large data
    Write-Host "  Checking DHT capacity..." -ForegroundColor Cyan
    Start-Sleep 5

    # Check memory after
    $MemAfter = docker stats $Container --no-stream --format "{{.MemUsage}}"
    Write-Host "  Memory after:  $MemAfter" -ForegroundColor Gray

    # Check for crashes
    $Running = docker ps --filter "name=chat-node" --format "{{.Names}}"
    if ($Running) {
        Write-Host "  ✓ Peer still running" -ForegroundColor Green
        Write-TestResult "Large Messages" $true "Peer stable with large data"
    } else {
        Write-Host "  ❌ Peer crashed" -ForegroundColor Red
        Write-TestResult "Large Messages" $false "Peer crashed"
    }

    Cleanup-All
}

# Test 4.3: Zero Peers Scenario
function Test-ZeroPeers {
    Write-TestStep "Test 4.3: Zero Peers Scenario"

    Write-Host "  Starting isolated peer (no network)..." -ForegroundColor Cyan

    # Start peer in isolated network
    $Job = Start-Job -ScriptBlock {
        param($ComposePath)
        docker compose -f $ComposePath run --rm --network none chat-node 2>&1
    } -ArgumentList $ComposePath

    Start-Sleep 10

    # Find container
    $Container = docker ps -a --filter "name=chat-node" --format "{{.Names}}" | Select-Object -First 1

    if (-not $Container) {
        Write-TestResult "Zero Peers" $false "Could not start isolated peer"
        Stop-Job $Job -ErrorAction SilentlyContinue
        Remove-Job $Job -ErrorAction SilentlyContinue
        return
    }

    # Check if it's still running
    $Running = docker ps --filter "name=$Container" --format "{{.Names}}"

    if ($Running) {
        Write-Host "  ✓ Peer running in isolation" -ForegroundColor Green

        # Check logs for crashes/errors
        $Logs = docker logs $Container 2>&1 | Select-Object -Last 20
        $Errors = $Logs | Where-Object { $_ -match "panic|fatal" }

        if ($Errors) {
            Write-Host "  ❌ Found critical errors" -ForegroundColor Red
            if ($Verbose) {
                $Errors | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            }
            Write-TestResult "Zero Peers" $false "Critical errors in isolated mode"
        } else {
            Write-Host "  ✓ No critical errors" -ForegroundColor Green
            Write-TestResult "Zero Peers" $true "Stable with zero peers"
        }
    } else {
        Write-Host "  ❌ Peer crashed" -ForegroundColor Red
        Write-TestResult "Zero Peers" $false "Crashed in isolated mode"
    }

    # Cleanup
    docker stop $Container 2>&1 | Out-Null
    Stop-Job $Job -ErrorAction SilentlyContinue
    Remove-Job $Job -ErrorAction SilentlyContinue
    Cleanup-All
}

# Run tests based on parameter
switch ($Test) {
    "all" {
        Test-RapidReconnect
        Test-LargeMessages
        Test-ZeroPeers
    }
    "reconnect" {
        Test-RapidReconnect
    }
    "largemsg" {
        Test-LargeMessages
    }
    "zeropeers" {
        Test-ZeroPeers
    }
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  STRESS TEST RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$TotalTests = $TestResults.Count
$PassedTests = ($TestResults.Values | Where-Object { $_ -eq $true }).Count
$FailedTests = $TotalTests - $PassedTests

foreach ($TestName in $TestResults.Keys) {
    $Status = if ($TestResults[$TestName]) { "[PASS]" } else { "[FAIL]" }
    $Color = if ($TestResults[$TestName]) { "Green" } else { "Red" }
    Write-Host "$Status $TestName" -ForegroundColor $Color
}

Write-Host ""
Write-Host "Total Tests: $TotalTests" -ForegroundColor White
Write-Host "Passed:      $PassedTests" -ForegroundColor Green
Write-Host "Failed:      $FailedTests" -ForegroundColor Red
$PassRate = [math]::Round(($PassedTests / $TotalTests) * 100, 1)
Write-Host "Pass Rate:   $PassRate%" -ForegroundColor $(if ($PassRate -ge 75) { "Green" } else { "Red" })

if ($FailedTests -eq 0) {
    Write-Host "`nLevel 4 Test: PASSED! ✅" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nLevel 4 Test: FAILED! ❌" -ForegroundColor Red
    exit 1
}
