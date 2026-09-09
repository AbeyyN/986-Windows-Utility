# Architecture

## v0.3 runtime

986 Windows Utility v0.3 is a Windows PowerShell 5.1 application with a WPF interface, a read-only Tweak Intelligence module and a separate 986 Doctor diagnostics/repair module. It intentionally has no external runtime dependency beyond components present on supported Windows installations.

## Core state model

For every managed tweak the engine evaluates the current Windows state, records the original value before the first managed change, writes the target state, then verifies the result.

Undo uses the recorded original state. If the original registry value did not exist, Undo removes the value instead of inventing a Windows default.

## Current components

- `986-Windows-Utility.ps1` — application, tweak metadata, state engine and WPF shell
- `modules/TweakIntelligence.ps1` — read-only classification, report export and Intelligence UI
- `modules/Doctor.ps1` — health diagnostics, repair preflight, explicit repair launchers and Doctor UI
- `Start-986-Windows-Utility.cmd` — local launcher
- `bootstrap.ps1` — remote bootstrap that downloads the application to a local temporary path before execution
- `state/` — local runtime state; never committed
- `tests/Static.Tests.ps1` — non-destructive repository validation

## Design constraints

1. No automatic system modification on application launch.
2. Managed changes require explicit user action.
3. Original state must be captured before the first managed write.
4. Apply and Undo must be verifiable.
5. Unknown or foreign state must not be silently labelled as a specific third-party tool.
6. High-risk changes require stronger review and compatibility evidence than low-risk preference changes.
7. Doctor diagnostics never trigger repair automatically; system-changing repair actions require explicit confirmation and log output.

## Future split

As the project grows, tweak metadata, engine logic, diagnostics, UI and presets will move into separate modules while preserving a small auditable bootstrap layer.