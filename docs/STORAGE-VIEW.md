# 986 Storage View

`986 Storage View` is an optional v0.7 Explorer integration. It does not replace the tweak-first core of 986 Windows Utility.

## Target experience

A `986 Storage` namespace entry appears under **This PC**. Opening it stays inside File Explorer and shows per-volume storage categories such as:

- Apps
- Videos
- Pictures
- Documents
- Audio
- System
- Other
- Free

The final view may render a segmented storage bar inspired by mobile storage views.

## Architecture

- `986StorageShell.dll`: small in-process COM/Shell glue and view host.
- `986StorageScanner.exe`: out-of-process, read-only scanner.
- cache/report data: generated on demand; no permanent background service.
- registration: per-user HKCU only.

The scanner must not run a recursive disk walk inside `explorer.exe`.

## CLSID

Immutable CLSID:

`{5FCCE720-D806-4B6A-A5F1-F060344FC88D}`

## Registration safety

The shell DLL does not export self-registration functions. Registration is performed by `storage/registration/Register-StorageView.ps1`.

Rules:

1. Never write HKLM for normal installation.
2. Refuse to overwrite a foreign CLSID/namespace owner.
3. `ThreadingModel` must be `Apartment`.
4. Remove only registration owned by 986.
5. Notify Explorer after install/remove.
6. No Explorer injection, binary patching, watchdog or Policy enforcement.

## Scanner safety

The scanner is read-only. Reparse-point directories are skipped to avoid traversal loops. Inaccessible files/directories are tolerated and counted/skipped instead of modified.

## Release gate

Real registration into `This PC` is not allowed until:

- native DLL compiles in Windows CI;
- scanner deterministic tests pass;
- registration collision tests pass;
- real-machine registration/Explorer smoke test passes;
- unregister leaves Explorer functional and removes only 986-owned state.
