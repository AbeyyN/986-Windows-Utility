# Roadmap

## v0.1.x — Foundation

- stabilize WPF shell and reversible registry engine
- expand static validation and release packaging
- document every shipped tweak and side effect
- improve snapshot integrity and recovery messages

## v0.2 — Foreign Tweak Audit

- inventory relevant registry, policy, service and scheduled-task states
- classify states as Windows-like, 986-managed, WinUtil-like, custom or unknown
- review/import foreign state into a 986 baseline
- never claim exact tool attribution without reliable evidence

## v0.3 — Diagnostics & Repair

- Windows health dashboard
- network and update diagnostics
- repair actions with preflight checks and logs
- exportable diagnostics report

## v0.4 — Profiles

- 986 Balanced
- 986 Performance
- 986 Laptop
- 986 Technician
- user-defined profiles

## v1.0 — Stable

- documented compatibility matrix
- mature rollback and recovery path
- signed/reproducible release pipeline target
- stable contributor and security process