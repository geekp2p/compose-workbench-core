param(
  [Parameter(Mandatory=$true)][string]$Project,
  [switch]$Build
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$composePath = Join-Path $root ("projects\" + $Project + "\compose.yml")

if (!(Test-Path $composePath)) {
  Write-Host "Unknown project: $Project"
  Write-Host "Available projects:"
  Get-ChildItem (Join-Path $root "projects") -Directory | ForEach-Object { " - " + $_.Name }
  exit 1
}

$args = @("-f", $composePath, "-p", $Project, "up", "-d")
if ($Build) { $args += "--build" }

docker compose @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Running: $Project"
Write-Host "Tip: docker compose -f $composePath -p $Project ps"
