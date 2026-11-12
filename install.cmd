@echo off
rem Installs the Anno 1602 extensions from this folder (a double-click is enough).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\install.ps1"
echo.
pause
