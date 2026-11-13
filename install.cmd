@echo off
rem Installs the Anno 1602 extensions from this folder (a double-click is enough).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\install.ps1"
echo.
pause
