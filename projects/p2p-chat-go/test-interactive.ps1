# ============================================
# P2P Chat - Interactive Testing Helper
# ============================================
# Simplified tool for manual testing

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("start", "attach", "status", "logs", "stop", "clean", "help")]
    [string]$Action = "help",

    [Parameter(Mandatory=$false)]
    [int]$PeerCount = 3,

    [Parameter(Mandatory=$false)]
    [int]$PeerId
)

$ProjectPath = "projects/p2p-chat-go"
$ComposeFile = "$ProjectPath/compose.yml"

# Colors
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error { Write-Host $args -ForegroundColor Red }
function Write-Header {
    Write-Host ""
    Write-Host $args -ForegroundColor Magenta
    Write-Host ("=" * 50) -ForegroundColor Magenta
}

# Main menu
function Show-Help {
    Write-Header "P2P Chat - Interactive Testing Helper"

    Write-Info "Usage: .\test-interactive.ps1 -Action <action> [options]"
    Write-Info ""
    Write-Info "Actions:"
    Write-Info "  start      Start multiple peers for testing"
    Write-Info "  attach     Attach to a running peer"
    Write-Info "  status     Show status of all peers"
    Write-Info "  logs       Show logs from all peers"
    Write-Info "  stop       Stop all peers"
    Write-Info "  clean      Stop and remove all containers/volumes"
    Write-Info "  help       Show this help message"
    Write-Info ""
    Write-Info "Options:"
    Write-Info "  -PeerCount <n>   Number of peers to start (default: 3)"
    Write-Info "  -PeerId <n>      Specific peer ID for attach action"
    Write-Info ""
    Write-Info "Examples:"
    Write-Info "  .\test-interactive.ps1 -Action start -PeerCount 3"
    Write-Info "  .\test-interactive.ps1 -Action attach -PeerId 1"
    Write-Info "  .\test-interactive.ps1 -Action status"
    Write-Info "  .\test-interactive.ps1 -Action clean"
    Write-Info ""
}

# Start peers
function Start-Peers {
    Write-Header "Starting $PeerCount Peers"

    try {
        Write-Info "Building image..."
        docker compose -f $ComposeFile build --quiet
        Write-Success "✓ Build complete"

        Write-Info "Starting peer 1..."
        docker compose -f $ComposeFile up -d
        Write-Success "✓ Peer 1 started"
        Start-Sleep 5

        if ($PeerCount -gt 1) {
            for ($i = 2; $i -le $PeerCount; $i++) {
                Write-Info "Starting peer $i..."
                docker compose -f $ComposeFile run -d chat-node
                Write-Success "✓ Peer $i started"
                Start-Sleep 3
            }
        }

        Write-Success ""
        Write-Success "✓ All $PeerCount peers started!"
        Write-Info ""
        Write-Info "Waiting 30 seconds for peer discovery..."

        for ($i = 1; $i -le 30; $i++) {
            Write-Progress -Activity "Peer Discovery" -Status "Waiting... ($i/30s)" -PercentComplete (($i/30)*100)
            Start-Sleep 1
        }
        Write-Progress -Activity "Peer Discovery" -Completed

        Write-Info ""
        Show-Status

        Write-Info ""
        Write-Success "Ready to test!"
        Write-Info "Use: .\test-interactive.ps1 -Action attach -PeerId 1"
        Write-Info ""

    } catch {
        Write-Error "Failed to start peers: $_"
    }
}

# Show status
function Show-Status {
    Write-Header "Peer Status"

    $containers = docker compose -f $ComposeFile ps -q
    $containerArray = $containers -split "`n" | Where-Object { $_ -ne "" }

    if ($containerArray.Count -eq 0) {
        Write-Warning "No peers running"
        return
    }

    Write-Info "Running peers: $($containerArray.Count)"
    Write-Info ""

    $peerNum = 1
    foreach ($containerId in $containerArray) {
        $shortId = $containerId.Substring(0, 12)
        $status = docker inspect --format='{{.State.Status}}' $containerId

        Write-Info "Peer #${peerNum} (${shortId}):"
        Write-Info "  Status: $status"

        # Try to extract peer ID from logs
        $logs = docker logs --tail 100 $containerId 2>&1
        if ($logs -match "Peer ID: (12D3KooW[a-zA-Z0-9]+)") {
            $peerId = $matches[1]
            Write-Info "  Peer ID: $($peerId.Substring(0,20))..."
        }

        # Check for mesh peers
        if ($logs -match "mesh ready with (\d+) peer") {
            Write-Success "  Mesh peers: $($matches[1])"
        } elseif ($logs -match "Connected peers: (\d+)") {
            Write-Success "  Connected peers: $($matches[1])"
        } else {
            Write-Warning "  Mesh peers: Unknown (still discovering...)"
        }

        Write-Info ""
        $peerNum++
    }

    Write-Info "To attach to a peer: .\test-interactive.ps1 -Action attach -PeerId <number>"
}

# Attach to peer
function Attach-ToPeer {
    Write-Header "Attach to Peer"

    $containers = docker compose -f $ComposeFile ps -q
    $containerArray = $containers -split "`n" | Where-Object { $_ -ne "" }

    if ($containerArray.Count -eq 0) {
        Write-Error "No peers running. Start peers first:"
        Write-Info "  .\test-interactive.ps1 -Action start"
        return
    }

    if ($PeerId) {
        if ($PeerId -le $containerArray.Count) {
            $containerId = $containerArray[$PeerId - 1]
        } else {
            Write-Error "Peer #$PeerId not found. Available: 1-$($containerArray.Count)"
            return
        }
    } else {
        # Show menu
        Write-Info "Available peers:"
        for ($i = 1; $i -le $containerArray.Count; $i++) {
            $shortId = $containerArray[$i-1].Substring(0, 12)
            Write-Info "  $i. Peer #$i ($shortId)"
        }
        Write-Info ""
        $selection = Read-Host "Select peer number (1-$($containerArray.Count))"

        if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $containerArray.Count) {
            $containerId = $containerArray[[int]$selection - 1]
        } else {
            Write-Error "Invalid selection"
            return
        }
    }

    Write-Info ""
    Write-Info "Attaching to container: $($containerId.Substring(0,12))"
    Write-Info ""
    Write-Success "🔌 Connected! Try these commands:"
    Write-Info "  /peers    - Show connected peers"
    Write-Info "  /routing  - Show routing info"
    Write-Info "  /relay    - Show relay status"
    Write-Info "  /dht      - Show DHT storage"
    Write-Info "  /conn     - Show connection types"
    Write-Info "  /mesh     - Show mesh status"
    Write-Info "  /help     - Show all commands"
    Write-Info ""
    Write-Warning "To detach without stopping: Ctrl+P, then Ctrl+Q"
    Write-Info ""
    Start-Sleep 3

    docker attach $containerId
}

# Show logs
function Show-Logs {
    Write-Header "Peer Logs"

    $containers = docker compose -f $ComposeFile ps -q
    $containerArray = $containers -split "`n" | Where-Object { $_ -ne "" }

    if ($containerArray.Count -eq 0) {
        Write-Warning "No peers running"
        return
    }

    Write-Info "Showing logs from all $($containerArray.Count) peers..."
    Write-Info "(Press Ctrl+C to stop)"
    Write-Info ""

    docker compose -f $ComposeFile logs -f
}

# Stop peers
function Stop-Peers {
    Write-Header "Stopping All Peers"

    try {
        docker compose -f $ComposeFile down
        Write-Success "✓ All peers stopped"
    } catch {
        Write-Error "Failed to stop peers: $_"
    }
}

# Clean everything
function Clean-All {
    Write-Header "Cleaning Up"

    Write-Warning "This will remove:"
    Write-Warning "  - All containers"
    Write-Warning "  - All volumes (message history will be lost)"
    Write-Warning "  - Networks"
    Write-Info ""

    $confirm = Read-Host "Continue? (yes/no)"

    if ($confirm -eq "yes") {
        try {
            docker compose -f $ComposeFile down -v
            Write-Success "✓ Cleanup complete"
        } catch {
            Write-Error "Failed to clean: $_"
        }
    } else {
        Write-Info "Cancelled"
    }
}

# Main
switch ($Action) {
    "start"  { Start-Peers }
    "attach" { Attach-ToPeer }
    "status" { Show-Status }
    "logs"   { Show-Logs }
    "stop"   { Stop-Peers }
    "clean"  { Clean-All }
    "help"   { Show-Help }
    default  { Show-Help }
}
