@echo off
REM Wrapper script for init-from-github.ps1 to support Windows batch execution

REM Check if PowerShell exists
where pwsh >nul 2>&1
if %errorlevel% == 0 (
    pwsh -File "%~dp0init-from-github.ps1" %*
) else (
    powershell -ExecutionPolicy Bypass -File "%~dp0init-from-github.ps1" %*
)
