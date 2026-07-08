@echo off
setlocal enabledelayedexpansion
TITLE Firestorm WoD Launcher

:: === CONFIG ===
set WOW_EXE=Wow-64.exe
set CACHE_DIR=%~dp0Cache
set REG_PATH=HKCU\Software\Blizzard Entertainment\Battle.net

:: === Check local cache ===
if not exist "%CACHE_DIR%\0a\3a\0a3afee2cade3a0e8b458c4b4660104cac7fc50e2ca9bef0d708942e77f15c1d.auth" (
    echo [ERROR] Local cache not found at %CACHE_DIR%
    echo Run setup-launcher.bat first to create it.
    pause
    exit /b 1
)

:: === Save current CachePath from registry ===
set SAVED_PATH=
for /f "skip=2 tokens=3*" %%a in ('reg query "%REG_PATH%" /v CachePath 2^>nul') do (
    set SAVED_PATH=%%a %%b
)

:: === Set cache to local directory ===
echo [Launcher] Setting cache path to: %CACHE_DIR%
reg add "%REG_PATH%" /v CachePath /t REG_SZ /d "%CACHE_DIR%" /f >nul 2>&1

:: === Launch the game ===
echo [Launcher] Starting Wow-64.exe ...
echo.
start "" /wait "%WOW_EXE%"

:: === Restore original registry value ===
echo.
echo [Launcher] Game exited. Restoring registry ...
if "%SAVED_PATH%"=="" (
    reg delete "%REG_PATH%" /v CachePath /f >nul 2>&1
    echo   Removed CachePath (was not set before)
) else (
    reg add "%REG_PATH%" /v CachePath /t REG_SZ /d "%SAVED_PATH%" /f >nul 2>&1
    echo   Restored CachePath to: %SAVED_PATH%
)

echo [Launcher] Done.
exit /b 0
