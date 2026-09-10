# Changelog

All notable project changes are documented here.

## [0.5.0] - 2026-09-10

### Added

- 9 user-editable Windows preference tweaks across Taskbar, Start, Gaming and Personalization
- Never-Lock User metadata and CI contract for all active tweaks
- real manual-override persistence test and single-selection regression test

### Changed

- four legacy Group Policy tweaks from v0.1-v0.4 are now undo-only and cannot be applied again
- built-in profiles now contain only ordinary user preferences; no active Policy enforcement

### Fixed

- selecting exactly one tweak no longer crashes Save Custom, Apply Selected or Undo Selected on Windows PowerShell 5.1

## [0.4.0] - 2026-09-10

### Added

- 986 Profiles selection-only preset engine
- built-in 986 Balanced, Performance, Laptop and Technician profiles
- local custom profile save/delete in `state/profiles.json`
- profile picker with Select Profile, Save Custom and Delete Custom controls
- headless `-ProfileList` mode
- WPF profile UI smoke validation and profile safety CI checks

### Safety

Profile selection only changes checkbox selection. It does not call Apply or Undo. Local validation on AbeyyN986 confirmed zero registry changes across all 20 tweak targets during GUI launch, built-in profile selection and custom profile save/delete.

## [0.3.0] - 2026-09-09

### Added

- 986 Doctor system health dashboard
- system, storage, servicing, Defender and network diagnostics
- pending reboot and repair-source connectivity signals
- privacy-hardened Doctor JSON report export
- headless `-DoctorOnly` and optional `-DoctorJson` modes
- DISM CheckHealth, ScanHealth and RestoreHealth actions
- SFC scan/repair, DNS flush and Winsock reset actions
- repair preflight, explicit confirmation and timestamped logs
- CI Doctor safety validation and headless smoke test

### Safety

Doctor refresh and report export are read-only. Actions that can change Windows state require explicit user selection and a confirmation dialog; no repair runs automatically.

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
