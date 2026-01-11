# ============================================================
# help.ps1
# Display help information for multi-compose-lab
# ============================================================

using module .\common.psm1

param(
  [Parameter(Position=0)]
  [ValidateSet("", "start", "stop", "clean", "new", "list", "remove")]
  [string]$Topic = ""
)

function Show-Header {
  Write-Host ""
  Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
  Write-Host "  Multi-Compose Lab - Help & Quick Reference" -ForegroundColor Cyan
  Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
  Write-Host ""
}

function Show-QuickStart {
  Write-Host "Quick Start Guide:" -ForegroundColor Green
  Write-Host ""
  Write-Host "  1. Create a new project:" -ForegroundColor Yellow
  Write-Host "     .\run.ps1 new my-app -Lang node" -ForegroundColor White
  Write-Host ""
  Write-Host "  2. Start your project:" -ForegroundColor Yellow
  Write-Host "     .\up.ps1 my-app -Build" -ForegroundColor White
  Write-Host ""
  Write-Host "  3. Test it:" -ForegroundColor Yellow
  Write-Host "     curl http://localhost:8001" -ForegroundColor White
  Write-Host ""
  Write-Host "  4. Stop your project:" -ForegroundColor Yellow
  Write-Host "     .\down.ps1 my-app" -ForegroundColor White
  Write-Host ""
}

function Show-MainCommands {
  Write-Host "Main Commands:" -ForegroundColor Green
  Write-Host ""

  Write-Host "  Project Management:" -ForegroundColor Cyan
  Write-Host "    .\run.ps1 new <name> -Lang <go|node|python>" -ForegroundColor White
  Write-Host "      Create a new project with specified language"
  Write-Host ""
  Write-Host "    .\run.ps1 list" -ForegroundColor White
  Write-Host "      List all available projects"
  Write-Host ""
  Write-Host "    .\run.ps1 remove <name>" -ForegroundColor White
  Write-Host "      Completely remove a project (Docker + files)"
  Write-Host ""

  Write-Host "  Docker Operations:" -ForegroundColor Cyan
  Write-Host "    .\up.ps1 <project> [-Build]" -ForegroundColor White
  Write-Host "      Start a project (use -Build for first time or after code changes)"
  Write-Host ""
  Write-Host "    .\down.ps1 <project>" -ForegroundColor White
  Write-Host "      Stop a running project"
  Write-Host ""

  Write-Host "  Cleanup:" -ForegroundColor Cyan
  Write-Host "    .\clean.ps1 -Project <name>" -ForegroundColor White
  Write-Host "      Stop and remove containers/network"
  Write-Host ""
  Write-Host "    .\clean.ps1 -Project <name> -Deep" -ForegroundColor White
  Write-Host "      Also remove images and volumes (more thorough)"
  Write-Host ""
  Write-Host "    .\clean.ps1 -All" -ForegroundColor White
  Write-Host "      Clean all unused Docker resources (safe)"
  Write-Host ""
  Write-Host "    .\clean.ps1 -All -Deep" -ForegroundColor White
  Write-Host "      Clean everything including volumes (WARNING: destructive!)"
  Write-Host ""

  Write-Host "  Help:" -ForegroundColor Cyan
  Write-Host "    .\help.ps1" -ForegroundColor White
  Write-Host "      Show this help message"
  Write-Host ""
  Write-Host "    .\help.ps1 <topic>" -ForegroundColor White
  Write-Host "      Show detailed help for: start, stop, clean, new, list, remove"
  Write-Host ""
}

function Show-Examples {
  Write-Host "Common Examples:" -ForegroundColor Green
  Write-Host ""

  Write-Host "  Create & run a Node.js project:" -ForegroundColor Yellow
  Write-Host "    .\run.ps1 new my-api -Lang node" -ForegroundColor White
  Write-Host "    .\up.ps1 my-api -Build" -ForegroundColor White
  Write-Host ""

  Write-Host "  Create a Go project on custom port:" -ForegroundColor Yellow
  Write-Host "    .\run.ps1 new go-service -Lang go -Port 9000" -ForegroundColor White
  Write-Host "    .\up.ps1 go-service -Build" -ForegroundColor White
  Write-Host ""

  Write-Host "  Create a Python project:" -ForegroundColor Yellow
  Write-Host "    .\run.ps1 new py-app -Lang python" -ForegroundColor White
  Write-Host "    .\up.ps1 py-app -Build" -ForegroundColor White
  Write-Host ""

  Write-Host "  View all projects:" -ForegroundColor Yellow
  Write-Host "    .\run.ps1 list" -ForegroundColor White
  Write-Host ""

  Write-Host "  Stop a project:" -ForegroundColor Yellow
  Write-Host "    .\down.ps1 my-api" -ForegroundColor White
  Write-Host ""

  Write-Host "  Clean up after testing:" -ForegroundColor Yellow
  Write-Host "    .\clean.ps1 -Project my-api -Deep" -ForegroundColor White
  Write-Host ""

  Write-Host "  Completely remove a project:" -ForegroundColor Yellow
  Write-Host "    .\run.ps1 remove my-api" -ForegroundColor White
  Write-Host ""

  Write-Host "  Free up disk space:" -ForegroundColor Yellow
  Write-Host "    .\clean.ps1 -All -Deep -Force" -ForegroundColor White
  Write-Host ""
}

function Show-AvailableProjects {
  $root = Get-ScriptRoot
  $projectsDir = Join-Path $root "projects"

  if (!(Test-Path $projectsDir)) {
    Write-Host "No projects directory found." -ForegroundColor Yellow
    return
  }

  $projects = Get-ChildItem $projectsDir -Directory

  if ($projects.Count -eq 0) {
    Write-Host "No projects found. Create one with:" -ForegroundColor Yellow
    Write-Host "  .\run.ps1 new <name> -Lang <go|node|python>" -ForegroundColor White
    return
  }

  Write-Host "Available Projects:" -ForegroundColor Green
  Write-Host ""
  Write-Host ("  {0,-20} {1,-10} {2}" -f "Name", "Language", "Port") -ForegroundColor Cyan
  Write-Host ("  {0,-20} {1,-10} {2}" -f "----", "--------", "----") -ForegroundColor DarkGray

  foreach ($proj in $projects) {
    $composePath = Join-Path $proj.FullName "compose.yml"
    if (Test-Path $composePath) {
      $content = Get-Content $composePath -Raw

      # Extract port
      $port = "?"
      if ($content -match '\$\{HOST_PORT:-(\d+)\}') {
        $port = $Matches[1]
      }

      # Detect language
      $lang = "?"
      if (Test-Path (Join-Path $proj.FullName "go.mod")) { $lang = "go" }
      elseif (Test-Path (Join-Path $proj.FullName "package.json")) { $lang = "node" }
      elseif (Test-Path (Join-Path $proj.FullName "requirements.txt")) { $lang = "python" }

      Write-Host ("  {0,-20} {1,-10} {2}" -f $proj.Name, $lang, $port) -ForegroundColor White
    }
  }
  Write-Host ""
}

function Show-TopicHelp {
  param([string]$Topic)

  Write-Host ""
  switch ($Topic) {
    "start" {
      Write-Host "Starting Projects (up.ps1):" -ForegroundColor Green
      Write-Host ""
      Write-Host "  Usage:" -ForegroundColor Cyan
      Write-Host "    .\up.ps1 <project-name> [-Build]" -ForegroundColor White
      Write-Host ""
      Write-Host "  Parameters:" -ForegroundColor Cyan
      Write-Host "    -Build      Build/rebuild the Docker image before starting" -ForegroundColor White
      Write-Host ""
      Write-Host "  Examples:" -ForegroundColor Cyan
      Write-Host "    .\up.ps1 my-app -Build    # First time or after code changes" -ForegroundColor White
      Write-Host "    .\up.ps1 my-app           # Start existing container" -ForegroundColor White
      Write-Host ""
      Write-Host "  After starting, access your app at:" -ForegroundColor Yellow
      Write-Host "    http://localhost:<port>   # Port shown in .\run.ps1 list" -ForegroundColor White
      Write-Host ""
    }

    "stop" {
      Write-Host "Stopping Projects (down.ps1):" -ForegroundColor Green
      Write-Host ""
      Write-Host "  Usage:" -ForegroundColor Cyan
      Write-Host "    .\down.ps1 <project-name>" -ForegroundColor White
      Write-Host ""
      Write-Host "  What it does:" -ForegroundColor Cyan
      Write-Host "    - Stops running containers" -ForegroundColor White
      Write-Host "    - Removes containers" -ForegroundColor White
      Write-Host "    - Keeps images and volumes (for quick restart)" -ForegroundColor White
      Write-Host ""
      Write-Host "  Examples:" -ForegroundColor Cyan
      Write-Host "    .\down.ps1 my-app" -ForegroundColor White
      Write-Host "    .\down.ps1 go-service" -ForegroundColor White
      Write-Host ""
    }

    "clean" {
      Write-Host "Cleaning Up (clean.ps1):" -ForegroundColor Green
      Write-Host ""
      Write-Host "  Project Cleanup:" -ForegroundColor Cyan
      Write-Host "    .\clean.ps1 -Project <name>               # Basic cleanup" -ForegroundColor White
      Write-Host "    .\clean.ps1 -Project <name> -Deep         # Remove images & volumes" -ForegroundColor White
      Write-Host "    .\clean.ps1 -Project <name> -Deep -Force  # No confirmation prompt" -ForegroundColor White
      Write-Host ""
      Write-Host "  Global Cleanup:" -ForegroundColor Cyan
      Write-Host "    .\clean.ps1 -All               # Clean unused resources" -ForegroundColor White
      Write-Host "    .\clean.ps1 -All -Deep         # Also remove unused volumes" -ForegroundColor White
      Write-Host "    .\clean.ps1 -All -Deep -Force  # No confirmation" -ForegroundColor White
      Write-Host ""
      Write-Host "  WARNING:" -ForegroundColor Yellow
      Write-Host "    -Deep will remove volumes containing database data!" -ForegroundColor Red
      Write-Host "    Use -Force carefully in scripts/automation" -ForegroundColor Red
      Write-Host ""
      Write-Host "  Disk Space:" -ForegroundColor Cyan
      Write-Host "    Build cache usually takes the most space." -ForegroundColor White
      Write-Host "    Use -Deep to clean it and free significant disk space." -ForegroundColor White
      Write-Host ""
    }

    "new" {
      Write-Host "Creating New Projects (run.ps1 new):" -ForegroundColor Green
      Write-Host ""
      Write-Host "  Usage:" -ForegroundColor Cyan
      Write-Host "    .\run.ps1 new <project-name> -Lang <go|node|python> [-Port <port>]" -ForegroundColor White
      Write-Host ""
      Write-Host "  Parameters:" -ForegroundColor Cyan
      Write-Host "    -Lang       Language: go, node, or python (required)" -ForegroundColor White
      Write-Host "    -Port       Host port (optional, auto-assigned if not specified)" -ForegroundColor White
      Write-Host ""
      Write-Host "  Project name rules:" -ForegroundColor Cyan
      Write-Host "    - Lowercase letters, numbers, and hyphens only" -ForegroundColor White
      Write-Host "    - No spaces or special characters" -ForegroundColor White
      Write-Host ""
      Write-Host "  Examples:" -ForegroundColor Cyan
      Write-Host "    .\run.ps1 new my-api -Lang node           # Auto port (8001+)" -ForegroundColor White
      Write-Host "    .\run.ps1 new go-service -Lang go -Port 9000" -ForegroundColor White
      Write-Host "    .\run.ps1 new py-app -Lang python         # Auto port" -ForegroundColor White
      Write-Host ""
      Write-Host "  What gets created:" -ForegroundColor Cyan
      Write-Host "    - Project folder in ./projects/<name>/" -ForegroundColor White
      Write-Host "    - Dockerfile with optimized build" -ForegroundColor White
      Write-Host "    - compose.yml with port mapping" -ForegroundColor White
      Write-Host "    - Sample application code" -ForegroundColor White
      Write-Host ""
    }

    "list" {
      Write-Host "Listing Projects (run.ps1 list):" -ForegroundColor Green
      Write-Host ""
      Write-Host "  Usage:" -ForegroundColor Cyan
      Write-Host "    .\run.ps1 list" -ForegroundColor White
      Write-Host ""
      Write-Host "  Shows:" -ForegroundColor Cyan
      Write-Host "    - Project name" -ForegroundColor White
      Write-Host "    - Programming language" -ForegroundColor White
      Write-Host "    - Mapped host port" -ForegroundColor White
      Write-Host ""
      Write-Host "  Example output:" -ForegroundColor Cyan
      Write-Host "    my-api        [node]     port 8001" -ForegroundColor DarkGray
      Write-Host "    go-service    [go]       port 9000" -ForegroundColor DarkGray
      Write-Host "    py-app        [python]   port 8002" -ForegroundColor DarkGray
      Write-Host ""
    }

    "remove" {
      Write-Host "Removing Projects (run.ps1 remove):" -ForegroundColor Green
      Write-Host ""
      Write-Host "  Usage:" -ForegroundColor Cyan
      Write-Host "    .\run.ps1 remove <project-name> [-Force]" -ForegroundColor White
      Write-Host ""
      Write-Host "  What it does:" -ForegroundColor Cyan
      Write-Host "    1. Stops and removes containers" -ForegroundColor White
      Write-Host "    2. Removes Docker images and volumes" -ForegroundColor White
      Write-Host "    3. Cleans build cache" -ForegroundColor White
      Write-Host "    4. DELETES the project folder" -ForegroundColor Yellow
      Write-Host ""
      Write-Host "  Parameters:" -ForegroundColor Cyan
      Write-Host "    -Force      Skip confirmation prompts" -ForegroundColor White
      Write-Host ""
      Write-Host "  Examples:" -ForegroundColor Cyan
      Write-Host "    .\run.ps1 remove my-api          # With confirmation" -ForegroundColor White
      Write-Host "    .\run.ps1 remove my-api -Force   # No confirmation" -ForegroundColor White
      Write-Host ""
      Write-Host "  WARNING:" -ForegroundColor Yellow
      Write-Host "    This is PERMANENT! The project folder will be deleted." -ForegroundColor Red
      Write-Host "    Make sure to backup any important code first." -ForegroundColor Red
      Write-Host ""
    }
  }
}

function Show-Tips {
  Write-Host "Helpful Tips:" -ForegroundColor Green
  Write-Host ""

  Write-Host "  View logs:" -ForegroundColor Yellow
  Write-Host "    docker compose -f projects/<name>/compose.yml -p <name> logs -f" -ForegroundColor White
  Write-Host ""

  Write-Host "  Check running containers:" -ForegroundColor Yellow
  Write-Host "    docker compose -f projects/<name>/compose.yml -p <name> ps" -ForegroundColor White
  Write-Host ""

  Write-Host "  Test your service:" -ForegroundColor Yellow
  Write-Host "    curl http://localhost:<port>" -ForegroundColor White
  Write-Host "    # or open in browser" -ForegroundColor DarkGray
  Write-Host ""

  Write-Host "  Check disk usage:" -ForegroundColor Yellow
  Write-Host "    docker system df" -ForegroundColor White
  Write-Host ""

  Write-Host "  PowerShell vs CMD:" -ForegroundColor Yellow
  Write-Host "    PowerShell: .\help.ps1, .\up.ps1, etc." -ForegroundColor White
  Write-Host "    CMD:        help, up <project>, etc." -ForegroundColor White
  Write-Host ""
}

function Show-Footer {
  Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "  For more help on a specific topic:" -ForegroundColor DarkGray
  Write-Host "    .\help.ps1 <topic>  (start|stop|clean|new|list|remove)" -ForegroundColor DarkGray
  Write-Host ""
  Write-Host "  Project repository: multi-compose-lab" -ForegroundColor DarkGray
  Write-Host ""
}

# ============================================================
# Main
# ============================================================

if ($Topic) {
  Show-Header
  Show-TopicHelp -Topic $Topic
} else {
  Show-Header
  Show-QuickStart
  Write-Host ""
  Show-AvailableProjects
  Write-Host ""
  Show-MainCommands
  Show-Examples
  Show-Tips
  Show-Footer
}
