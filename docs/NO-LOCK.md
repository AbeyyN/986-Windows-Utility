# 986 Never-Lock User Baseline

986 Windows Utility is a Windows tweak utility first. A tweak may set a preference, but it must not take ownership of that preference away from the user.

## Locked rules

1. Active tweaks prefer normal user preference/state keys, not Group Policy enforcement.
2. Active tweak metadata must declare `UserEditable=$true` and `Enforcement='None'`.
3. Apply is one-shot. 986 has no timer, watcher, background service or scheduled re-apply loop.
4. After Apply, the user may change the same setting manually in Windows or Registry. 986 does not fight that change.
5. Undo restores the exact pre-986 value/type, or removes a value that did not exist before.
6. Profiles only select tweak checkboxes. Profiles never Apply automatically.
7. A tweak that requires a locking Policy path is not eligible for the normal active catalog.

## Legacy policy migration

v0.1-v0.4 shipped four Policy-based privacy tweaks. From v0.5 they are no longer applyable:

- `disable-activity-feed`
- `disable-publish-activity`
- `disable-upload-activity`
- `disable-consumer`

They remain defined only so existing snapshots can perform an exact Undo. A legacy row is shown only when an existing snapshot contains that tweak ID.

## CI proof

`tests/NoLock.Tests.ps1` rejects Policy paths or enforcement metadata in the active catalog.
`tests/PreferenceOverride.Tests.ps1` exercises the real Apply/Undo engine on an isolated HKCU test key, manually overrides the value after Apply, waits, and verifies the manual value remains unchanged until Undo.