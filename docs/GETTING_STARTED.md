# Getting Started

## Requirements

- Windows 11 is the primary v0.3 target
- Windows PowerShell 5.1
- Administrator rights for system-wide policy changes

## Recommended first run

1. Review the source and release notes.
2. Launch 986 Windows Utility as Administrator.
3. Create a System Restore Point.
4. Press **986 Doctor** for a read-only health overview.
5. Press **Tweak Intelligence** for the read-only classification audit.
6. Press **Audit** to refresh target-state status.
7. Select individual tweaks or `986 Balanced`.
8. Press **Apply Selected** only after reviewing the list.
9. Re-run Audit and confirm expected states.

## Undo

Undo restores the original state captured by 986 before its first managed write. If no snapshot exists for a tweak, do not assume the tool can reconstruct a historical pre-986 state.

## Remote bootstrap

```powershell
irm https://raw.githubusercontent.com/AbeyyN/986-Windows-Utility/main/bootstrap.ps1 | iex
```

The bootstrap downloads the application to a local temporary directory before execution so normal elevation and file-based runtime behaviour remain available.
## Read-only CLI audit

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\986-Windows-Utility.ps1 -AuditOnly
```

Use `-AuditJson` to export a JSON report. See [INTELLIGENCE.md](INTELLIGENCE.md).

## Headless Doctor

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\986-Windows-Utility.ps1 -DoctorOnly
```

Use `-DoctorJson` to export a report. Repair buttons remain GUI-only and require explicit action. See [DOCTOR.md](DOCTOR.md).
