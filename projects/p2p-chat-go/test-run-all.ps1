# ============================================
# P2P DHT Network - Run All Tests (Master Script)
# ============================================
# Runs all 5 test levels sequentially
# Duration: ~2-3 hours for complete testing
# Based on: TESTING-ROADMAP.md

param(
    [switch]$QuickMode,       # Run minimal tests (faster)
    [switch]$SkipLevel1,      # Skip Level 1 (Quick Start)
    [switch]$SkipLevel2,      # Skip Level 2 (Features)
    [switch]$SkipLevel3,      # Skip Level 3 (Network)
    [switch]$SkipLevel4,      # Skip Level 4 (Stress)
    [switch]$SkipLevel5,      # Skip Level 5 (Performance)
    [switch]$StopOnFailure,   # Stop if any test fails
    [switch]$GenerateReport,  # Generate HTML report at end
    [switch]$Cleanup          # Cleanup after all tests
)

$ErrorActionPreference = "Continue"  # Continue on errors to run all tests

# Colors
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error { Write-Host $args -ForegroundColor Red }
function Write-Step { Write-Host "`n$args" -ForegroundColor Magenta }
function Write-Title {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host $args -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host ""
}

# Test results tracking
$TestLevels = @()
$StartTime = Get-Date

# Banner
Clear-Host
Write-Title "P2P DHT Network - Complete Test Suite"
Write-Info "Starting comprehensive testing at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Info "Mode: $(if ($QuickMode) { 'QUICK' } else { 'FULL' })"
Write-Info ""

if ($QuickMode) {
    Write-Warning "Quick Mode: Running faster, less thorough tests"
    Write-Info ""
}

# Pre-flight checks
Write-Step "[Pre-flight] Environment Checks"
Write-Info "----------------------------------------"

# Check Docker
try {
    $dockerVersion = docker --version
    Write-Success "✓ Docker: $dockerVersion"
} catch {
    Write-Error "✗ Docker not found or not running"
    Write-Error "  Please install Docker and ensure it's running"
    exit 1
}

# Check Docker Compose
try {
    $composeVersion = docker compose version
    Write-Success "✓ Docker Compose: $composeVersion"
} catch {
    Write-Error "✗ Docker Compose not found"
    Write-Error "  Please install Docker Compose"
    exit 1
}

# Check project files
$ProjectPath = "projects/p2p-chat-go"
if (-not (Test-Path "$ProjectPath/compose.yml")) {
    Write-Error "✗ Project files not found at: $ProjectPath"
    exit 1
}
Write-Success "✓ Project files found"

Write-Info ""
Write-Info "Environment checks passed! Starting tests..."
Start-Sleep 3

# ============================================
# Level 1: Quick Start (5 min)
# ============================================
if (-not $SkipLevel1) {
    Write-Title "Level 1: Quick Start Test (5 min)"

    $level1Start = Get-Date

    try {
        $params = @{
            SkipBuild = $false
            Cleanup = $true
        }

        Write-Info "Executing: .\test-level1-quickstart.ps1"
        & "$ProjectPath\test-level1-quickstart.ps1" @params

        $level1Duration = (Get-Date) - $level1Start
        $level1Status = if ($LASTEXITCODE -eq 0) { "PASS" } else { "FAIL" }

        Write-Info ""
        Write-Info "Level 1 completed in $([math]::Round($level1Duration.TotalMinutes, 1)) minutes"

    } catch {
        Write-Error "Level 1 execution failed: $_"
        $level1Status = "FAIL"
        $level1Duration = (Get-Date) - $level1Start
    }

    $TestLevels += @{
        Level = "Level 1: Quick Start"
        Status = $level1Status
        Duration = $level1Duration
    }

    if ($StopOnFailure -and $level1Status -eq "FAIL") {
        Write-Error "Stopping test suite due to Level 1 failure"
        exit 1
    }

    Start-Sleep 5
}

# ============================================
# Level 2: Feature Testing (15 min)
# ============================================
if (-not $SkipLevel2) {
    Write-Title "Level 2: Feature Testing (15 min)"

    $level2Start = Get-Date

    try {
        $params = @{
            SkipSetup = $false
            Cleanup = $true
        }

        Write-Info "Executing: .\test-level2-features.ps1"
        & "$ProjectPath\test-level2-features.ps1" @params

        $level2Duration = (Get-Date) - $level2Start
        $level2Status = if ($LASTEXITCODE -eq 0) { "PASS" } else { "PARTIAL" }

    } catch {
        Write-Error "Level 2 execution failed: $_"
        $level2Status = "FAIL"
        $level2Duration = (Get-Date) - $level2Start
    }

    $TestLevels += @{
        Level = "Level 2: Feature Testing"
        Status = $level2Status
        Duration = $level2Duration
    }

    if ($StopOnFailure -and $level2Status -eq "FAIL") {
        Write-Error "Stopping test suite due to Level 2 failure"
        exit 1
    }

    Start-Sleep 5
}

# ============================================
# Level 3: Network Testing (30 min)
# ============================================
if (-not $SkipLevel3) {
    Write-Title "Level 3: Network Testing (30 min)"

    $level3Start = Get-Date

    try {
        $params = @{
            LANOnly = $QuickMode
            SkipSetup = $false
            Cleanup = $true
        }

        Write-Info "Executing: .\test-level3-network.ps1"
        & "$ProjectPath\test-level3-network.ps1" @params

        $level3Duration = (Get-Date) - $level3Start
        $level3Status = if ($LASTEXITCODE -eq 0) { "PASS" } else { "PARTIAL" }

    } catch {
        Write-Error "Level 3 execution failed: $_"
        $level3Status = "FAIL"
        $level3Duration = (Get-Date) - $level3Start
    }

    $TestLevels += @{
        Level = "Level 3: Network Testing"
        Status = $level3Status
        Duration = $level3Duration
    }

    if ($StopOnFailure -and $level3Status -eq "FAIL") {
        Write-Error "Stopping test suite due to Level 3 failure"
        exit 1
    }

    Start-Sleep 5
}

# ============================================
# Level 4: Stress Testing (45 min)
# ============================================
if (-not $SkipLevel4) {
    Write-Title "Level 4: Stress Testing (45 min)"

    $level4Start = Get-Date

    try {
        $params = @{
            RapidTestCycles = if ($QuickMode) { 5 } else { 10 }
            SkipRapidTest = $false
            SkipLargeMessage = $false
            Cleanup = $true
        }

        Write-Info "Executing: .\test-level4-stress.ps1"
        & "$ProjectPath\test-level4-stress.ps1" @params

        $level4Duration = (Get-Date) - $level4Start
        $level4Status = if ($LASTEXITCODE -eq 0) { "PASS" } else { "PARTIAL" }

    } catch {
        Write-Error "Level 4 execution failed: $_"
        $level4Status = "FAIL"
        $level4Duration = (Get-Date) - $level4Start
    }

    $TestLevels += @{
        Level = "Level 4: Stress Testing"
        Status = $level4Status
        Duration = $level4Duration
    }

    if ($StopOnFailure -and $level4Status -eq "FAIL") {
        Write-Error "Stopping test suite due to Level 4 failure"
        exit 1
    }

    Start-Sleep 5
}

# ============================================
# Level 5: Performance Testing (60 min)
# ============================================
if (-not $SkipLevel5) {
    Write-Title "Level 5: Performance Testing (60 min)"

    $level5Start = Get-Date

    try {
        $params = @{
            PeerCount = if ($QuickMode) { 3 } else { 5 }
            MonitorDuration = if ($QuickMode) { 120 } else { 300 }
            SkipThroughput = $false
            SkipScalability = $false
            Cleanup = $true
        }

        Write-Info "Executing: .\test-level5-performance.ps1"
        & "$ProjectPath\test-level5-performance.ps1" @params

        $level5Duration = (Get-Date) - $level5Start
        $level5Status = if ($LASTEXITCODE -eq 0) { "PASS" } else { "PARTIAL" }

    } catch {
        Write-Error "Level 5 execution failed: $_"
        $level5Status = "FAIL"
        $level5Duration = (Get-Date) - $level5Start
    }

    $TestLevels += @{
        Level = "Level 5: Performance Testing"
        Status = $level5Status
        Duration = $level5Duration
    }

    Start-Sleep 5
}

# ============================================
# Final Summary
# ============================================
Write-Title "Test Suite Complete - Final Summary"

$TotalDuration = (Get-Date) - $StartTime
$TotalPassed = ($TestLevels | Where-Object { $_.Status -eq "PASS" }).Count
$TotalPartial = ($TestLevels | Where-Object { $_.Status -eq "PARTIAL" }).Count
$TotalFailed = ($TestLevels | Where-Object { $_.Status -eq "FAIL" }).Count
$TotalTests = $TestLevels.Count

Write-Info "Test Results Summary:"
Write-Info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

foreach ($level in $TestLevels) {
    $symbol = switch ($level.Status) {
        "PASS" { "✓"; $color = "Green" }
        "FAIL" { "✗"; $color = "Red" }
        "PARTIAL" { "⚠"; $color = "Yellow" }
    }

    $duration = $level.Duration
    $durationStr = if ($duration.TotalMinutes -lt 60) {
        "$([math]::Round($duration.TotalMinutes, 1)) min"
    } else {
        "$([math]::Round($duration.TotalHours, 1)) hr"
    }

    Write-Host "  $symbol $($level.Level) - $durationStr" -ForegroundColor $color
}

Write-Info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Info ""
Write-Info "Overall Results:"
Write-Info "  Total tests: $TotalTests"
Write-Success "  Passed: $TotalPassed"
Write-Warning "  Partial: $TotalPartial"
Write-Error "  Failed: $TotalFailed"
Write-Info ""
Write-Info "Total Duration: $([math]::Round($TotalDuration.TotalHours, 2)) hours"
Write-Info ""

# Overall assessment
if ($TotalFailed -eq 0 -and $TotalPassed -eq $TotalTests) {
    Write-Success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Success "  🎉 ALL TESTS PASSED!"
    Write-Success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Success "  P2P DHT Network is production-ready!"
    Write-Success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
} elseif ($TotalFailed -eq 0) {
    Write-Warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Warning "  ⚠ TESTS COMPLETED WITH WARNINGS"
    Write-Warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Info "  Some manual verifications required."
    Write-Info "  Review partial test results above."
} else {
    Write-Error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Error "  ✗ SOME TESTS FAILED"
    Write-Error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Info "  Review failed tests and fix issues."
}

Write-Info ""

# ============================================
# Generate Report
# ============================================
if ($GenerateReport) {
    Write-Step "Generating HTML Report"
    Write-Info "----------------------------------------"

    $reportPath = "$ProjectPath\test-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>P2P DHT Network Test Results</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1000px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        .summary { background: #ecf0f1; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .test-level { margin: 15px 0; padding: 15px; border-left: 4px solid #3498db; background: #f9f9f9; }
        .pass { border-left-color: #27ae60; }
        .fail { border-left-color: #e74c3c; }
        .partial { border-left-color: #f39c12; }
        .status { font-weight: bold; padding: 3px 8px; border-radius: 3px; }
        .status.pass { background: #27ae60; color: white; }
        .status.fail { background: #e74c3c; color: white; }
        .status.partial { background: #f39c12; color: white; }
        .timestamp { color: #7f8c8d; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <h1>P2P DHT Network - Test Results</h1>
        <p class="timestamp">Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>

        <div class="summary">
            <h2>Summary</h2>
            <p><strong>Total Tests:</strong> $TotalTests</p>
            <p><strong>Passed:</strong> $TotalPassed</p>
            <p><strong>Partial:</strong> $TotalPartial</p>
            <p><strong>Failed:</strong> $TotalFailed</p>
            <p><strong>Duration:</strong> $([math]::Round($TotalDuration.TotalHours, 2)) hours</p>
        </div>

        <h2>Test Levels</h2>
"@

    foreach ($level in $TestLevels) {
        $statusClass = $level.Status.ToLower()
        $duration = "$([math]::Round($level.Duration.TotalMinutes, 1)) min"

        $html += @"
        <div class="test-level $statusClass">
            <h3>$($level.Level)</h3>
            <p><span class="status $statusClass">$($level.Status)</span> - Duration: $duration</p>
        </div>
"@
    }

    $html += @"
    </div>
</body>
</html>
"@

    try {
        $html | Out-File -FilePath $reportPath -Encoding UTF8
        Write-Success "✓ Report generated: $reportPath"
        Write-Info "  Open in browser to view detailed results"
    } catch {
        Write-Warning "⚠ Failed to generate report: $_"
    }

    Write-Info ""
}

# ============================================
# Cleanup
# ============================================
if ($Cleanup) {
    Write-Step "Final Cleanup"
    Write-Info "----------------------------------------"

    Write-Info "Cleaning up all Docker resources..."

    try {
        docker compose -f "$ProjectPath/compose.yml" down -v 2>&1 | Out-Null
        Write-Success "✓ Cleanup complete"
    } catch {
        Write-Warning "⚠ Cleanup encountered issues: $_"
    }

    Write-Info ""
}

# ============================================
# Next Steps
# ============================================
Write-Info "Next Steps:"
Write-Info "  - Review test results above"

if ($TotalPartial -gt 0) {
    Write-Info "  - Complete manual verifications for partial tests"
}

if ($TotalFailed -gt 0) {
    Write-Info "  - Fix issues in failed test levels"
    Write-Info "  - Re-run specific levels: .\test-levelX-xxx.ps1"
}

if ($GenerateReport) {
    Write-Info "  - Review HTML report for detailed results"
}

Write-Info "  - Document results in TEST-RESULTS-TEMPLATE.md"
Write-Info ""

Write-Success "Test suite execution complete!"
Write-Info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
