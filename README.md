# Khaos Nexus Palworld Admin Panel

Client-side Palworld administration UI for legitimately authenticated server administrators.

## Test release

**Version:** `0.2.0-preview`  
**Target:** Palworld 1.0.x, Windows/Steam client  
**Server install:** None  
**Required:** UE4SS Experimental and the server's real `AdminPassword`

This release uses a red-and-black WPF overlay connected to a UE4SS Lua client mod. Press **F9** from Palworld to open it.

The project does not bypass Palworld permissions. Every action is sent through Palworld's existing authenticated admin-command route, and the server remains authoritative.

## Included UI actions

- Authenticate without saving the password
- Save world
- Show players
- Server information
- Broadcast
- Spectator toggle
- Kick, ban and unban
- Teleport to a player
- Bring a player to you
- Scheduled shutdown
- Confirmed emergency force-exit
- Activity and transport status

## Install

1. Install or enable **UE4SS Experimental (Palworld)**.
2. Download the release ZIP and extract it.
3. Run PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Tools\Install.ps1
```

For a custom Steam library:

```powershell
.\Tools\Install.ps1 -PalworldPath "D:\SteamLibrary\steamapps\common\Palworld"
```

4. Start Palworld.
5. Join your Nitrado server.
6. Press **F9**.
7. Enter the server's configured `AdminPassword`.
8. Test `Server Info`, `Show Players`, and `Save World` first.

The direct install location is:

```text
Palworld\Mods\NativeMods\UE4SS\Mods\KhaosAdminDeck
```

## Preview the UI without Palworld

Run:

```text
Tools\Preview-UI.cmd
```

Preview mode renders the interface but cannot execute commands.

## Console fallback

Open the UE4SS console and run:

```text
knadmin help
knadmin ui
knadmin status
knadmin auth <password>
knadmin save
knadmin players
knadmin info
knadmin broadcast <message>
```

## Safety

Kick, ban, shutdown and forced exit require a confirmation dialog. Raw commands are disabled by default in `Scripts/config.lua`.

## Known limitation

`Show Players` and `Server Info` are official Palworld commands whose detailed output is still shown by Palworld itself. This preview does not yet scrape the game's chat response into a native player table.

See `Docs/TEST-CHECKLIST.md` and `Docs/TROUBLESHOOTING.md`.
