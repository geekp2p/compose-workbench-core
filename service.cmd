@echo off
REM ============================================================
REM service.cmd - CMD wrapper for service.ps1
REM Manages individual services within a Docker Compose project
REM ============================================================

pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0service.ps1" %*
if %ERRORLEVEL% neq 0 (
  REM Try Windows PowerShell if pwsh is not available
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0service.ps1" %*
)
exit /b %ERRORLEVEL%
