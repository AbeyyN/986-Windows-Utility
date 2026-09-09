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

## v1.0 — Stable

- documented compatibility matrix
- mature rollback and recovery path
- signed/reproducible release pipeline target
- stable contributor and security process