@echo off
rem Startet das Werkzeug fuer die grosse Welt in einem eigenen Fenster und danach
rem Anno 1602 History Edition ueber Ubisoft Connect.
rem Weitere Angaben werden an das Werkzeug durchgereicht, z. B.:
rem   anno-grosse-welt.cmd -Breite 750 -Hoehe 525
rem   anno-grosse-welt.cmd -OhneInselVerteilung
start "Anno 1602 - grosse Welt" powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0weltgroesse.ps1" %*
rem kurze Pause (ping statt timeout, das ohne Konsole-Eingabe abbricht)
ping -n 5 127.0.0.1 >nul
start "" "uplay://launch/16236/0"
