$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

$required = @(
    "KhaosAdminDeck\Scripts\main.lua",
    "KhaosAdminDeck\Scripts\config.lua",
    "KhaosAdminDeck\UI\KhaosAdminDeckUI.ps1",
    "KhaosAdminDeck\UI\Launch-Khaos-Admin-Deck.cmd",
    "WorkshopPackage\Info.json",
    "README.md"
)

foreach ($relative in $required) {
    $path = Join-Path $Root $relative
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required file: $relative"
    }
}

$info = Get-Content -LiteralPath (Join-Path $Root "WorkshopPackage\Info.json") -Raw | ConvertFrom-Json
if ($info.PackageName -ne "KhaosAdminDeck") {
    throw "Unexpected PackageName."
}

$main = Get-Content -LiteralPath (Join-Path $Root "KhaosAdminDeck\Scripts\main.lua") -Raw
foreach ($marker in @(
    'RegisterConsoleCommandHandler("knadmin"',
    'RegisterKeyBind(Key.F9',
    'controller:EnterChat_Receive(message)',
    'action == "auth"',
    'action == "shutdown"'
)) {
    if (-not $main.Contains($marker)) {
        throw "Lua source missing marker: $marker"
    }
}

$ui = Get-Content -LiteralPath (Join-Path $Root "KhaosAdminDeck\UI\KhaosAdminDeckUI.ps1") -Raw
if (-not $ui.Contains("KHAOS ADMIN DECK")) {
    throw "UI source is incomplete."
}

Write-Host "Package validation passed." -ForegroundColor Green
