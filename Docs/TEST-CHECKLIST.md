# Test Checklist

## UI-only preview

- [ ] Run `Tools/Preview-UI.cmd`.
- [ ] Confirm the panel opens with no console window left behind.
- [ ] Confirm all sections fit at 1920×1080 and 2560×1440.
- [ ] Confirm destructive buttons show confirmation prompts.
- [ ] Confirm the window can close normally.

## Palworld client test

- [ ] Back up the existing client mod folder.
- [ ] Install current UE4SS Experimental.
- [ ] Run `Tools/Install.ps1`.
- [ ] Start Palworld.
- [ ] Confirm `[KhaosAdminDeck] v0.2.0-preview loaded` appears in UE4SS output.
- [ ] Join the Nitrado server.
- [ ] Press F9.
- [ ] Confirm the badge changes from `CLIENT OFFLINE` to `CLIENT CONNECTED`.
- [ ] Authenticate using the real server admin password.
- [ ] Confirm `ADMIN ACTIVE`.
- [ ] Test `Server Info`.
- [ ] Test `Show Players`.
- [ ] Test `Save World`.
- [ ] Test a harmless broadcast.
- [ ] Test spectator mode only when your character is safe.
- [ ] Test player actions with a consenting second account.
- [ ] Do not test shutdown until the save and broadcast actions work.

## Report back

Include:

- Palworld version shown on the title screen
- UE4SS version
- Whether F9 opened the UI
- The last result text
- Relevant lines from `KhaosAdminDeck/ipc/activity.log`
- Any UE4SS error line
