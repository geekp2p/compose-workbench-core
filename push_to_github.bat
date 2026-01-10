@echo off
setlocal

rem Default remote URL for this repository (used when no remote is configured)
set DEFAULT_REMOTE_URL=https://github.com/geekp2p/multi-compose-labV2.git
git rev-parse --is-inside-work-tree >nul 2>&1 || goto notrepo

set REMOTE=%1
if "%REMOTE%"=="" set REMOTE=origin

set BRANCH=%2
if "%BRANCH%"=="" (
  for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set BRANCH=%%b
)
if "%BRANCH%"=="" set BRANCH=main

echo Pushing local branch to %REMOTE%/%BRANCH% ...
git remote get-url %REMOTE% >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
  call :add_remote %REMOTE% %3
  if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%
)

rem Push with retry logic (up to 4 retries with exponential backoff)
call :push_with_retry %REMOTE% %BRANCH%
if %ERRORLEVEL% NEQ 0 goto error

echo Done: pushed to %REMOTE%/%BRANCH%.
exit /b 0

:push_with_retry
set PUSH_REMOTE=%1
set PUSH_BRANCH=%2
set RETRY_COUNT=0
set MAX_RETRIES=4

:retry_loop
git push -u %PUSH_REMOTE% %PUSH_BRANCH%
if %ERRORLEVEL% EQU 0 exit /b 0

set /a RETRY_COUNT+=1
if %RETRY_COUNT% GEQ %MAX_RETRIES% (
  echo Push failed after %MAX_RETRIES% retries.
  exit /b 1
)

rem Calculate delay: 2^RETRY_COUNT seconds
set /a DELAY=2
for /L %%i in (2,1,%RETRY_COUNT%) do set /a DELAY*=2

echo Push failed, retrying in %DELAY% seconds (attempt %RETRY_COUNT%/%MAX_RETRIES%)...
timeout /t %DELAY% /nobreak >nul
goto retry_loop

:add_remote
set ADD_REMOTE_NAME=%1
set ADD_REMOTE_URL=%2

if "%ADD_REMOTE_URL%"=="" if defined GIT_REMOTE_URL set ADD_REMOTE_URL=%GIT_REMOTE_URL%
if "%ADD_REMOTE_URL%"=="" if defined DEFAULT_REMOTE_URL set ADD_REMOTE_URL=%DEFAULT_REMOTE_URL%

if "%ADD_REMOTE_URL%"=="" (
  set /p "ADD_REMOTE_URL=Enter URL for remote %ADD_REMOTE_NAME% (e.g. github.com/your/repo.git) - "
)

if "%ADD_REMOTE_URL%"=="" (
  echo Remote %ADD_REMOTE_NAME% is not configured and no URL was provided.
  exit /b 1
)

git remote add %ADD_REMOTE_NAME% %ADD_REMOTE_URL% || exit /b 1
echo Added remote %ADD_REMOTE_NAME% with %ADD_REMOTE_URL%.
git fetch --quiet %ADD_REMOTE_NAME% 2>nul
exit /b 0

:notrepo
echo This folder is not a git repository.
exit /b 1

:error
echo Push failed. Check the messages above for details.
exit /b 1
