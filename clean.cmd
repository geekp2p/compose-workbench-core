@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================
rem clean.cmd
rem Wrapper for clean.ps1 (PowerShell) with easy CLI usage.
rem
rem Usage:
rem   clean.cmd project go-hello
rem   clean.cmd project go-hello deep
rem   clean.cmd all
rem   clean.cmd all deep
rem   clean.cmd all deep force
rem   clean.cmd project go-hello deep force
rem ============================================================

if "%~1"=="" (
  echo Usage: clean.cmd ^(project ^<name^> [deep] [force]^|all [deep] [force]^)
  exit /b 1
)

set "MODE=%~1"
set "ARG=%~2"
set "OPT3=%~3"
set "OPT4=%~4"

rem Normalize options
set "DEEP="
set "FORCE="

if /I "%OPT3%"=="deep"  set "DEEP=1"
if /I "%OPT3%"=="force" set "FORCE=1"
if /I "%OPT4%"=="deep"  set "DEEP=1"
if /I "%OPT4%"=="force" set "FORCE=1"

set "PS1=%~dp0clean.ps1"

if not exist "%PS1%" (
  echo ERROR: clean.ps1 not found at: "%PS1%"
  exit /b 1
)

if /I "%MODE%"=="project" (
  if "%ARG%"=="" (
    echo Missing project name.
    echo Example: clean.cmd project go-hello deep
    exit /b 1
  )

  if defined DEEP (
    if defined FORCE (
      powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Project "%ARG%" -Deep -Force
    ) else (
      powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Project "%ARG%" -Deep
    )
  ) else (
    if defined FORCE (
      powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Project "%ARG%" -Force
    ) else (
      powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Project "%ARG%"
    )
  )

  exit /b %ERRORLEVEL%
)

if /I "%MODE%"=="all" (
  if defined DEEP (
    if defined FORCE (
      powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -All -Deep -Force
    ) else (
      powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -All -Deep
    )
  ) else (
    if defined FORCE (
      powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -All -Force
    ) else (
      powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -All
    )
  )

  exit /b %ERRORLEVEL%
)

echo Unknown mode: %MODE%
echo Usage: clean.cmd ^(project ^<name^> [deep] [force]^|all [deep] [force]^)
exit /b 1
