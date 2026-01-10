@echo off
setlocal
if "%~1"=="" (
  echo Usage: down.cmd ^<project^>
  exit /b 1
)
set PROJECT=%~1
set ROOT=%~dp0
set COMPOSE=%ROOT%projects\%PROJECT%\compose.yml

if not exist "%COMPOSE%" (
  echo Unknown project: %PROJECT%
  exit /b 1
)

docker compose -f "%COMPOSE%" -p "%PROJECT%" down
exit /b %ERRORLEVEL%
