using module .\common.psm1

param(
  [Parameter(Mandatory=$true)][string]$Project,
  [switch]$Build
)

$root = Get-ScriptRoot

if (!(Test-ProjectExists -Root $root -Project $Project -ShowError)) {
  exit 1
}

$composePath = Get-ProjectComposePath -Root $root -Project $Project

$args = @("-f", $composePath, "-p", $Project, "up", "-d")
if ($Build) { $args += "--build" }

docker compose @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Running: $Project"
Write-Host "Tip: docker compose -f $composePath -p $Project ps"
