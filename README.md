# 986 Windows Utility

**Optimize Â· Diagnose Â· Repair Â· Undo**

An open-source Windows utility by **AbeyyTechXy / AbeyyN** focused on safe, inspectable and reversible system tweaks.

[![Release](https://img.shields.io/github/v/release/AbeyyN/986-Windows-Utility?style=for-the-badge)](https://github.com/AbeyyN/986-Windows-Utility/releases/latest)
[![CI](https://img.shields.io/github/actions/workflow/status/AbeyyN/986-Windows-Utility/ci.yml?branch=main&style=for-the-badge&label=CI)](https://github.com/AbeyyN/986-Windows-Utility/actions)
[![License](https://img.shields.io/github/license/AbeyyN/986-Windows-Utility?style=for-the-badge)](LICENSE)
[![Contributors](https://img.shields.io/github/contributors/AbeyyN/986-Windows-Utility?style=for-the-badge)](https://github.com/AbeyyN/986-Windows-Utility/graphs/contributors)

> **Project status:** early public alpha. v0.1.0 establishes the reversible tweak engine and Windows-native WPF interface.

## Why 986 Windows Utility?

Most tweak scripts know the value they want to set. 986 Windows Utility also records what was there **before** the change.

```text
Detect current state â†’ Snapshot original state â†’ Apply â†’ Verify
                                              â†“
                             Undo â†’ Restore original â†’ Verify
```

This is the foundation of **986 State-Aware Reversible Tweaks**.
## v0.1.0 features

- Windows-native PowerShell 5.1 + WPF GUI
- 19 initial Explorer, Privacy and Performance tweaks
- `986 Balanced` preset
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

> Read the source before running system-modification tools. A restore point is recommended before the first tweak session.

## Safety model

A tweak is not considered complete merely because it can write a registry value. New tweak contributions are expected to define or document:

`Detect` Â· `Snapshot` Â· `Apply` Â· `Verify` Â· `Undo` Â· `Verify Undo` Â· risk Â· supported Windows versions Â· side effects.
## Project direction

The roadmap extends beyond a debloater into a Windows maintenance platform:

- **986 Tweak Intelligence Engine** â€” identify managed, WinUtil-like, custom and unknown states
- diagnostics and repair modules
- technician-oriented presets and tools
- richer tweak metadata and compatibility rules
- automated release validation

See [ROADMAP.md](ROADMAP.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Contributing

Issues, testing reports, documentation fixes and pull requests are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md). Security issues should follow [SECURITY.md](SECURITY.md), not a public issue.

## Relationship to Chris Titus Tech WinUtil

`986 Windows Utility` is an **independent original project**, not an official Chris Titus Tech product and not the user's WinUtil fork. WinUtil is an important reference and learning project; contributions to WinUtil should remain in the separate `AbeyyN/winutil` fork and go upstream through pull requests when appropriate.

## License

MIT. See [LICENSE](LICENSE).

---

Built and maintained by **AbeyyN / AbeyyTechXy**.
