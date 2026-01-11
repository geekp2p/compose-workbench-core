using module .\common.psm1

param(
  [Parameter(Mandatory=$true)][string]$Project,
  [string[]]$Services      # Array of specific service names to stop
)

$root = Get-ScriptRoot

if (!(Test-ProjectExists -Root $root -Project $Project -ShowError)) {
  exit 1
}

$composePath = Get-ProjectComposePath -Root $root -Project $Project

if ($Services) {
  # Stop and remove specific services
  Write-Host "Stopping services: $($Services -join ', ') in project: $Project"
  docker compose -f $composePath -p $Project stop $Services
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  docker compose -f $composePath -p $Project rm -f $Services
  exit $LASTEXITCODE
} else {
  # Stop and remove entire project
  docker compose -f $composePath -p $Project down
  exit $LASTEXITCODE
}
