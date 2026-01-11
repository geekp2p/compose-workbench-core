# ============================================================
# common.psm1
# Shared functions for docker compose wrapper scripts
# ============================================================

function Get-ScriptRoot {
    <#
    .SYNOPSIS
    Gets the root directory of the script (directory containing the script).
    #>
    return Split-Path -Parent $PSCommandPath
}

function Get-ProjectComposePath {
    <#
    .SYNOPSIS
    Builds the path to a project's compose.yml file.

    .PARAMETER Root
    The root directory path.

    .PARAMETER Project
    The project name.
    #>
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [Parameter(Mandatory=$true)][string]$Project
    )

    return Join-Path $Root ("projects\" + $Project + "\compose.yml")
}

function Test-ProjectExists {
    <#
    .SYNOPSIS
    Validates that a project exists by checking if its compose.yml file exists.

    .PARAMETER Root
    The root directory path.

    .PARAMETER Project
    The project name.

    .PARAMETER ShowError
    If true, displays error messages and lists available projects.

    .OUTPUTS
    Returns $true if project exists, $false otherwise.
    #>
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [Parameter(Mandatory=$true)][string]$Project,
        [switch]$ShowError
    )

    $composePath = Get-ProjectComposePath -Root $Root -Project $Project

    if (!(Test-Path $composePath)) {
        if ($ShowError) {
            Write-Host "Unknown project: $Project"
            Show-AvailableProjects -Root $Root
        }
        return $false
    }

    return $true
}

function Show-AvailableProjects {
    <#
    .SYNOPSIS
    Lists all available projects in the projects directory.

    .PARAMETER Root
    The root directory path.
    #>
    param(
        [Parameter(Mandatory=$true)][string]$Root
    )

    Write-Host "Available projects:"
    Get-ChildItem (Join-Path $Root "projects") -Directory | ForEach-Object {
        Write-Host (" - " + $_.Name)
    }
}

Export-ModuleMember -Function Get-ScriptRoot, Get-ProjectComposePath, Test-ProjectExists, Show-AvailableProjects
