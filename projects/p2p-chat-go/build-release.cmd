@echo off
REM P2P Chat Build Release - Windows Command Wrapper
REM This script wraps the PowerShell build script for easier execution

setlocal

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"

REM Check if PowerShell 7+ (pwsh) is available
where pwsh >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Using PowerShell 7+
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%build-release.ps1" %*
    goto :end
)

REM Fall back to Windows PowerShell 5.1
where powershell >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Using Windows PowerShell 5.1
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%build-release.ps1" %*
    goto :end
)

REM No PowerShell found
echo Error: PowerShell is not installed or not in PATH
exit /b 1

:end
endlocal
exit /b %ERRORLEVEL%
