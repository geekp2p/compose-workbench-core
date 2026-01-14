# test-peers.ps1
# Helper script to manage multiple peers for testing

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("start", "stop", "status", "attach", "logs", "cleanup")]
    [string]$Action = "status",

    [int]$Count = 3,
    [int]$PeerId,
    [switch]$Follow
)

$ErrorActionPreference = "Stop"

$ProjectPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ComposePath = "$ProjectPath/compose.yml"
$ProjectName = "p2p-chat-go"

function Get-PeerContainers {
    return docker ps -a --filter "name=chat-node" --format "{{.Names}}" | Sort-Object
}

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

# Main actions
switch ($Action) {
    "start" {
        Write-Header "STARTING $Count PEERS"

        # Start first peer with compose
        Write-Host "Starting Peer 1..." -ForegroundColor Yellow
        $RootPath = Split-Path -Parent (Split-Path -Parent $ProjectPath)
        Set-Location $RootPath
        & "$RootPath\up.ps1" -Project $ProjectName -Build
        Start-Sleep 5

        # Start additional peers
        for ($i = 2; $i -le $Count; $i++) {
            Write-Host "Starting Peer $i..." -ForegroundColor Yellow

            Start-Job -Name "peer-$i" -ScriptBlock {
                param($ComposePath)
                docker compose -f $ComposePath run --rm chat-node
            } -ArgumentList $ComposePath | Out-Null

            Start-Sleep 3
        }

        Write-Host ""
        Write-Host "Waiting for all peers to start (15 seconds)..." -ForegroundColor Yellow
        Start-Sleep 15

        Write-Host ""
        Write-Host "Peers started successfully! ✅" -ForegroundColor Green
        Write-Host ""

        # Show status
        & $MyInvocation.MyCommand.Path -Action status
    }

    "stop" {
        Write-Header "STOPPING ALL PEERS"

        $Containers = Get-PeerContainers
        if ($Containers) {
            foreach ($Container in $Containers) {
                Write-Host "Stopping $Container..." -ForegroundColor Yellow
                docker stop $Container 2>&1 | Out-Null
            }
            Write-Host "All peers stopped. ✅" -ForegroundColor Green
        } else {
            Write-Host "No running peers found." -ForegroundColor Yellow
        }

        # Stop background jobs
        Get-Job | Where-Object { $_.Name -like "peer-*" } | Stop-Job
        Get-Job | Where-Object { $_.Name -like "peer-*" } | Remove-Job
    }

    "status" {
        Write-Header "PEER STATUS"

        $Containers = Get-PeerContainers
        if (-not $Containers) {
            Write-Host "No peers running." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "To start peers:" -ForegroundColor Cyan
            Write-Host "  .\test-peers.ps1 -Action start -Count 3" -ForegroundColor White
            return
        }

        Write-Host "Running Peers: $($Containers.Count)" -ForegroundColor Green
        Write-Host ""

        # Get container details
        docker ps --filter "name=chat-node" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

        Write-Host ""
        Write-Host "To attach to a peer:" -ForegroundColor Cyan
        Write-Host "  .\test-peers.ps1 -Action attach -PeerId 1" -ForegroundColor White
        Write-Host ""
        Write-Host "To view logs:" -ForegroundColor Cyan
        Write-Host "  .\test-peers.ps1 -Action logs -PeerId 1" -ForegroundColor White
    }

    "attach" {
        if (-not $PeerId) {
            Write-Host "ERROR: PeerId required" -ForegroundColor Red
            Write-Host "Usage: .\test-peers.ps1 -Action attach -PeerId 1" -ForegroundColor Yellow
            exit 1
        }

        $Containers = Get-PeerContainers
        if ($PeerId -lt 1 -or $PeerId -gt $Containers.Count) {
            Write-Host "ERROR: Invalid PeerId. Available: 1-$($Containers.Count)" -ForegroundColor Red
            exit 1
        }

        $Container = $Containers[$PeerId - 1]
        Write-Host "Attaching to Peer $PeerId ($Container)..." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Detach: Press Ctrl+P, Ctrl+Q" -ForegroundColor Gray
        Write-Host "Exit:   Type /quit" -ForegroundColor Gray
        Write-Host ""
        Start-Sleep 2

        docker attach $Container
    }

    "logs" {
        if (-not $PeerId) {
            Write-Host "ERROR: PeerId required" -ForegroundColor Red
            Write-Host "Usage: .\test-peers.ps1 -Action logs -PeerId 1 [-Follow]" -ForegroundColor Yellow
            exit 1
        }

        $Containers = Get-PeerContainers
        if ($PeerId -lt 1 -or $PeerId -gt $Containers.Count) {
            Write-Host "ERROR: Invalid PeerId. Available: 1-$($Containers.Count)" -ForegroundColor Red
            exit 1
        }

        $Container = $Containers[$PeerId - 1]
        Write-Host "Logs for Peer $PeerId ($Container):" -ForegroundColor Yellow
        Write-Host ""

        if ($Follow) {
            docker logs -f $Container
        } else {
            docker logs --tail 50 $Container
        }
    }

    "cleanup" {
        Write-Header "CLEANUP"

        Write-Host "Stopping all peers..." -ForegroundColor Yellow
        & $MyInvocation.MyCommand.Path -Action stop

        Write-Host ""
        Write-Host "Removing containers and volumes..." -ForegroundColor Yellow
        docker compose -f $ComposePath down -v 2>&1 | Out-Null

        Write-Host ""
        Write-Host "Cleanup complete! ✅" -ForegroundColor Green
    }
}
