param(
    [string]$PalworldPath = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$PackageRoot = Split-Path -Parent $PSScriptRoot
$Source = Join-Path $PackageRoot "ClientMod\KhaosAdminDeck"

if (-not (Test-Path -LiteralPath $Source)) {
    $Source = Join-Path $PackageRoot "KhaosAdminDeck"
}

if ([string]::IsNullOrWhiteSpace($PalworldPath)) {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Steam\steamapps\common\Palworld",
        "$env:ProgramFiles\Steam\steamapps\common\Palworld"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            $PalworldPath = $candidate
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($PalworldPath) -or -not (Test-Path -LiteralPath $PalworldPath)) {
    throw "Palworld was not found. Re-run with -PalworldPath 'D:\SteamLibrary\steamapps\common\Palworld'"
}

if (-not (Test-Path -LiteralPath $Source)) {
    throw "The KhaosAdminDeck source folder was not found beside this installer."
}

$TargetParent = Join-Path $PalworldPath "Mods\NativeMods\UE4SS\Mods"
$Target = Join-Path $TargetParent "KhaosAdminDeck"
$Ue4ssRoot = Join-Path $PalworldPath "Mods\NativeMods\UE4SS"

if (-not (Test-Path -LiteralPath $Ue4ssRoot)) {
    Write-Warning "The official UE4SS path was not found: $Ue4ssRoot"
    Write-Warning "Install or enable UE4SS Experimental for Palworld before testing the mod."
}

New-Item -ItemType Directory -Path $TargetParent -Force | Out-Null

if (Test-Path -LiteralPath $Target) {
    $backup = "$Target.backup-" + (Get-Date -Format "yyyyMMdd-HHmmss")
    Write-Host "Backing up existing mod to $backup"
    Move-Item -LiteralPath $Target -Destination $backup
}

Copy-Item -LiteralPath $Source -Destination $Target -Recurse -Force
Write-Host ""
Write-Host "Khaos Admin Deck installed:" -ForegroundColor Green
Write-Host "  $Target"
Write-Host ""
Write-Host "Launch Palworld, join the server, and press F9."
