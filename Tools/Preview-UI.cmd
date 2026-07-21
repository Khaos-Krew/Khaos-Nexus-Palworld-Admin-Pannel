@echo off
set "ROOT=%~dp0.."
if exist "%ROOT%\ClientMod\KhaosAdminDeck\UI\KhaosAdminDeckUI.ps1" (
  start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\ClientMod\KhaosAdminDeck\UI\KhaosAdminDeckUI.ps1" -PreviewOnly
  exit /b 0
)
if exist "%ROOT%\KhaosAdminDeck\UI\KhaosAdminDeckUI.ps1" (
  start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\KhaosAdminDeck\UI\KhaosAdminDeckUI.ps1" -PreviewOnly
  exit /b 0
)
echo KhaosAdminDeckUI.ps1 was not found.
pause
