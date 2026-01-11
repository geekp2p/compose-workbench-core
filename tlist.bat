@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ==== Usage: tlist.bat [target_dir] [skip_file]
rem Example:  tlist.bat . txt.txt > txt.txt

set "target=%~1"
if "%target%"=="" set "target=."
set "skipfile=%~f2"

echo =================================
echo   TREE STRUCTURE
echo   Target: %target%
echo =================================
echo.
rem ASCII tree to avoid garbled characters when redirecting to a file
tree "%target%" /f /a
echo.

echo =================================
echo   LIST FILES + SHOW CONTENTS
echo   Target: %target%
echo =================================
echo.

set "MAXSIZE=2000000"

rem ---- allowed text extensions ----
set "ALLOWEXTS=.ps1 .psm1 .txt .md .json .yaml .yml .xml .html .htm .css .js .ts .go .py .bat .cmd .ini .conf .toml .env .gitignore .dockerfile .sh .c .h .am .in .ac .rst .cmake .asm .def .pc"

rem ---- blacklist extensions (won't show even if in allow list) ----
set "SKIPEXTS=.mod .sum .lock"

rem ---- files without extension to include (filename patterns) ----
set "NOEXT_FILES=Dockerfile LICENSE Makefile README AUTHORS COPYING NEWS ChangeLog"

rem ---- directories to skip ----
set "SKIP_DIRS=.git node_modules __pycache__ .pytest_cache build dist obj bin"

rem ---- Process all files ----
for /r "%target%" %%F in (*) do (
    set "full=%%~fF"
    set "ext=%%~xF"
    set "size=%%~zF"
    set "name=%%~nxF"
    set "skip_dir=0"

    rem check if file is in a blacklisted directory
    for %%D in (%SKIP_DIRS%) do (
        echo !full! | findstr /I /C:"\%%D\" >nul
        if !ERRORLEVEL! EQU 0 set "skip_dir=1"
    )

    rem skip output file if provided as arg2
    if /I "!full!"=="%skipfile%" (
        rem skip
    ) else if "!skip_dir!"=="1" (
        rem skip - in blacklisted directory
    ) else (
        set "okext=0"
        set "skipext=0"

        rem check if it's a file without extension that we want to include
        if "!ext!"=="" (
            call :isTextExt "!name!" "%NOEXT_FILES%" okext
        ) else (
            call :isTextExt "!ext!" "%ALLOWEXTS%" okext
            call :isTextExt "!ext!" "%SKIPEXTS%" skipext
        )

        if "!okext!"=="1" if "!skipext!"=="0" (
            echo ----------------------------------------
            echo FILE: %%F
            echo ----------------------------------------
            if !size! GEQ %MAXSIZE% (
                echo [skip] file size !size! bytes ^(>= %MAXSIZE%^)
            ) else (
                type "%%F"
            )
            echo.
        )
    )
)

echo.
echo ============ DONE ============
exit /b 0

:isTextExt
setlocal EnableDelayedExpansion
set "extchk=%~1"
set "list=%~2"
set "found=0"
for %%E in (%list%) do (
  if /I "%%E"=="!extchk!" set "found=1"
)
endlocal & set "%~3=%found%"
exit /b