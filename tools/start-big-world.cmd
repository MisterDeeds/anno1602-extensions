@echo off
rem Starts the tool for the big world (anno-patcher.ps1) in its own window and then
rem Anno 1602 History Edition through Ubisoft Connect.
rem Further arguments are passed on to the tool, e.g.:
rem   start-big-world.cmd -Width 750 -Height 525
rem   start-big-world.cmd -NoIslandSpread
start "Anno 1602 - big world" powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0anno-patcher.ps1" %*
rem short pause (ping instead of timeout, which aborts without console input)
ping -n 5 127.0.0.1 >nul
start "" "uplay://launch/16236/0"
