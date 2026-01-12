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

echo [1/4] Checking git configuration...
call :ensure_git_email_configured

echo.
echo [2/4] Getting current branch...
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
echo [3/5] Checking what will be pushed...
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
echo [4/5] Current status...
echo.
git status -s
if %errorlevel% neq 0 (
    echo (Working tree clean)
)

echo.
echo [5/5] Pushing to origin/!current_branch!...
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

:ensure_git_email_configured
rem Check and fix git email configuration to avoid GitHub privacy restrictions
rem GitHub blocks pushes with private emails like noreply@anthropic.com

rem Get current configured email
for /f "delims=" %%e in ('git config user.email 2^>nul') do set "GIT_EMAIL=%%e"

rem Check if email contains problematic domains
echo !GIT_EMAIL! | findstr /C:"anthropic.com" >nul
if %errorlevel% equ 0 goto fix_email_auto

rem Check if email is empty
if "!GIT_EMAIL!"=="" goto fix_email_auto

rem Email looks okay
echo Git email: !GIT_EMAIL!
exit /b 0

:fix_email_auto
rem Try to get GitHub username from remote
for /f "tokens=2 delims=/" %%u in ('git remote get-url origin 2^>nul') do set "GITHUB_USER=%%u"
if "!GITHUB_USER!"=="" set "GITHUB_USER=user"

rem Remove .git suffix if present
set "GITHUB_USER=!GITHUB_USER:.git=!"

echo [AUTO-FIX] Current email: !GIT_EMAIL!
echo [AUTO-FIX] Configuring GitHub no-reply email...

rem Try to extract ID from existing commits
for /f "tokens=1 delims=+" %%i in ('git log -1 --format^=%%ae 2^>nul ^| findstr "@users.noreply.github.com"') do set "GITHUB_ID=%%i"

if defined GITHUB_ID (
  rem Found ID in history, use it
  git config user.email "!GITHUB_ID!+!GITHUB_USER!@users.noreply.github.com"
  echo [AUTO-FIX] New email: !GITHUB_ID!+!GITHUB_USER!@users.noreply.github.com
) else (
  rem No ID found, use simple format
  git config user.email "!GITHUB_USER!@users.noreply.github.com"
  echo [AUTO-FIX] New email: !GITHUB_USER!@users.noreply.github.com
)

exit /b 0

:success
endlocal
exit /b 0
