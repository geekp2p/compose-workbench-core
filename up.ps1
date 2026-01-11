using module .\common.psm1

param(
  [Parameter(Mandatory=$true)][string]$Project,
  [string[]]$Services,      # Array of specific service names to start
  [string[]]$Profiles,      # Array of profile names to activate
  [switch]$Build
)

$root = Get-ScriptRoot

if (!(Test-ProjectExists -Root $root -Project $Project -ShowError)) {
  exit 1
}

$composePath = Get-ProjectComposePath -Root $root -Project $Project

$args = @("-f", $composePath, "-p", $Project)

# Add profiles if specified
if ($Profiles) {
  foreach ($profile in $Profiles) {
    $args += "--profile"
    $args += $profile
  }
}

$args += "up", "-d"
if ($Build) { $args += "--build" }

# Add specific services if specified
if ($Services) {
  $args += $Services
}

docker compose @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
if ($Services) {
  Write-Host "Running services: $($Services -join ', ') in project: $Project"
} elseif ($Profiles) {
  Write-Host "Running profiles: $($Profiles -join ', ') in project: $Project"
} else {
  Write-Host "Running: $Project"
}
Write-Host "Tip: docker compose -f $composePath -p $Project ps"
