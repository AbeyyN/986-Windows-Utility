# Changelog

All notable project changes are documented here.

## [0.7.0-rc.3] - 2026-09-13

### Fixed
- Fixed Custom Resolution Keep/Revert countdown state scoping so the DispatcherTimer always reaches the 15-second auto-revert deadline instead of stalling in a PowerShell event-handler child scope.
- Hardened native `986 Storage` Scan / Refresh dispatch after RC2 physical-machine testing proved the scanner binary was healthy but the Explorer button path did not launch it.
- Scan hit-testing now derives from the current Explorer client geometry instead of depending on a hitbox populated by a prior paint cycle.
- Promoted Scan / Refresh to a real owner-drawn child `BUTTON` control with `BN_CLICKED` dispatch, keyboard focus and resize-aware layout instead of relying only on parent-window mouse hit-testing.
- Scanner process launch now supplies the executable path and working directory explicitly and records Windows launch errors for the user-visible storage card.
- Fixed Win32 command-line quoting for fixed-drive roots such as `C:\`; trailing backslashes are no longer placed inside naive quotes that can corrupt scanner arguments.
- Reworked full-volume scanning onto one-pass Win32 `FindFirstFileExW` / `FindNextFileW` enumeration so file size comes directly from directory records instead of a separate managed `FileInfo` lookup per file.

### Validation
- RC2 official ZIP checksum, per-user COM registration, real File Explorer `986StorageViewWindow`, and responsive 374px-wide button geometry were verified on `AbeyyN986`.
- The RC2 scanner executable independently produced valid JSON on the same machine, isolating the failure to Explorer dispatch rather than scanner packaging or scan logic.
- The hardened shell contract and complete native Storage payload compile passed on the GitHub Windows runner before RC3 promotion.

## [0.7.0-rc.2] - 2026-09-13

### Fixed
- Made the native `986 Storage` renderer responsive to narrow real File Explorer content panes instead of forcing a 640px minimum card width.
- Storage category labels now adapt between 4, 2, or 1 columns and the `Scan / Refresh` control remains inside the visible card geometry.

### Validation
- RC1 physical-machine smoke testing on `AbeyyN986` proved per-user COM registration and a real `986StorageViewWindow` opened inside File Explorer, and exposed the narrow-pane Scan button regression before stable promotion.
- Added a regression guard that rejects the old forced 640px card layout.

## [0.7.0-rc.1] - 2026-09-13

- Added optional 986 Storage native File Explorer view with segmented per-drive storage categories.
- Added out-of-process storage scanner and reversible per-user This PC registration.
- Added 986 Custom Resolution driver trial engine with CDS_TEST, timed Keep/Revert and exact Undo.
- Preserved the 30 active tweak + 4 legacy Undo-only baseline and Never-Lock rule.

## [0.6.0] - 2026-09-12

### Added

- five optional user-editable Windows Settings tweaks: scrollbars, battery percentage, taskbar alignment, Snap windows and Storage Sense
- Wave 2 CI definition guard covering exact registry paths, values, types and targets
- documented manual Windows Settings path for every Wave 2 tweak

### Validation

- all five candidates passed real Apply -> Verify -> Undo exact-original round-trip testing on AbeyyN986, Windows 11 build 26200
- WinUtil current `config/tweaks.json` was used as a reference catalog; Policy, service, AppX and ambiguous/compound candidates were not copied into the active Wave 2 set

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
