@echo off
setlocal enabledelayedexpansion

rem ========================================
rem AUTO-PUSH: Automatic Push Current Branch
rem ========================================
rem Automatically pushes current branch to remote
rem No questions asked, just run and done!
rem Includes retry logic for network failures
rem ========================================

echo.
echo ======================================
echo   AUTO-PUSH (Current Branch)
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

echo [1/4] Getting current branch...
for /f "tokens=*" %%a in ('git branch --show-current') do set "current_branch=%%a"

if not defined current_branch (
    echo [ERROR] Not on any branch (detached HEAD?)
    exit /b 1
)

echo Current branch: !current_branch!

rem Check if branch starts with "claude/"
echo !current_branch! | findstr /B "claude/" >nul
if %errorlevel% neq 0 (
    echo.
    echo [WARNING] Branch does not start with "claude/"
    echo Push may fail with 403 error according to git rules
    echo.
)

echo.
echo [2/4] Checking what will be pushed...
echo.

rem Check for unpushed commits
for /f %%a in ('git rev-list --count origin/!current_branch!..HEAD 2^>nul') do set "commit_count=%%a"
if not defined commit_count set commit_count=0

if !commit_count! gtr 0 (
    echo ┌─ Commits to push: !commit_count!
    echo │
    git log --oneline --decorate origin/!current_branch!..HEAD 2>nul
    echo.
) else (
    echo ┌─ No new commits to push
    echo.
)

echo.
echo [3/4] Current status...
echo.
git status -s
if %errorlevel% neq 0 (
    echo (Working tree clean)
)

echo.
echo [4/4] Pushing to origin/!current_branch!...
echo.

rem Retry logic: up to 4 retries with exponential backoff (2s, 4s, 8s, 16s)
set max_retries=4
set retry_count=0
set wait_time=2

:retry_push
set /a retry_count+=1

if !retry_count! gtr 1 (
    echo.
    echo [Retry !retry_count!/!max_retries!] Waiting !wait_time! seconds...
    timeout /t !wait_time! /nobreak >nul
)

echo Pushing... (attempt !retry_count!/!max_retries!)
git push -u origin !current_branch!

if %errorlevel% equ 0 (
    echo.
    echo ======================================
    echo   PUSH SUCCESSFUL!
    echo ======================================
    echo Branch: !current_branch!
    echo Remote: origin/!current_branch!
    echo.
    goto :success
)

rem Check if we should retry
if !retry_count! lss !max_retries! (
    echo [ERROR] Push failed, retrying...
    rem Double the wait time for next retry (exponential backoff)
    set /a wait_time*=2
    goto :retry_push
)

rem All retries failed
echo.
echo ======================================
echo   PUSH FAILED AFTER !max_retries! ATTEMPTS
echo ======================================
echo.
echo Possible reasons:
echo - Network connectivity issues
echo - Branch name doesn't start with "claude/" (403 error)
echo - No changes to push
echo - Authentication failed
echo.
exit /b 1

:success
endlocal
exit /b 0
