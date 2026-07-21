# Troubleshooting

## F9 does nothing

Run `knadmin ui` in the UE4SS console.

Then verify:

```text
Palworld\Mods\NativeMods\UE4SS\Mods\KhaosAdminDeck\UI\Launch-Khaos-Admin-Deck.cmd
```

exists.

## UI says CLIENT OFFLINE

The overlay is open, but `status.kad` is not receiving a fresh heartbeat.

- Confirm Palworld is running.
- Confirm UE4SS loaded the mod.
- Confirm `Scripts/main.lua` is in the correct folder.
- Check `ipc/activity.log`.
- Check the UE4SS console for `[KhaosAdminDeck]`.

## Authentication stays inactive

- Confirm the Nitrado server has `AdminPassword` set.
- Confirm capitalization.
- Authenticate after joining the server.
- Wait two seconds for the admin flag to refresh.
- Try `/AdminPassword your-password` manually in Palworld chat.

## Command is submitted but has no effect

Try the equivalent official slash command manually. If the manual command also fails, this is a server/configuration issue rather than the UI.

## PowerShell is blocked

The launcher uses `-ExecutionPolicy Bypass` for this process only. Security software can still block PowerShell scripts. Review the source before allowing it.

## Duplicate or crashing UE4SS

Do not run both the official Workshop UE4SS installation and an older standalone UE4SS copy.
