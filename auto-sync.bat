@echo off
setlocal enabledelayedexpansion

rem ========================================
rem Auto-Sync Current Branch Script
rem ========================================
rem This script syncs the CURRENT branch with its remote tracking branch
rem WITHOUT switching to a different branch
rem ========================================

echo.
echo ===================================
echo   AUTO-SYNC CURRENT BRANCH
echo ===================================
echo.

rem Check if this is a git repository
git rev-parse --is-inside-work-tree >nul 2>&1 || goto notrepo

rem Get current branch name
for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set CURRENT_BRANCH=%%b

if "%CURRENT_BRANCH%"=="" (
    echo Error: Could not determine current branch
    exit /b 1
)

echo Current branch: %CURRENT_BRANCH%
echo.

rem Set remote (default: origin)
set REMOTE=%1
if "%REMOTE%"=="" set REMOTE=origin

rem Check if remote exists
git remote get-url %REMOTE% >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: Remote '%REMOTE%' does not exist
    echo Available remotes:
    git remote -v
    exit /b 1
)

rem Check for uncommitted changes
git diff --quiet 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo WARNING: You have uncommitted changes!
    echo.
    git status --short
    echo.
    set /p "CONTINUE=Do you want to continue? This will DISCARD local changes! [y/N]: "
    if /i not "!CONTINUE!"=="y" (
        echo Sync cancelled.
        exit /b 0
    )
)

rem Save current commit hash for comparison
for /f %%h in ('git rev-parse HEAD 2^>nul') do set OLD_COMMIT=%%h

echo Fetching from %REMOTE%...
git fetch %REMOTE% || goto error

rem Check if remote branch exists
git rev-parse %REMOTE%/%CURRENT_BRANCH% >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Error: Remote branch '%REMOTE%/%CURRENT_BRANCH%' does not exist
    echo.
    echo Available remote branches matching '%CURRENT_BRANCH%':
    git branch -r | findstr "%CURRENT_BRANCH%"
    if %ERRORLEVEL% NEQ 0 (
        echo   (No matching branches found)
    )
    exit /b 1
)

rem Get the new commit hash from remote
for /f %%h in ('git rev-parse %REMOTE%/%CURRENT_BRANCH% 2^>nul') do set NEW_COMMIT=%%h

rem Show what's changing if there are updates
if not "%OLD_COMMIT%"=="%NEW_COMMIT%" (
    echo.
    echo ===== UPDATE SUMMARY =====
    echo Branch:  %CURRENT_BRANCH%
    echo From:    %OLD_COMMIT:~0,7%
    echo To:      %NEW_COMMIT:~0,7%
    echo.
    echo New commits:
    git log --oneline --color=always %OLD_COMMIT%..%NEW_COMMIT%
    echo.
    echo Files changed:
    git diff --stat --color=always %OLD_COMMIT%..%NEW_COMMIT%
    echo.
    echo ==========================
    echo.
) else (
    echo.
    echo ✓ Already up to date - no changes detected.
    echo.
    exit /b 0
)

echo Syncing local branch with %REMOTE%/%CURRENT_BRANCH%...
git reset --hard %REMOTE%/%CURRENT_BRANCH% || goto error
git clean -fd || goto error

echo.
echo ✓ Done: '%CURRENT_BRANCH%' now matches %REMOTE%/%CURRENT_BRANCH%
echo.
exit /b 0

:notrepo
echo Error: This folder is not a git repository.
exit /b 1

:error
echo.
echo ✗ Sync failed. Check the messages above for details.
echo.
exit /b 1
