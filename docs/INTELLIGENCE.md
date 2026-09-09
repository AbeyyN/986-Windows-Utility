# 986 Tweak Intelligence

Tweak Intelligence is the read-only audit layer introduced in v0.2.0.

It inspects selected Windows Registry, Policy, Service and Scheduled Task states and classifies observations without changing those states.

## Classification model

| Classification | Meaning |
|---|---|
| `986 Managed` | 986 has an original-state snapshot for the tweak. |
| `WinUtil-like` | Current state matches a verified shared WinUtil signature. This is not proof WinUtil created it. |
| `Windows-like` | State looks compatible with Windows-managed/default behaviour. This is heuristic. |
| `Custom` | State is present but is not 986-managed and does not match a verified shared signature. |
| `Unknown` | State could not be read or the target object was not found. |

## Attribution rule

A matching registry value or service startup mode is a technical fingerprint, not provenance evidence.

986 must never claim that WinUtil, another tweak tool or a specific user created a state unless reliable provenance exists.

The v0.2 WinUtil-like signatures are deliberately narrow and are derived from settings present in the WinUtil configuration tracked in the separate `AbeyyN/winutil` fork.

## Headless audit

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\986-Windows-Utility.ps1 -AuditOnly
```

To also export JSON:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\986-Windows-Utility.ps1 -AuditOnly -AuditJson
```

Reports are written to the local `state` directory and are ignored by Git. Default reports omit the Windows username and computer name to reduce accidental disclosure when reports are shared.

## Safety boundary

The audit module may read system configuration and write its own JSON report file. It does not contain Registry mutation, Service mutation or Scheduled Task mutation commands.

Future versions may offer selected import/restore actions, but those actions must be separate from the read-only scanner and must follow the normal 986 snapshot, apply, verify and undo rules.
