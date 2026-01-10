using module .\common.psm1

param(
  [string]$Project = "",
  [switch]$Deep,
  [switch]$All,
  [switch]$Force,
  [switch]$RemoveProject
)

# ============================================================
# clean.ps1
# - Project cleanup: docker compose down (+ optional remove images/volumes)
# - Global cleanup: docker system prune (+ optional volumes) + builder prune
#
# Notes:
# - Your "disk hog" is usually Build Cache, so builder prune is included.
# - -Deep is destructive for volumes; use with caution for DBs.
# ============================================================

function Confirm-OrExit([string]$Message) {
  if ($Force) { return }
  $ans = Read-Host "$Message (y/N)"
  if ($ans.ToLower() -ne "y") {
    Write-Host "Cancelled."
    exit 0
  }
}

$root = Get-ScriptRoot

# Validate parameters
if ($All -and $Project) {
  Write-Host "Use either -All or -Project, not both."
  exit 1
}

if (-not $All -and [string]::IsNullOrWhiteSpace($Project)) {
  Write-Host "Usage:"
  Write-Host "  .\clean.ps1 -Project go-hello                        # stop/remove containers+network"
  Write-Host "  .\clean.ps1 -Project go-hello -Deep                  # + remove local images + volumes"
  Write-Host "  .\clean.ps1 -Project go-hello -Deep -RemoveProject   # + delete project folder"
  Write-Host "  .\clean.ps1 -All                                     # prune unused (safe-ish)"
  Write-Host "  .\clean.ps1 -All -Deep                               # + prune volumes (destructive)"
  Write-Host "  .\clean.ps1 -All -Force                              # no prompt"
  Write-Host "  .\clean.ps1 -Project go-hello -Deep -Force           # no prompt"
  exit 1
}

# Validate -RemoveProject usage
if ($RemoveProject) {
  if ($All) {
    Write-Host "Error: -RemoveProject can only be used with -Project, not -All."
    exit 1
  }
  if ([string]::IsNullOrWhiteSpace($Project)) {
    Write-Host "Error: -RemoveProject requires -Project to be specified."
    exit 1
  }
  # Force -Deep when removing project
  if (-not $Deep) {
    Write-Host "Note: -RemoveProject implies -Deep (cleaning all Docker resources first)."
    $Deep = $true
  }
}

# ------------------------------------------------------------
# Per-project cleanup
# ------------------------------------------------------------
if (-not [string]::IsNullOrWhiteSpace($Project)) {

  if (!(Test-ProjectExists -Root $root -Project $Project -ShowError)) {
    exit 1
  }

  $composePath = Get-ProjectComposePath -Root $root -Project $Project

  if ($Deep) {
    Confirm-OrExit "This will remove containers/network AND local images+volumes for project '$Project'. Continue?"
    docker compose -f $composePath -p $Project down --remove-orphans --rmi local --volumes
  } else {
    docker compose -f $composePath -p $Project down --remove-orphans
  }

  # Check if Docker commands failed
  $dockerFailed = ($LASTEXITCODE -ne 0)

  if ($dockerFailed) {
    if ($RemoveProject) {
      # When removing project, warn but continue to folder deletion
      Write-Host ""
      Write-Host "Warning: Docker cleanup failed (is Docker running?)" -ForegroundColor Yellow
      Write-Host "Continuing with project folder removal..." -ForegroundColor Yellow
      Write-Host ""
    } else {
      # For regular cleanup, fail if Docker commands fail
      exit $LASTEXITCODE
    }
  }

  # Build cache is typically the biggest part: optionally clean it after project deep clean
  if ($Deep -and -not $dockerFailed) {
    Confirm-OrExit "Also prune Docker build cache (recommended; frees the most space)?"
    docker builder prune -af
  }

  # Remove project folder if requested
  if ($RemoveProject) {
    $projectPath = Join-Path $root "projects" $Project
    Confirm-OrExit "DELETE project folder at $projectPath ?"

    Write-Host "Removing project folder: $projectPath"
    Remove-Item -Path $projectPath -Recurse -Force

    if (Test-Path $projectPath) {
      Write-Host "Error: Failed to remove project folder." -ForegroundColor Red
      exit 1
    }

    Write-Host ""
    Write-Host "Project completely removed: $Project" -ForegroundColor Green
    if ($dockerFailed) {
      Write-Host "  - Docker resources: skipped (Docker not available)"
    } else {
      Write-Host "  - Docker resources: cleaned"
    }
    Write-Host "  - Project folder: deleted"
  } else {
    Write-Host ""
    Write-Host "Project cleanup done: $Project"
  }

  if (-not $dockerFailed) {
    Write-Host ""
    Write-Host "Disk usage summary:"
    docker system df
  }
  exit 0
}

# ------------------------------------------------------------
# Global cleanup
# ------------------------------------------------------------
if ($All) {

  if ($Deep) {
    Confirm-OrExit "GLOBAL DEEP CLEAN will remove: stopped containers, unused images, unused networks, build cache, AND UNUSED VOLUMES. Continue?"
    docker system prune -af --volumes
    # build cache may still exist in some cases; prune explicitly
    docker builder prune -af
  } else {
    Confirm-OrExit "Global clean will remove: stopped containers, unused images, unused networks, build cache. Continue?"
    docker system prune -af
    docker builder prune -af
  }

  Write-Host ""
  Write-Host "Global cleanup done."
  Write-Host "Disk usage summary:"
  docker system df
  exit 0
}

# Should not reach here
exit 1
