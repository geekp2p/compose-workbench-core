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

rem Check for uncommitted changes before pushing
call :check_uncommitted_changes
if %ERRORLEVEL% EQU 2 exit /b 0

rem Ensure git email is configured correctly to avoid GitHub privacy restrictions
call :ensure_git_email_configured

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

:check_uncommitted_changes
rem Check for uncommitted changes and display summary
rem Returns 0 to continue, 2 to cancel

rem Check if there are any uncommitted changes (staged or unstaged)
git diff-index --quiet HEAD -- 2>nul
if %ERRORLEVEL% EQU 0 (
  rem No changes, continue
  exit /b 0
)

echo.
echo === WARNING: UNCOMMITTED CHANGES ===
echo.

rem Count changes by type
set /a ADDED=0
set /a MODIFIED=0
set /a DELETED=0
set /a UNTRACKED=0

rem Check unstaged changes (modified/deleted files not yet added)
for /f "tokens=1,2" %%a in ('git diff --name-status 2^>nul') do (
  if "%%a"=="M" set /a MODIFIED+=1
  if "%%a"=="D" set /a DELETED+=1
  if "%%a"=="A" set /a ADDED+=1
  echo  %%a  %%b
)

rem Check staged changes (added to index but not committed)
for /f "tokens=1,2" %%a in ('git diff --cached --name-status 2^>nul') do (
  if "%%a"=="M" set /a MODIFIED+=1
  if "%%a"=="D" set /a DELETED+=1
  if "%%a"=="A" set /a ADDED+=1
  echo  %%a  %%b (staged)
)

rem Check untracked files
for /f "delims=" %%f in ('git ls-files --others --exclude-standard 2^>nul') do (
  set /a UNTRACKED+=1
  echo  ?  %%f (untracked)
)

echo.
echo Summary:
if %ADDED% GTR 0 echo   - Added: %ADDED% file(s)
if %MODIFIED% GTR 0 echo   - Modified: %MODIFIED% file(s)
if %DELETED% GTR 0 echo   - Deleted: %DELETED% file(s)
if %UNTRACKED% GTR 0 echo   - Untracked: %UNTRACKED% file(s)
echo.
echo These changes will NOT be pushed to remote.
echo You need to commit them first with: git add . ^&^& git commit -m "message"
echo.
echo ======================================
echo.

set /p "CONTINUE=Continue push anyway? (y/N): "
if /i "%CONTINUE%"=="y" exit /b 0

echo Push cancelled.
exit /b 2

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

:ensure_git_email_configured
rem Check and fix git email configuration to avoid GitHub privacy restrictions
rem GitHub blocks pushes with private emails like noreply@anthropic.com

rem Get current configured email
for /f "delims=" %%e in ('git config user.email 2^>nul') do set GIT_EMAIL=%%e

rem Check if email contains problematic domains
echo %GIT_EMAIL% | findstr /C:"anthropic.com" >nul
if %ERRORLEVEL% EQU 0 goto fix_email

rem Check if email is empty
if "%GIT_EMAIL%"=="" goto fix_email

rem Email looks okay
exit /b 0

:fix_email
rem Try to get GitHub username and ID from remote
for /f "tokens=2 delims=:/" %%u in ('git remote get-url %REMOTE% 2^>nul') do set GITHUB_USER=%%u
if "%GITHUB_USER%"=="" set GITHUB_USER=user

rem Set GitHub no-reply email format
rem Common format: ID+username@users.noreply.github.com
rem Fallback: username@users.noreply.github.com

echo.
echo [AUTO-FIX] Configuring git email to avoid GitHub privacy restrictions...
echo Current email: %GIT_EMAIL%

rem Try to extract ID from existing commits
for /f "tokens=1 delims=+" %%i in ('git log -1 --format^=%%ae 2^>nul ^| findstr "@users.noreply.github.com"') do set GITHUB_ID=%%i

if defined GITHUB_ID (
  rem Found ID in history, use it
  git config user.email "%GITHUB_ID%+%GITHUB_USER%@users.noreply.github.com"
  echo New email: %GITHUB_ID%+%GITHUB_USER%@users.noreply.github.com
) else (
  rem No ID found, use simple format
  git config user.email "%GITHUB_USER%@users.noreply.github.com"
  echo New email: %GITHUB_USER%@users.noreply.github.com
)

echo [AUTO-FIX] Email configured successfully
echo.
exit /b 0

:notrepo
echo This folder is not a git repository.
exit /b 1

:error
echo Push failed. Check the messages above for details.
exit /b 1
