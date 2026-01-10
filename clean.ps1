using module .\common.psm1

param(
  [string]$Project = "",
  [switch]$Deep,
  [switch]$All,
  [switch]$Force
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
  Write-Host "  .\clean.ps1 -Project go-hello                  # stop/remove containers+network"
  Write-Host "  .\clean.ps1 -Project go-hello -Deep            # + remove local images + volumes"
  Write-Host "  .\clean.ps1 -All                               # prune unused (safe-ish)"
  Write-Host "  .\clean.ps1 -All -Deep                         # + prune volumes (destructive)"
  Write-Host "  .\clean.ps1 -All -Force                        # no prompt"
  Write-Host "  .\clean.ps1 -Project go-hello -Deep -Force     # no prompt"
  exit 1
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

  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  # Build cache is typically the biggest part: optionally clean it after project deep clean
  if ($Deep) {
    Confirm-OrExit "Also prune Docker build cache (recommended; frees the most space)?"
    docker builder prune -af
  }

  Write-Host ""
  Write-Host "Project cleanup done: $Project"
  Write-Host "Disk usage summary:"
  docker system df
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
