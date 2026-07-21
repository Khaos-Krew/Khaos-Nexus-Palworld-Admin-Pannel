param(
    [string]$PalworldPath = ""
)

$ErrorActionPreference = "Stop"

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

if ([string]::IsNullOrWhiteSpace($PalworldPath)) {
    throw "Provide -PalworldPath."
}

$Target = Join-Path $PalworldPath "Mods\NativeMods\UE4SS\Mods\KhaosAdminDeck"
if (Test-Path -LiteralPath $Target) {
    Remove-Item -LiteralPath $Target -Recurse -Force
    Write-Host "Removed $Target" -ForegroundColor Green
} else {
    Write-Host "Khaos Admin Deck was not installed at $Target"
}
