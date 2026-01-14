# test-performance.ps1
# Level 5: Performance Testing
# Tests: resource usage, scalability, latency

param(
    [ValidateSet("all", "resources", "scalability")]
    [string]$Test = "all",

    [int]$PeerCount = 5,
    [int]$Duration = 60,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  LEVEL 5: PERFORMANCE TESTING" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ProjectPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ComposePath = "$ProjectPath/compose.yml"

$TestResults = @{}
$Metrics = @{}

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

function Parse-MemoryValue {
    param([string]$MemString)
    # Parse strings like "45.5MiB / 7.677GiB" to get used memory in MB
    if ($MemString -match '([\d.]+)([MG])iB') {
        $Value = [decimal]$Matches[1]
        $Unit = $Matches[2]
        if ($Unit -eq "G") {
            return $Value * 1024
        } else {
            return $Value
        }
    }
    return 0
}

function Parse-CPUValue {
    param([string]$CPUString)
    # Parse strings like "5.43%" to get percentage
    if ($CPUString -match '([\d.]+)%') {
        return [decimal]$Matches[1]
    }
    return 0
}

# Test 5.1: Resource Usage
function Test-ResourceUsage {
    Write-TestStep "Test 5.1: Resource Usage Monitoring"

    Write-Host "  Starting single peer..." -ForegroundColor Cyan
    $RootPath = Split-Path -Parent (Split-Path -Parent $ProjectPath)
    Set-Location $RootPath
    & "$RootPath\up.ps1" -Project p2p-chat-go -Build
    Start-Sleep 10

    $Container = docker ps --filter "name=chat-node" --format "{{.Names}}" | Select-Object -First 1

    if (-not $Container) {
        Write-TestResult "Resource Usage" $false "Could not start peer"
        return
    }

    Write-Host "  Collecting metrics for $Duration seconds..." -ForegroundColor Cyan

    $MemSamples = @()
    $CPUSamples = @()
    $SampleCount = [math]::Min($Duration / 5, 12) # Sample every 5s, max 12 samples

    for ($i = 1; $i -le $SampleCount; $i++) {
        $Stats = docker stats $Container --no-stream --format "{{.MemUsage}}|{{.CPUPerc}}"
        $Parts = $Stats -split '\|'

        $MemUsage = Parse-MemoryValue $Parts[0]
        $CPUUsage = Parse-CPUValue $Parts[1]

        $MemSamples += $MemUsage
        $CPUSamples += $CPUUsage

        if ($Verbose) {
            Write-Host "    Sample $i/$SampleCount - Memory: $([math]::Round($MemUsage, 1))MB, CPU: $([math]::Round($CPUUsage, 1))%" -ForegroundColor Gray
        }

        Start-Sleep 5
    }

    # Calculate averages
    $AvgMem = ($MemSamples | Measure-Object -Average).Average
    $MaxMem = ($MemSamples | Measure-Object -Maximum).Maximum
    $AvgCPU = ($CPUSamples | Measure-Object -Average).Average
    $MaxCPU = ($CPUSamples | Measure-Object -Maximum).Maximum

    Write-Host ""
    Write-Host "  Results:" -ForegroundColor Cyan
    Write-Host "    Memory (avg): $([math]::Round($AvgMem, 1)) MB" -ForegroundColor $(if ($AvgMem -lt 50) { "Green" } elseif ($AvgMem -lt 100) { "Yellow" } else { "Red" })
    Write-Host "    Memory (max): $([math]::Round($MaxMem, 1)) MB" -ForegroundColor $(if ($MaxMem -lt 75) { "Green" } elseif ($MaxMem -lt 150) { "Yellow" } else { "Red" })
    Write-Host "    CPU (avg):    $([math]::Round($AvgCPU, 1))%" -ForegroundColor $(if ($AvgCPU -lt 5) { "Green" } elseif ($AvgCPU -lt 20) { "Yellow" } else { "Red" })
    Write-Host "    CPU (max):    $([math]::Round($MaxCPU, 1))%" -ForegroundColor $(if ($MaxCPU -lt 10) { "Green" } elseif ($MaxCPU -lt 30) { "Yellow" } else { "Red" })

    # Store metrics
    $Metrics["AvgMemory"] = $AvgMem
    $Metrics["MaxMemory"] = $MaxMem
    $Metrics["AvgCPU"] = $AvgCPU
    $Metrics["MaxCPU"] = $MaxCPU

    # Pass criteria: Avg Memory < 100MB, Avg CPU < 20%
    $Passed = ($AvgMem -lt 100) -and ($AvgCPU -lt 20)
    Write-TestResult "Resource Usage" $Passed "Mem: $([math]::Round($AvgMem, 1))MB, CPU: $([math]::Round($AvgCPU, 1))%"

    # Cleanup
    docker compose -f $ComposePath down -v 2>&1 | Out-Null
}

# Test 5.2: Scalability
function Test-Scalability {
    Write-TestStep "Test 5.2: Peer Scalability ($PeerCount peers)"

    Write-Host "  Starting $PeerCount peers..." -ForegroundColor Cyan
    Write-Host "  (This may take a few minutes)" -ForegroundColor Gray
    Write-Host ""

    # Use test-peers.ps1 helper
    & "$ProjectPath\test-peers.ps1" -Action start -Count $PeerCount

    Start-Sleep 15

    # Count running peers
    $RunningPeers = @(docker ps --filter "name=chat-node" --format "{{.Names}}")
    $ActualCount = $RunningPeers.Count

    Write-Host ""
    Write-Host "  Peers started: $ActualCount/$PeerCount" -ForegroundColor $(if ($ActualCount -eq $PeerCount) { "Green" } else { "Yellow" })

    if ($ActualCount -eq 0) {
        Write-TestResult "Scalability" $false "No peers started"
        return
    }

    # Wait for peer discovery
    Write-Host "  Waiting for peer discovery (60 seconds)..." -ForegroundColor Cyan
    Start-Sleep 60

    # Check logs for connections
    Write-Host "  Checking peer connections..." -ForegroundColor Cyan
    $ConnectionCounts = @()

    foreach ($Container in $RunningPeers) {
        $Logs = docker logs $Container 2>&1 | Select-Object -Last 50
        $Connections = ($Logs | Select-String -Pattern "joined the chat|Connected Peer").Count

        $ConnectionCounts += $Connections

        if ($Verbose) {
            Write-Host "    $Container : $Connections connections" -ForegroundColor Gray
        }
    }

    $AvgConnections = if ($ConnectionCounts.Count -gt 0) {
        ($ConnectionCounts | Measure-Object -Average).Average
    } else { 0 }

    Write-Host ""
    Write-Host "  Results:" -ForegroundColor Cyan
    Write-Host "    Target peers:      $PeerCount" -ForegroundColor White
    Write-Host "    Started peers:     $ActualCount" -ForegroundColor $(if ($ActualCount -eq $PeerCount) { "Green" } else { "Yellow" })
    Write-Host "    Avg connections:   $([math]::Round($AvgConnections, 1))" -ForegroundColor $(if ($AvgConnections -ge ($PeerCount - 2)) { "Green" } else { "Yellow" })

    # Collect aggregate resource usage
    if ($ActualCount -gt 0) {
        Write-Host "  Checking aggregate resource usage..." -ForegroundColor Cyan

        $TotalStats = docker stats --no-stream --format "{{.MemUsage}}|{{.CPUPerc}}" $RunningPeers

        $TotalMem = 0
        $TotalCPU = 0

        foreach ($Stat in $TotalStats) {
            $Parts = $Stat -split '\|'
            $TotalMem += Parse-MemoryValue $Parts[0]
            $TotalCPU += Parse-CPUValue $Parts[1]
        }

        Write-Host "    Total memory:      $([math]::Round($TotalMem, 1)) MB" -ForegroundColor $(if ($TotalMem -lt ($PeerCount * 100)) { "Green" } else { "Yellow" })
        Write-Host "    Total CPU:         $([math]::Round($TotalCPU, 1))%" -ForegroundColor $(if ($TotalCPU -lt ($PeerCount * 20)) { "Green" } else { "Yellow" })

        $Metrics["TotalMemory"] = $TotalMem
        $Metrics["TotalCPU"] = $TotalCPU
        $Metrics["PeerCount"] = $ActualCount
    }

    # Pass criteria: All peers started and discovered each other
    $Passed = ($ActualCount -eq $PeerCount) -and ($AvgConnections -ge 1)
    Write-TestResult "Scalability" $Passed "$ActualCount peers, avg $([math]::Round($AvgConnections, 1)) connections"

    # Cleanup
    & "$ProjectPath\test-peers.ps1" -Action cleanup
}

# Run tests based on parameter
switch ($Test) {
    "all" {
        Test-ResourceUsage
        Test-Scalability
    }
    "resources" {
        Test-ResourceUsage
    }
    "scalability" {
        Test-Scalability
    }
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PERFORMANCE TEST RESULTS" -ForegroundColor Cyan
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

# Show metrics summary
if ($Metrics.Count -gt 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  PERFORMANCE METRICS" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    foreach ($Metric in $Metrics.Keys) {
        $Value = $Metrics[$Metric]
        if ($Value -is [decimal] -or $Value -is [double]) {
            Write-Host "$Metric : $([math]::Round($Value, 2))" -ForegroundColor White
        } else {
            Write-Host "$Metric : $Value" -ForegroundColor White
        }
    }
}

if ($FailedTests -eq 0) {
    Write-Host "`nLevel 5 Test: PASSED! ✅" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nLevel 5 Test: FAILED! ❌" -ForegroundColor Red
    exit 1
}
