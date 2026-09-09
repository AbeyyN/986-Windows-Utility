# Changelog

All notable project changes are documented here.

## [0.2.0] - 2026-09-09

### Added

- read-only 986 Tweak Intelligence Engine
- Registry and Policy classification across all shipped tweaks
- shared WinUtil registry/service signature matching without provenance claims
- read-only service and scheduled-task observations
- JSON audit export
- headless `-AuditOnly` and optional `-AuditJson` modes
- dedicated Intelligence window in the WPF UI
- CI audit safety guard and headless smoke test

### Safety

The v0.2 audit path contains no Registry, Service or Scheduled Task mutation commands. `WinUtil-like` means a shared technical signature matched; it does not prove which tool created that state.

## [0.1.1] - 2026-09-09

### Added

- Windows 11 taskbar `End task` right-click tweak
- strict UTF-8 repository validation
- `.editorconfig` encoding and line-ending policy

### Fixed

- README mojibake sequences caused by incorrect character decoding
- normalized tracked text files to UTF-8

## [0.1.0] - 2026-09-08

### Added

- initial public PowerShell 5.1 + WPF application
- 19 Explorer, Privacy and Performance tweaks
- 986 Balanced preset
- original-state snapshot engine
- Apply verification and Undo verification
- live tweak status
- activity logging
- restore-point control
- public documentation, contribution policy, security policy and CI

### Safety

No tweak is applied automatically at startup. The user must explicitly select and apply changes.
