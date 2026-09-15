# Roadmap

**Current stable:** `v0.8.1`

## v0.1.x — Foundation (shipped)

- stabilize WPF shell and reversible registry engine
- expand static validation and release packaging
- document shipped tweaks and side effects
- establish snapshot integrity and recovery behavior

## v0.2 — Tweak Intelligence (shipped)

- read-only Registry, Policy, Service and Scheduled Task observations
- classify states as Windows-like, 986 Managed, WinUtil-like, Custom or Unknown
- JSON export and headless audit mode
- never claim exact tool attribution without reliable evidence

## v0.3 — Diagnostics & Repair (shipped)

- Windows health dashboard
- system, storage, Defender, network and servicing diagnostics
- repair actions with preflight checks, confirmation and logs
- exportable privacy-hardened diagnostics report
- headless Doctor mode for CI and technician workflows

## v0.4 — Profiles (shipped)

- 986 Balanced selection profile
- 986 Performance selection profile
- conservative 986 Laptop profile
- 986 Technician visibility/troubleshooting profile
- user-defined local profiles
- profile actions remain selection-only; Apply/Undo stays explicit and reversible

## v0.5 — Windows Settings Expansion (shipped)

- keep 986 tweak-first; diagnostics/tooling remain secondary
- active tweaks use normal user-editable preference keys, not locking Policy paths
- migrate four v0.1-v0.4 Policy tweaks to legacy Undo-only compatibility
- add Taskbar, Start, Gaming and Personalization preference tweaks
- add CI proof that manual user overrides persist after 986 Apply
- expand compatibility/side-effect evidence before each new tweak ships

## v0.6 — Windows Tweaks Expansion Wave 2 (shipped)

- audit the WinUtil tweak catalog as reference, not as source-of-truth behavior
- ship only ordinary Windows preferences that remain manually user-editable
- add Accessibility, Taskbar, Multitasking and Storage preferences
- require real Windows Apply/Verify/Undo exact-original evidence before promotion
- keep all Wave 2 tweaks optional; do not silently change the 986 Balanced profile

## v0.7 — Storage View + Custom Resolution (shipped)

- optional `986 Storage` namespace under This PC using reversible per-user Shell registration
- out-of-process read-only storage scanner; no recursive scanning inside `explorer.exe`
- Android-style per-volume category breakdowns for Apps, Videos, Pictures, Documents, Audio, System, Other and Free
- responsive native Storage cards and real Scan / Refresh control inside File Explorer
- Custom Resolution driver test path using `CDS_TEST`
- 15-second Keep/Revert trial with automatic fallback and exact original-resolution Undo
- no EDID registry hacks, driver patching, watchdog enforcement or forced unsupported panel modes
- physical Windows validation for Storage registration/scanning and Resolution trial/revert/Keep/Undo before stable promotion

## v0.8.0 — Rose Gold Intelligence + Storage Intelligence P1 (shipped)

- official AbeyyTechXy branding and Rose Gold + Black + Orange visual system
- readable dark-theme profile/display dropdowns and corrected watermark z-order
- Storage Intelligence P1 with Top 10 largest files, Top 10 largest root folders, compact Top 3 previews and review-only recommendations
- width-driven Custom Resolution input with automatic aspect-ratio-preserving Height
- clear suitability guidance for external monitors/desktop displays and built-in laptop-panel limitations
- retain the driver test + timed reversible trial before keeping any display mode
- keep Storage Intelligence analysis/review-only with no automatic file deletion

## v0.8.1 — Storage Intelligence P2 + Update Center (shipped)

- live Storage scan progress with files, bytes, elapsed time and current folder
- scoped Cancel Scan that targets only the active 986 scanner process
- cache age/state for completed Storage scans
- safe largest-file, largest-folder and recommendation review actions
- JSON Storage report export to the user Documents folder
- 986 Update Center using the checksum-verified stable bootstrap path
- block in-place updates while the current Storage shell DLL is loaded; never force-restart Explorer
- corrected Storage branding composition with user-approved 25% Storage watermark opacity
- stable promotion only after Windows CI, native Storage build, physical scan/cancel validation, loaded-DLL update blocking and Explorer preview validation

## v1.0 — Stable Platform (planned)

- documented compatibility matrix across supported Windows versions and hardware classes
- mature rollback and disaster-recovery path for every supported mutation
- signed/reproducible release pipeline target
- stronger release provenance and binary-distribution architecture
- stable contributor, security and long-term maintenance process
- continue the Never-Lock User contract as a release invariant
