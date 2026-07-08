@echo off
setlocal
TITLE Firestorm Cache Setup

set CACHE_DIR=%~dp0Cache

echo ========================================
echo  Firestorm Cache Setup
echo ========================================
echo.

:: Find the auth modules zip (look in same dir and parent dirs)
set ZIP_FILE=
if exist "%~dp0bnet-auth-modules.zip" (
    set ZIP_FILE=%~dp0bnet-auth-modules.zip
) else if exist "%~dp0..\bnet-auth-modules.zip" (
    set ZIP_FILE=%~dp0..\bnet-auth-modules.zip
)

if "%ZIP_FILE%"=="" (
    echo [ERROR] Cannot find bnet-auth-modules.zip
    echo Place it next to this script or in the parent directory.
    pause
    exit /b 1
)

echo Found: %ZIP_FILE%
echo Target: %CACHE_DIR%
echo.

:: Clean and create cache directory
if exist "%CACHE_DIR%" (
    echo Cleaning existing cache ...
    rmdir /s /q "%CACHE_DIR%"
)
mkdir "%CACHE_DIR%"

:: Extract using PowerShell (available on all Win10+)
echo Extracting auth modules ...
powershell -NoProfile -Command ^
    "Expand-Archive -Path '%ZIP_FILE%' -DestinationPath '%CACHE_DIR%' -Force"

:: Verify extraction
if exist "%CACHE_DIR%\0a\3a\0a3afee2cade3a0e8b458c4b4660104cac7fc50e2ca9bef0d708942e77f15c1d.auth" (
    echo.
    echo ========================================
    echo  Setup complete!
    echo  Cache created at: %CACHE_DIR%
    echo  Use launch-wow-windows.bat to start the game.
    echo ========================================
) else (
    echo.
    echo [ERROR] Extraction failed! Try extracting bnet-auth-modules.zip
    echo manually to: %CACHE_DIR%
    echo The folder structure should be:
    echo   Cache\0a\3a\*.auth
    echo   Cache\2e\6d\*.auth
    echo   etc.
)

pause
