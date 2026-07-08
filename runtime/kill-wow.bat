@echo off
REM kill-wow.bat — Force-kill a frozen WoW client immediately.
REM
REM Double-click this if WoW is frozen and won't close.
REM Place it on your desktop for quick access.

taskkill /f /im Wow-64.exe >nul 2>&1
taskkill /f /im Wow.exe >nul 2>&1
taskkill /f /im launcher.exe >nul 2>&1
taskkill /f /im Agent.exe >nul 2>&1
taskkill /f /im "Battle.net.exe" >nul 2>&1

echo WoW processes killed.
timeout /t 2 /nobreak >nul 2>&1
