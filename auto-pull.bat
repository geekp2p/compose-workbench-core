@echo off
setlocal enabledelayedexpansion

rem ========================================
rem AUTO-PULL: Automatic Pull Latest Branch
rem ========================================
rem Automatically pulls from the latest claude/ branch
rem No questions asked, just run and done!
rem ========================================

echo.
echo ======================================
echo   AUTO-PULL (Latest claude/ Branch)
echo ======================================
echo.

rem Check if git is available
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Git is not installed or not in PATH
    exit /b 1
)

rem Check if we're in a git repository
git rev-parse --git-dir >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Not a git repository
    exit /b 1
)

echo [1/3] Checking current status...
git status -s

echo.
echo [2/3] Fetching from remote...
git fetch origin
if %errorlevel% neq 0 (
    echo [ERROR] Failed to fetch from remote
    exit /b 1
)

echo.
echo [3/3] Finding latest claude/ branch...

rem Get all remote claude/ branches sorted by commit date
for /f "tokens=*" %%a in ('git branch -r --list "origin/claude/*" --sort=-committerdate 2^>nul') do (
    set "latest_branch=%%a"
    goto :found_branch
)

:found_branch
if not defined latest_branch (
    echo [ERROR] No claude/ branches found on remote
    exit /b 1
)

rem Extract branch name (remove "origin/" prefix)
set "latest_branch=!latest_branch:*origin/=!"
set "latest_branch=!latest_branch: =!"

echo.
echo Found latest branch: !latest_branch!
echo Pulling from origin/!latest_branch!...
echo.

rem Get current branch
for /f "tokens=*" %%a in ('git branch --show-current') do set "current_branch=%%a"

rem If we're already on the branch, just pull
if "!current_branch!"=="!latest_branch!" (
    git pull origin !latest_branch!
    if %errorlevel% equ 0 (
        echo.
        echo ======================================
        echo   PULL SUCCESSFUL!
        echo ======================================
        echo Branch: !latest_branch!
        echo.
    ) else (
        echo.
        echo [ERROR] Pull failed
        exit /b 1
    )
) else (
    rem Switch to the branch if it exists locally, otherwise create it
    git show-ref --verify --quiet refs/heads/!latest_branch!
    if %errorlevel% equ 0 (
        rem Branch exists locally, switch and pull
        git checkout !latest_branch!
        git pull origin !latest_branch!
    ) else (
        rem Branch doesn't exist locally, create it from remote
        git checkout -b !latest_branch! origin/!latest_branch!
    )

    if %errorlevel% equ 0 (
        echo.
        echo ======================================
        echo   PULL SUCCESSFUL!
        echo ======================================
        echo Switched to: !latest_branch!
        echo.
    ) else (
        echo.
        echo [ERROR] Failed to checkout/pull branch
        exit /b 1
    )
)

endlocal
exit /b 0
