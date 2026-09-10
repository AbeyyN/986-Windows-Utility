# Architecture

## v0.5 runtime

986 Windows Utility is a Windows PowerShell 5.1 + WPF tweak utility. The **primary product surface is Windows settings/tweaks**; Tweak Intelligence, Doctor and Profiles support that core rather than replace it.

The active v0.5 catalog contains normal user preference tweaks only. Four historical Policy tweaks remain as legacy Undo-only definitions for snapshot compatibility.

## Core state model

For every managed tweak the engine evaluates current Windows state, records the exact original value before the first managed change, writes the target state, then verifies the result.

Apply is one-shot. There is no background enforcement loop. If the user later changes the same preference manually, 986 leaves that manual value alone.

Undo uses the recorded original state. If the original registry value did not exist, Undo removes the value instead of inventing a Windows default.

## Current components

- `986-Windows-Utility.ps1` — active/legacy tweak metadata, state engine and WPF shell
- `modules/TweakIntelligence.ps1` — read-only classification, report export and Intelligence UI
- `modules/Doctor.ps1` — secondary health diagnostics and explicit repair actions
- `modules/Profiles.ps1` — selection-only tweak profiles; never applies changes
- `Start-986-Windows-Utility.cmd` — local launcher
- `bootstrap.ps1` — downloads the application/modules locally before execution
- `state/` — local runtime state; never committed
- `tests/NoLock.Tests.ps1` — rejects locking Policy paths from the active tweak catalog
- `tests/PreferenceOverride.Tests.ps1` — proves a manual user override persists after Apply
## Design constraints

1. No automatic system modification on application launch.
2. Managed changes require explicit user action.
3. Active tweaks must remain user-editable after Apply; no watchdog, timer or automatic re-apply.
4. Active tweak catalog must not use a Group Policy path when it would enforce/lock a Windows setting.
5. Historical Policy tweaks are compatibility-only and `ApplyAllowed=false`.
6. Original state must be captured before the first managed write.
7. Apply and Undo must be verifiable.
8. Unknown or foreign state must not be silently labelled as a specific third-party tool.
9. High-risk changes require stronger review and compatibility evidence than low-risk preferences.
10. Doctor diagnostics never trigger repair automatically; system-changing repair actions require explicit confirmation and log output.

## Future split

As the catalog grows, tweak metadata and compatibility rules should move into dedicated data/modules while preserving the same one-shot preference and exact-Undo contract.