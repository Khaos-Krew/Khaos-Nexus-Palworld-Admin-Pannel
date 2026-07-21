# Architecture

```text
WPF UI
  │
  ├── writes ipc/request.kad
  │
UE4SS Lua client mod
  ├── validates request
  ├── requires Palworld bAdmin for protected actions
  ├── submits an official slash command through EnterChat_Receive
  └── writes ipc/status.kad and ipc/activity.log
```

The password is sent from the UI to the local mod through a temporary request file. The mod deletes that file as soon as it reads it. It does not write the password to status or activity logs.

This is intentionally client-only. The Nitrado server receives the same authenticated Palworld command it would receive from manual in-game chat.
