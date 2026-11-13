@echo off
rem Removes the Anno 1602 extensions again. Game and saved games stay unchanged.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\install.ps1" -Remove
echo.
pause
