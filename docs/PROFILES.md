# 986 Profiles

Profiles are **selection presets**, not a second tweak engine.

Selecting a profile only checks or unchecks tweak rows in the main 986 Windows Utility interface. No registry, service, task, package, repair or network change occurs until the user explicitly presses **Apply Selected**.

Apply and Undo continue to use the existing state-aware reversible workflow:

`Detect -> Snapshot actual original -> Apply -> Verify -> Undo -> Restore exact original -> Verify Undo`

## Built-in profiles

### 986 Balanced

General-purpose recommended selection. It intentionally matches every tweak currently marked `Balanced=$true` in the main tweak inventory.

### 986 Performance

Balanced plus the current low-risk performance-oriented tweak set, including Xbox/Game DVR capture disable.

### 986 Laptop

Conservative laptop-oriented selection. It currently avoids optional Game DVR and Explorer startup-delay tuning. Battery/power-plan tuning is not added until it has the same reversible safety model.

### 986 Technician

Visibility and troubleshooting convenience for repair/technician workflows, including file extensions, hidden files, This PC, taskbar End task and selected suggestion/noise reductions.

## Custom profiles

A custom profile stores only:

- profile name;
- selected tweak IDs;
- created/updated timestamps.

Custom profile data is stored in `state/profiles.json` and is excluded from Git. It does **not** store registry values or replace `state/original-state.json`.

Profile names are restricted to 1-40 characters and built-in names are reserved.

## Safety rules

1. Profile selection never calls Apply or Undo.
2. Built-in profiles reference existing tweak IDs only.
3. Unknown/missing tweak IDs are ignored by the UI and reported in the activity log.
4. Custom profile persistence never writes Windows system state.
5. Built-in profiles cannot be overwritten or deleted.
6. Apply/Undo remains explicit and continues through the existing snapshot + verification engine.
