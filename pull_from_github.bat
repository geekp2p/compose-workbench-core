@echo off
setlocal enabledelayedexpansion

rem Default remote URL for this repository (used when no remote is configured)
set DEFAULT_REMOTE_URL=https://github.com/geekp2p/multi-compose-labV2.git
git rev-parse --is-inside-work-tree >nul 2>&1 || goto notrepo

set REMOTE=%1
if "%REMOTE%"=="" set REMOTE=origin

set BRANCH=%2
if "%BRANCH%"=="" (
  rem Find the latest claude/ branch from remote
  echo Fetching latest branches...
  git fetch %REMOTE% --quiet 2>nul

  rem Get the latest claude/ branch (first line only using for loop break)
  set LATEST_BRANCH=
  for /f "delims=" %%b in ('git for-each-ref --sort^=-committerdate --format^="%%(refname:short)" refs/remotes/%REMOTE%/claude/ 2^>nul') do (
    if not defined LATEST_BRANCH set LATEST_BRANCH=%%b
  )

  rem Remove "origin/" prefix to get branch name
  if defined LATEST_BRANCH (
    set "BRANCH=!LATEST_BRANCH:%REMOTE%/=!"
    echo Found latest claude branch: !BRANCH!
  ) else (
    rem Fallback to current branch
    for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set BRANCH=%%b
  )
)
if "%BRANCH%"=="" set BRANCH=main

echo Syncing local branch with %REMOTE%/!BRANCH! ...

rem Switch to the branch if not already on it
for /f "delims=" %%c in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set CURRENT_BRANCH=%%c
if not "!CURRENT_BRANCH!"=="!BRANCH!" (
  echo Switching to branch !BRANCH!...
  git checkout -B !BRANCH! %REMOTE%/!BRANCH! 2>nul || git checkout -b !BRANCH! %REMOTE%/!BRANCH! 2>nul || goto error
)
git remote get-url %REMOTE% >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
  call :add_remote %REMOTE% %3
  if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%
)

rem Save current commit hash for comparison
for /f %%h in ('git rev-parse HEAD 2^>nul') do set OLD_COMMIT=%%h

git fetch %REMOTE% || goto error

rem Get the new commit hash from remote
for /f %%h in ('git rev-parse %REMOTE%/!BRANCH! 2^>nul') do set NEW_COMMIT=%%h

rem Show what's changing if there are updates
if not "!OLD_COMMIT!"=="!NEW_COMMIT!" (
  echo.
  echo === UPDATE SUMMARY ===
  echo From: !OLD_COMMIT:~0,7!
  echo To:   !NEW_COMMIT:~0,7!
  echo.
  echo New commits:
  git log --oneline !OLD_COMMIT!..!NEW_COMMIT!
  echo.
  echo Files changed:
  git diff --stat !OLD_COMMIT!..!NEW_COMMIT!
  echo.
  echo ======================
  echo.
) else (
  echo Already up to date - no changes detected.
)

git reset --hard %REMOTE%/!BRANCH! || goto error
git clean -fd || goto error

echo Done: local tree now matches %REMOTE%/!BRANCH!.
exit /b 0

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
echo Sync failed. Check the messages above for details.
exit /b 1
