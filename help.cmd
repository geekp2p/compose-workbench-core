@echo off
setlocal
REM ============================================================
REM help.cmd
REM Display help information for multi-compose-lab
REM ============================================================

set ROOT=%~dp0
set TOPIC=%~1

if "%TOPIC%"=="" (
  powershell -ExecutionPolicy Bypass -File "%ROOT%help.ps1"
) else (
  powershell -ExecutionPolicy Bypass -File "%ROOT%help.ps1" -Topic "%TOPIC%"
)

exit /b %ERRORLEVEL%
