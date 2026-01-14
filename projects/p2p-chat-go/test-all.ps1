# test-all.ps1
# Master test script - Run all test levels

param(
    [ValidateSet("1", "2", "3", "4", "5", "all", "quick", "full")]
    [string]$Level = "all",

    [switch]$SkipCleanup,
    [switch]$StopOnFailure,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                        ║" -ForegroundColor Cyan
Write-Host "║   P2P DHT NETWORK - TEST SUITE         ║" -ForegroundColor Cyan
Write-Host "║                                        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$ProjectPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$StartTime = Get-Date

# Test results tracking
$GlobalResults = @{}

function Run-TestLevel {
    param(
        [string]$LevelName,
        [string]$ScriptName,
        [hashtable]$Params = @{}
    )

    Write-Host ""
    Write-Host "════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host " Running: $LevelName" -ForegroundColor Yellow
    Write-Host "════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""

    $LevelStart = Get-Date

    try {
        $ScriptPath = Join-Path $ProjectPath $ScriptName

        if (-not (Test-Path $ScriptPath)) {
            Write-Host "ERROR: Script not found: $ScriptPath" -ForegroundColor Red
            $GlobalResults[$LevelName] = @{
                Passed = $false
                Duration = 0
                Error = "Script not found"
            }
            return $false
        }

        # Build parameter string
        $ParamString = ""
        foreach ($Key in $Params.Keys) {
            $Value = $Params[$Key]
            if ($Value -is [bool]) {
                if ($Value) {
                    $ParamString += " -$Key"
                }
            } else {
                $ParamString += " -$Key $Value"
            }
        }

        # Run the test
        $Output = & $ScriptPath @Params 2>&1
        $ExitCode = $LASTEXITCODE

        if ($Verbose) {
            $Output | ForEach-Object { Write-Host $_ }
        }

        $Duration = ((Get-Date) - $LevelStart).TotalSeconds

        if ($ExitCode -eq 0) {
            $GlobalResults[$LevelName] = @{
                Passed = $true
                Duration = $Duration
            }
            Write-Host ""
            Write-Host "✅ $LevelName PASSED ($([math]::Round($Duration, 1))s)" -ForegroundColor Green
            return $true
        } else {
            $GlobalResults[$LevelName] = @{
                Passed = $false
                Duration = $Duration
                Error = "Exit code: $ExitCode"
            }
            Write-Host ""
            Write-Host "❌ $LevelName FAILED ($([math]::Round($Duration, 1))s)" -ForegroundColor Red
            return $false
        }
    }
    catch {
        $Duration = ((Get-Date) - $LevelStart).TotalSeconds
        $GlobalResults[$LevelName] = @{
            Passed = $false
            Duration = $Duration
            Error = $_.Exception.Message
        }
        Write-Host ""
        Write-Host "❌ $LevelName FAILED: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Show-Summary {
    Write-Host ""
    Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " TEST SUITE SUMMARY" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    $TotalDuration = ((Get-Date) - $StartTime).TotalSeconds
    $TotalTests = $GlobalResults.Count
    $PassedTests = ($GlobalResults.Values | Where-Object { $_.Passed }).Count
    $FailedTests = $TotalTests - $PassedTests

    # Show individual results
    foreach ($TestName in $GlobalResults.Keys | Sort-Object) {
        $Result = $GlobalResults[$TestName]
        $Status = if ($Result.Passed) { "✅ PASS" } else { "❌ FAIL" }
        $Color = if ($Result.Passed) { "Green" } else { "Red" }
        $Duration = [math]::Round($Result.Duration, 1)

        Write-Host "$Status - $TestName ($Duration`s)" -ForegroundColor $Color

        if (-not $Result.Passed -and $Result.Error) {
            Write-Host "      Error: $($Result.Error)" -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Host "Total Tests:    $TotalTests" -ForegroundColor White
    Write-Host "Passed:         $PassedTests" -ForegroundColor Green
    Write-Host "Failed:         $FailedTests" -ForegroundColor Red
    $PassRate = if ($TotalTests -gt 0) { [math]::Round(($PassedTests / $TotalTests) * 100, 1) } else { 0 }
    Write-Host "Pass Rate:      $PassRate%" -ForegroundColor $(if ($PassRate -ge 80) { "Green" } elseif ($PassRate -ge 50) { "Yellow" } else { "Red" })
    Write-Host "Total Duration: $([math]::Round($TotalDuration, 1))s" -ForegroundColor White

    Write-Host ""

    if ($FailedTests -eq 0) {
        Write-Host "🎉 ALL TESTS PASSED! 🎉" -ForegroundColor Green
        Write-Host ""
        Write-Host "Your P2P DHT Network is working perfectly! ✨" -ForegroundColor Cyan
        return $true
    } else {
        Write-Host "⚠️  SOME TESTS FAILED" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please review the failed tests above." -ForegroundColor Yellow
        return $false
    }
}

# Determine which tests to run
$TestsToRun = @()

switch ($Level) {
    "1" {
        $TestsToRun = @("Level 1")
    }
    "2" {
        $TestsToRun = @("Level 2")
    }
    "3" {
        Write-Host "NOTE: Level 3 (Network Testing) requires manual setup across different networks" -ForegroundColor Yellow
        Write-Host "      Skipping automated Level 3 tests" -ForegroundColor Yellow
    }
    "4" {
        $TestsToRun = @("Level 4")
    }
    "5" {
        $TestsToRun = @("Level 5")
    }
    "quick" {
        $TestsToRun = @("Level 1", "Level 2")
    }
    "full" {
        $TestsToRun = @("Level 1", "Level 2", "Level 4", "Level 5")
    }
    "all" {
        $TestsToRun = @("Level 1", "Level 2", "Level 4", "Level 5")
    }
}

if ($TestsToRun.Count -eq 0) {
    Write-Host "No tests to run." -ForegroundColor Yellow
    exit 0
}

Write-Host "Test Plan:" -ForegroundColor Cyan
foreach ($Test in $TestsToRun) {
    Write-Host "  - $Test" -ForegroundColor White
}
Write-Host ""
Write-Host "Estimated time: $($TestsToRun.Count * 3) - $($TestsToRun.Count * 10) minutes" -ForegroundColor Gray
Write-Host ""

$Continue = Read-Host "Continue? (Y/n)"
if ($Continue -eq "n" -or $Continue -eq "N") {
    Write-Host "Tests cancelled." -ForegroundColor Yellow
    exit 0
}

# Run tests
foreach ($Test in $TestsToRun) {
    $Params = @{}
    if ($Verbose) {
        $Params["Verbose"] = $true
    }

    switch ($Test) {
        "Level 1" {
            $Success = Run-TestLevel "Level 1: Quick Start" "test-level1.ps1" $Params
        }
        "Level 2" {
            $Success = Run-TestLevel "Level 2: Feature Testing" "test-level2.ps1" $Params
        }
        "Level 4" {
            $Params["Iterations"] = 5
            $Success = Run-TestLevel "Level 4: Stress Testing" "test-stress.ps1" $Params
        }
        "Level 5" {
            $Params["PeerCount"] = 3
            $Params["Duration"] = 30
            $Success = Run-TestLevel "Level 5: Performance Testing" "test-performance.ps1" $Params
        }
    }

    if (-not $Success -and $StopOnFailure) {
        Write-Host ""
        Write-Host "Stopping tests due to failure (StopOnFailure enabled)" -ForegroundColor Yellow
        break
    }

    # Brief pause between tests
    if ($Test -ne $TestsToRun[-1]) {
        Write-Host ""
        Write-Host "Pausing for 5 seconds before next test..." -ForegroundColor Gray
        Start-Sleep 5
    }
}

# Cleanup
if (-not $SkipCleanup) {
    Write-Host ""
    Write-Host "Cleaning up..." -ForegroundColor Yellow
    $ComposePath = "$ProjectPath/compose.yml"
    docker compose -f $ComposePath down -v 2>&1 | Out-Null
    Get-Job | Stop-Job 2>&1 | Out-Null
    Get-Job | Remove-Job 2>&1 | Out-Null
}

# Show summary
$AllPassed = Show-Summary

# Return exit code
if ($AllPassed) {
    exit 0
} else {
    exit 1
}
