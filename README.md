# 986 Windows Utility

**Optimize · Diagnose · Repair · Undo**

An open-source Windows utility by **AbeyyTechXy / AbeyyN** focused on safe, inspectable and reversible system tweaks.

[![Release](https://img.shields.io/github/v/release/AbeyyN/986-Windows-Utility?style=for-the-badge)](https://github.com/AbeyyN/986-Windows-Utility/releases/latest)
[![CI](https://img.shields.io/github/actions/workflow/status/AbeyyN/986-Windows-Utility/ci.yml?branch=main&style=for-the-badge&label=CI)](https://github.com/AbeyyN/986-Windows-Utility/actions)
[![License](https://img.shields.io/github/license/AbeyyN/986-Windows-Utility?style=for-the-badge)](LICENSE)
[![Contributors](https://img.shields.io/github/contributors/AbeyyN/986-Windows-Utility?style=for-the-badge)](https://github.com/AbeyyN/986-Windows-Utility/graphs/contributors)

> **Project status:** v0.5.0-alpha.1 development line. 986 remains a tweak-first Windows utility; active tweaks are user-editable preferences with no persistent enforcement.

## Why 986 Windows Utility?

Most tweak scripts know the value they want to set. 986 Windows Utility also records what was there **before** the change.

```text
Detect current state → Snapshot original state → Apply → Verify
                                              ↓
                             Undo → Restore original → Verify
```

This is the foundation of **986 State-Aware Reversible Tweaks**.
## v0.5.0-alpha.1 development features

- Windows-native PowerShell 5.1 + WPF GUI
- **26 active user-editable preference tweaks** across Explorer, Privacy, Performance, Gaming, Taskbar, Start and Personalization
- **4 legacy Policy tweaks are Undo-only** for pre-v0.5 snapshots and cannot be newly applied
- **986 Profiles**: Balanced, Performance, Laptop and Technician built-ins
- user-defined custom profiles stored locally in `state/profiles.json`
- selecting a profile only changes checkbox selection; it never applies tweaks automatically
- **Never-Lock User baseline:** active catalog contains no Group Policy paths, Apply is one-shot, and manual Windows/Registry changes remain in control
- new Windows preference tweaks for Task View, Widgets, taskbar Search, tray-clock seconds, Start layout/recommendations, Game Mode, transparency and dark mode
- optional Windows 11 taskbar `End task` right-click action
  - Warning: ending a task can discard unsaved work in that application.
- **986 Tweak Intelligence Engine** with read-only Registry, Policy, Service and Scheduled Task observations
- cautious `986 Managed`, `WinUtil-like`, `Windows-like`, `Custom` and `Unknown` classifications
- JSON audit export and headless `-AuditOnly` mode
- **986 Doctor** health dashboard for system, storage, servicing, security and network signals
- Doctor preflight plus explicit DISM, SFC, DNS flush and Winsock repair actions
- timestamped repair logs and privacy-hardened Doctor JSON reports
- headless `-DoctorOnly` and optional `-DoctorJson` modes
- live `ACTIVE` / `NOT ACTIVE` / undo-aware status
- automatic original-state snapshots before managed changes
- Apply verification and Undo verification
- activity log and restore-point control
- UAC elevation on normal file launch

## Quick start

Run **Windows Terminal / PowerShell as Administrator**:

```powershell
irm https://raw.githubusercontent.com/AbeyyN/986-Windows-Utility/main/bootstrap.ps1 | iex
```

Or download the latest release from the GitHub Releases page and run `Start-986-Windows-Utility.cmd`.

Read-only audit from a cloned/release copy:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\986-Windows-Utility.ps1 -AuditOnly
```

Add `-AuditJson` to export the report into the local `state` directory.

Headless Doctor check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\986-Windows-Utility.ps1 -DoctorOnly
```

Add `-DoctorJson` to export a privacy-hardened Doctor report.

> Read the source before running system-modification tools. A restore point is recommended before the first tweak session.

## Safety model

A tweak is not considered complete merely because it can write a registry value. New tweak contributions are expected to define or document:

`Detect` · `Snapshot` · `Apply` · `Verify` · `Undo` · `Verify Undo` · risk · supported Windows versions · side effects.
## Project direction

The roadmap extends beyond a debloater into a Windows maintenance platform:

- expand safe Windows Settings tweak coverage first
- maintain the Never-Lock User rule for every active tweak
- expand Tweak Intelligence signatures and compatibility metadata
- keep diagnostics, profiles and technician workflows secondary to the tweak engine
- automated release validation

See [ROADMAP.md](ROADMAP.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/INTELLIGENCE.md](docs/INTELLIGENCE.md) and [docs/DOCTOR.md](docs/DOCTOR.md) and [docs/PROFILES.md](docs/PROFILES.md), [docs/TWEAKS.md](docs/TWEAKS.md) and [docs/NO-LOCK.md](docs/NO-LOCK.md).

## Contributing

Issues, testing reports, documentation fixes and pull requests are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md). Security issues should follow [SECURITY.md](SECURITY.md), not a public issue.

## Relationship to Chris Titus Tech WinUtil

`986 Windows Utility` is an **independent original project**, not an official Chris Titus Tech product and not the user's WinUtil fork. WinUtil is an important reference and learning project; contributions to WinUtil should remain in the separate `AbeyyN/winutil` fork and go upstream through pull requests when appropriate.

## License

MIT. See [LICENSE](LICENSE).

---

Built and maintained by **AbeyyN / AbeyyTechXy**.
