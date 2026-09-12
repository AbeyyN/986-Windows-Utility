# Roadmap

## v0.1.x — Foundation

- stabilize WPF shell and reversible registry engine
- expand static validation and release packaging
- document every shipped tweak and side effect
- improve snapshot integrity and recovery messages

## v0.2 — Tweak Intelligence (shipped)

- read-only registry, policy, service and scheduled-task observations
- classify states as Windows-like, 986 Managed, WinUtil-like, Custom or Unknown
- JSON export and headless audit mode
- never claim exact tool attribution without reliable evidence
- next v0.2.x: confidence metadata and broader signature coverage

## v0.3 — Diagnostics & Repair (implemented)

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

- audit current WinUtil tweak catalog as reference, not as source-of-truth behavior
- ship only ordinary Windows preferences that remain manually user-editable
- add Accessibility, Taskbar, Multitasking and Storage preferences
- require real Windows Apply/Verify/Undo exact-original evidence before promotion
- keep all new Wave 2 tweaks optional; do not silently change the 986 Balanced profile

## v1.0 — Stable

- documented compatibility matrix
- mature rollback and recovery path
- signed/reproducible release pipeline target
- stable contributor and security process