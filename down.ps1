using module .\common.psm1

param(
  [Parameter(Mandatory=$true)][string]$Project
)

$root = Get-ScriptRoot

if (!(Test-ProjectExists -Root $root -Project $Project -ShowError)) {
  exit 1
}

$composePath = Get-ProjectComposePath -Root $root -Project $Project

docker compose -f $composePath -p $Project down
exit $LASTEXITCODE
