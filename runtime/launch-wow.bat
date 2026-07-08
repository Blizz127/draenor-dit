@echo off
REM launch-wow.bat — Launch the patched WoD client and clean up on exit.
REM
REM Place this in the same folder as Wow-64.exe (your wod/ directory).
REM Double-click to launch. When the game closes (or if it freezes),
REM this script will force-kill any lingering WoW processes.
REM
REM The timeout at the end ensures frozen processes get killed even if
REM WoW hangs on close (common when the server is unreachable).

REM Launch WoW directly (not the launcher)
start "" /wait "Wow-64.exe"

REM WoW has exited (or been closed). Wait a moment for clean shutdown.
timeout /t 3 /nobreak >nul 2>&1

REM Force-kill any lingering WoW processes (fixes the freeze-on-close).
taskkill /f /im Wow-64.exe >nul 2>&1
taskkill /f /im Wow.exe >nul 2>&1
taskkill /f /im launcher.exe >nul 2>&1

REM Also kill any stuck Agent.exe (Battle.net helper that can hang)
taskkill /f /im Agent.exe >nul 2>&1
