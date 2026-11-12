@echo off
rem Ghidra-Auswertung fuer Anno1602.exe (headless).
rem   ghidra-scan.cmd import                 - exe neu importieren, analysieren, AnnoScan laufen lassen
rem   ghidra-scan.cmd <Skript.java> [args]   - Skript auf dem vorhandenen Projekt ausfuehren
rem Ergebnisse landen in analysis\scan, das Log in analysis\scan\headless.log.
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "PROJ=%ROOT%\analysis\ghidra"
set "OUT=%ROOT%\analysis\scan"
set "EXE=%ROOT%\analysis\bin\Anno1602.exe"
set "SCRIPTS=%ROOT%\tools\ghidra_scripts"
if not exist "%OUT%" mkdir "%OUT%"
if not exist "%PROJ%" mkdir "%PROJ%"

if /i "%~1"=="import" (
  call "%GHIDRA_INSTALL_DIR%\support\analyzeHeadless.bat" "%PROJ%" Anno1602 -import "%EXE%" -overwrite -scriptPath "%SCRIPTS%" -postScript AnnoScan.java "%OUT%" -max-cpu 8 > "%OUT%\headless.log" 2>&1
  exit /b %ERRORLEVEL%
)

set "SCRIPT=%~1"
shift
set "ARGS="
:collect
if "%~1"=="" goto run
set "ARGS=%ARGS% %1"
shift
goto collect
:run
call "%GHIDRA_INSTALL_DIR%\support\analyzeHeadless.bat" "%PROJ%" Anno1602 -process Anno1602.exe -noanalysis -readOnly -scriptPath "%SCRIPTS%" -postScript %SCRIPT% "%OUT%" %ARGS% -max-cpu 8 > "%OUT%\headless.log" 2>&1
exit /b %ERRORLEVEL%
