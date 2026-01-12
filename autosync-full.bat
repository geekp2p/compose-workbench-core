@echo off
setlocal enabledelayedexpansion

rem ========================================
rem AUTO-SYNC FULL: Auto Pull + Auto Push
rem ========================================
rem This script automatically:
rem 1. Commits any uncommitted changes
rem 2. Pulls from remote (auto-detects latest claude/ branch)
rem 3. Pushes to remote with retry logic
rem ========================================

echo.
echo ======================================
echo   AUTO-SYNC FULL (Pull + Push)
echo ======================================
echo.

rem Default remote URL for this repository
set DEFAULT_REMOTE_URL=https://github.com/geekp2p/multi-compose-labV2.git
git rev-parse --is-inside-work-tree >nul 2>&1 || goto notrepo

rem Parse arguments
set REMOTE=%1
if "%REMOTE%"=="" set REMOTE=origin

set BRANCH=%2
set AUTO_COMMIT=%3
if "%AUTO_COMMIT%"=="" set AUTO_COMMIT=yes

rem ========================================
rem STEP 1: Auto-commit uncommitted changes
rem ========================================
call :auto_commit_changes
if %ERRORLEVEL% NEQ 0 goto error

rem ========================================
rem STEP 2: Auto-detect branch if not specified
rem ========================================
if "%BRANCH%"=="" (
    echo.
    echo [STEP 2/4] Detecting latest branch...
    echo ----------------------------------
    rem Find the latest claude/ branch from remote
    echo Fetching latest branches from %REMOTE%...
    git fetch %REMOTE% --quiet 2>nul

    rem Get the latest claude/ branch (sorted by commit date)
    set LATEST_BRANCH=
    for /f "delims=" %%b in ('git for-each-ref --sort^=-authordate --format^="%%(refname:short)" refs/remotes/%REMOTE%/claude/ 2^>nul') do (
        if not defined LATEST_BRANCH set LATEST_BRANCH=%%b
    )

    rem Remove "origin/" prefix to get branch name
    if defined LATEST_BRANCH (
        set "BRANCH=!LATEST_BRANCH:%REMOTE%/=!"
        echo Found latest claude branch: !BRANCH!

        rem Show branch date for confirmation
        for /f "tokens=*" %%d in ('git log -1 --format^="%%ai" refs/remotes/!LATEST_BRANCH! 2^>nul') do (
            echo Branch date: %%d
        )
    ) else (
        echo No claude/ branches found, using current branch...
        rem Fallback to current branch
        for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set BRANCH=%%b
    )
)
if "%BRANCH%"=="" set BRANCH=main

echo Target branch: %BRANCH%
echo.

rem ========================================
rem STEP 3: Pull from remote
rem ========================================
echo.
echo [STEP 3/4] Pulling from remote...
echo ----------------------------------
call :pull_from_remote %REMOTE% !BRANCH!
if %ERRORLEVEL% NEQ 0 goto error

rem ========================================
rem STEP 4: Push to remote
rem ========================================
echo.
echo [STEP 4/4] Pushing to remote...
echo ----------------------------------
call :push_to_remote %REMOTE% !BRANCH!
if %ERRORLEVEL% NEQ 0 goto error

echo.
echo ======================================
echo   SUCCESS: Auto-sync completed!
echo ======================================
echo.
echo   Remote: %REMOTE%
echo   Branch: !BRANCH!
echo.
exit /b 0

rem ========================================
rem FUNCTION: auto_commit_changes
rem ========================================
:auto_commit_changes
echo.
echo [STEP 1/4] Checking for uncommitted changes...
echo ----------------------------------

rem Check if there are any uncommitted changes
git diff-index --quiet HEAD -- 2>nul
if %ERRORLEVEL% EQU 0 (
    echo No uncommitted changes found.
    exit /b 0
)

echo.
echo Uncommitted changes detected:
echo.
git status --short
echo.

if /i not "%AUTO_COMMIT%"=="yes" (
    set /p "DO_COMMIT=Auto-commit these changes? (Y/n): "
    if /i "!DO_COMMIT!"=="n" (
        echo Skipping auto-commit.
        echo WARNING: Uncommitted changes will NOT be pushed!
        exit /b 0
    )
)

rem Generate commit message based on changes
set COMMIT_MSG=Auto-sync: Update files

rem Count changes for better commit message
set /a TOTAL_CHANGES=0
for /f %%f in ('git diff --name-only --cached 2^>nul') do set /a TOTAL_CHANGES+=1
for /f %%f in ('git diff --name-only 2^>nul') do set /a TOTAL_CHANGES+=1
for /f %%f in ('git ls-files --others --exclude-standard 2^>nul') do set /a TOTAL_CHANGES+=1

if %TOTAL_CHANGES% GTR 0 (
    set COMMIT_MSG=Auto-sync: Update %TOTAL_CHANGES% file(s)
)

echo Committing changes...
git add -A || exit /b 1
git commit -m "%COMMIT_MSG%" || exit /b 1

echo Committed successfully: %COMMIT_MSG%
exit /b 0

rem ========================================
rem FUNCTION: pull_from_remote
rem ========================================
:pull_from_remote
set PULL_REMOTE=%1
set PULL_BRANCH=%2

rem Ensure remote exists
git remote get-url %PULL_REMOTE% >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    call :add_remote %PULL_REMOTE%
    if %ERRORLEVEL% NEQ 0 exit /b 1
)

rem Switch to the branch if not already on it
for /f "delims=" %%c in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set CURRENT_BRANCH=%%c
if not "!CURRENT_BRANCH!"=="!PULL_BRANCH!" (
    echo Switching to branch !PULL_BRANCH!...
    git checkout -B !PULL_BRANCH! %PULL_REMOTE%/!PULL_BRANCH! 2>nul || git checkout -b !PULL_BRANCH! %PULL_REMOTE%/!PULL_BRANCH! 2>nul || exit /b 1
)

rem Save current commit for comparison
for /f %%h in ('git rev-parse HEAD 2^>nul') do set OLD_COMMIT=%%h

echo Fetching from %PULL_REMOTE%...
git fetch %PULL_REMOTE% || exit /b 1

rem Get remote commit
for /f %%h in ('git rev-parse %PULL_REMOTE%/!PULL_BRANCH! 2^>nul') do set NEW_COMMIT=%%h

rem Show changes if any
if not "%OLD_COMMIT%"=="%NEW_COMMIT%" (
    echo.
    echo === PULL SUMMARY ===
    echo From: %OLD_COMMIT:~0,7%
    echo To:   %NEW_COMMIT:~0,7%
    echo.
    echo New commits:
    git log --oneline %OLD_COMMIT%..%NEW_COMMIT%
    echo.
    echo Files changed:
    git diff --stat %OLD_COMMIT%..%NEW_COMMIT%
    echo ====================
    echo.

    echo Pulling changes...
    git pull %PULL_REMOTE% !PULL_BRANCH! || exit /b 1
    echo Pulled successfully.
) else (
    echo Already up to date - no remote changes.
)

exit /b 0

rem ========================================
rem FUNCTION: push_to_remote
rem ========================================
:push_to_remote
set PUSH_REMOTE=%1
set PUSH_BRANCH=%2

rem Ensure remote exists
git remote get-url %PUSH_REMOTE% >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    call :add_remote %PUSH_REMOTE%
    if %ERRORLEVEL% NEQ 0 exit /b 1
)

echo Pushing to %PUSH_REMOTE%/%PUSH_BRANCH%...

rem Push with retry logic (up to 4 retries with exponential backoff)
call :push_with_retry %PUSH_REMOTE% %PUSH_BRANCH%
if %ERRORLEVEL% NEQ 0 exit /b 1

echo Pushed successfully.
exit /b 0

rem ========================================
rem FUNCTION: push_with_retry
rem ========================================
:push_with_retry
set RETRY_REMOTE=%1
set RETRY_BRANCH=%2
set RETRY_COUNT=0
set MAX_RETRIES=4

:retry_loop
git push -u %RETRY_REMOTE% %RETRY_BRANCH% 2>nul
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

rem ========================================
rem FUNCTION: add_remote
rem ========================================
:add_remote
set ADD_REMOTE_NAME=%1
set ADD_REMOTE_URL=%2

if "%ADD_REMOTE_URL%"=="" if defined GIT_REMOTE_URL set ADD_REMOTE_URL=%GIT_REMOTE_URL%
if "%ADD_REMOTE_URL%"=="" if defined DEFAULT_REMOTE_URL set ADD_REMOTE_URL=%DEFAULT_REMOTE_URL%

if "%ADD_REMOTE_URL%"=="" (
    set /p "ADD_REMOTE_URL=Enter URL for remote %ADD_REMOTE_NAME%: "
)

if "%ADD_REMOTE_URL%"=="" (
    echo Remote %ADD_REMOTE_NAME% is not configured and no URL was provided.
    exit /b 1
)

git remote add %ADD_REMOTE_NAME% %ADD_REMOTE_URL% || exit /b 1
echo Added remote %ADD_REMOTE_NAME%: %ADD_REMOTE_URL%
git fetch --quiet %ADD_REMOTE_NAME% 2>nul
exit /b 0

rem ========================================
rem ERROR HANDLERS
rem ========================================
:notrepo
echo.
echo ERROR: This folder is not a git repository.
echo.
exit /b 1

:error
echo.
echo ======================================
echo   ERROR: Auto-sync failed!
echo ======================================
echo.
echo Please check the error messages above.
echo.
exit /b 1
