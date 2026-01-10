param(
  [Parameter(Mandatory=$true)][string]$Project
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$composePath = Join-Path $root ("projects\" + $Project + "\compose.yml")

if (!(Test-Path $composePath)) {
  Write-Host "Unknown project: $Project"
  exit 1
}

docker compose -f $composePath -p $Project down
exit $LASTEXITCODE
