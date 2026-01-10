@echo off
setlocal
if "%~1"=="" (
  echo Usage: up.cmd ^<project^> [--build]
  exit /b 1
)
set PROJECT=%~1
set BUILD=%~2

set ROOT=%~dp0
set COMPOSE=%ROOT%projects\%PROJECT%\compose.yml

if not exist "%COMPOSE%" (
  echo Unknown project: %PROJECT%
  echo Available projects:
  for /d %%D in ("%ROOT%projects\*") do echo  - %%~nxD
  exit /b 1
)

if "%BUILD%"=="--build" (
  docker compose -f "%COMPOSE%" -p "%PROJECT%" up -d --build
) else (
  docker compose -f "%COMPOSE%" -p "%PROJECT%" up -d
)
exit /b %ERRORLEVEL%
