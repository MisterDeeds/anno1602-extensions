@echo off
rem Installiert die Anno-1602-Erweiterungen aus diesem Ordner (Doppelklick genuegt).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\paket\installieren.ps1"
echo.
pause
