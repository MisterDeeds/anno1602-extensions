@echo off
rem Entfernt die Anno-1602-Erweiterungen wieder. Spiel und Spielstaende bleiben unveraendert.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\paket\installieren.ps1" -Entfernen
echo.
pause
