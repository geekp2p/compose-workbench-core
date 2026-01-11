using module .\common.psm1

<#
.SYNOPSIS
Manage individual services within a project.

.DESCRIPTION
Start, stop, restart, or view logs for specific services in a Docker Compose project.

.PARAMETER Action
The action to perform: start, stop, restart, logs

.PARAMETER Project
The project name.

.PARAMETER Services
Array of service names to operate on.

.PARAMETER Follow
When using 'logs' action, follow log output (like tail -f).

.PARAMETER Build
When using 'start' action, rebuild images before starting.

.EXAMPLE
.\service.ps1 start web-stack db,api
Start db and api services in web-stack project

.EXAMPLE
.\service.ps1 logs web-stack api -Follow
Follow logs for api service

.EXAMPLE
.\service.ps1 restart web-stack web
Restart web service
#>

param(
  [Parameter(Mandatory=$true)]
  [ValidateSet("start", "stop", "restart", "logs", "ps", "exec")]
  [string]$Action,

  [Parameter(Mandatory=$true)][string]$Project,
  [Parameter(Mandatory=$true)][string[]]$Services,

  [switch]$Follow,      # For logs action
  [switch]$Build,       # For start action
  [string]$Command      # For exec action
)

$root = Get-ScriptRoot

if (!(Test-ProjectExists -Root $root -Project $Project -ShowError)) {
  exit 1
}

$composePath = Get-ProjectComposePath -Root $root -Project $Project

switch ($Action) {
  "start" {
    $args = @("-f", $composePath, "-p", $Project, "up", "-d")
    if ($Build) { $args += "--build" }
    $args += $Services

    Write-Host "Starting services: $($Services -join ', ') in project: $Project"
    docker compose @args
  }

  "stop" {
    Write-Host "Stopping services: $($Services -join ', ') in project: $Project"
    docker compose -f $composePath -p $Project stop $Services
  }

  "restart" {
    Write-Host "Restarting services: $($Services -join ', ') in project: $Project"
    docker compose -f $composePath -p $Project restart $Services
  }

  "logs" {
    $args = @("-f", $composePath, "-p", $Project, "logs")
    if ($Follow) { $args += "-f" }
    $args += $Services

    Write-Host "Viewing logs for: $($Services -join ', ') in project: $Project"
    docker compose @args
  }

  "ps" {
    Write-Host "Status of services: $($Services -join ', ') in project: $Project"
    docker compose -f $composePath -p $Project ps $Services
  }

  "exec" {
    if (-not $Command) {
      Write-Host "Error: -Command parameter is required for 'exec' action"
      exit 1
    }

    if ($Services.Count -gt 1) {
      Write-Host "Error: 'exec' can only target one service at a time"
      exit 1
    }

    Write-Host "Executing command in service: $Services"
    docker compose -f $composePath -p $Project exec $Services $Command
  }
}

exit $LASTEXITCODE
