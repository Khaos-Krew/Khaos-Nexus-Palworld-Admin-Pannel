@echo off
setlocal
set "SCRIPT=%~dp0KhaosAdminDeckUI.ps1"
if not exist "%SCRIPT%" (
  echo KhaosAdminDeckUI.ps1 was not found.
  pause
  exit /b 1
)
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%SCRIPT%"
endlocal
