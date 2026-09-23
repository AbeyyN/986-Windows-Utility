<!-- CANONICAL_986_FASTOPS_FLOW_20260923 -->
## CURRENT CANONICAL INFRA / EXECUTION FLOW — 2026-09-23

**PRECEDENCE:** This remark overrides older operational host-routing assumptions while preserving historical records.

- **Sole active server:** `986`.
- Active aliases for that same server: `986`, `minilab`, `ryzen`, `ryzen 7`, `4700g`, `server`, `miniserver`, `sole server`, `sole 986`.
- `redmi` / `Redmi Build`, `986-server`, `fujitsu`, `pi`, `raspi`, `Raspberry Pi`, and `rapsi-nas` are **RETIRED / NON-EXISTENT as active server targets**. Older references remain historical only.
- **Execution priority:** `986 FastOps` is the **PRIMARY executor**. `SentinelX` is **EMERGENCY FALLBACK / STANDBY only** when FastOps is unavailable, blocked, or recovery explicitly requires it.
- New server-side routing, storage, build, deploy, backup, service ownership, and handoff assumptions resolve to `986`.
- This does not rename routers, APs, workstations, phones, or other explicitly identified edge/client devices.
- Preserve historical records; do not rewrite old host names.

<!-- CANONICAL_986_FASTOPS_FLOW_20260923 -->

# 986 Windows Utility — Project Workflow

This file defines the public, versioned engineering workflow for 986 Windows Utility. It applies to maintainers, agents and contributors.

## 1. Session bootstrap and source of truth

Before changing the project:

1. Read `WORKFLOW.md`, `AGENTS.md`, relevant architecture/docs and current tests.
2. Inspect repository status, current branch, HEAD commit, tags/releases and CI evidence.
3. Internal maintainers must also read the canonical local `HANDOFF.md` when it is available in the authorized maintainer workspace. `HANDOFF.md` is intentionally not published because this repository is public.
4. Verify the existing stable/LOCK baseline before modifying behavior.
5. Treat chat history as context, not as the project source of truth.

State precedence is: verified repository + canonical internal handoff + verified runtime state, then versioned workflow/docs/tests, then current instructions that do not conflict with a verified LOCK.

Do not claim `VERIFIED`, `FIXED`, `DEPLOYED`, `RELEASED`, `LOCKED` or `SUCCESS` without execution evidence.

## 2. Project lifecycle

Use this lifecycle for meaningful work:

`Recover state → Inspect → Decide → Branch → Implement → Narrow test → Full relevant verification → PR/CI → Physical Windows gate when required → Merge → Release/deploy when required → Artifact/checksum verification → Handoff update`

Do not restart the project or recreate existing infrastructure when a verified state already exists. Prefer the smallest reversible change that satisfies the requirement.

## 3. Branching, commits and versioning

- `main` is the stable integration baseline.
- Work from the latest verified `main` unless a documented release branch requires otherwise.
- Use focused branches such as `feature/*`, `fix/*`, `docs/*`, `infra/*` or `ops/*`.
- Keep diffs small, reviewable and reversible. Avoid unrelated cleanup in functional patches.
- Use concise imperative commit messages.
- Preserve semantic versioning already used by the project (`vMAJOR.MINOR.PATCH`).
- A version/tag must match the application `$Version` value before release.
- Never rewrite a released tag or silently alter a LOCKed baseline.

A discussion is not approval. Track decision state explicitly where relevant: `PROPOSED`, `NEED DECISION`, `APPROVED`, `REJECTED`, `CANCELLED`, `IN PROGRESS`, `BLOCKED`, `VERIFIED`, `LOCKED`, `SUPERSEDED`, `ROLLED BACK`.

## 4. Core product safety contract

986 Windows Utility is state-aware and reversible. A normal active tweak must implement or document:

`Detect → Snapshot original state → Apply → Verify → Undo → Verify Undo`

The **Never-Lock User** contract is mandatory:

- Apply is a one-shot preference change.
- The user must remain free to change the setting later through normal Windows controls or another legitimate tool.
- Do not use watchdogs, scheduled re-apply, event subscriptions, persistent services or policy enforcement to force a normal tweak state.
- Prefer ordinary user preference/configuration state over Group Policy paths.
- A normal tweak without a credible rollback path is not acceptable.
- Legacy Policy compatibility may remain Undo-only where required to restore old snapshots.

## 5. Feature-specific safety rules

### Tweak engine

Every new active tweak must define ID, category, risk, supported Windows versions, target state, detection, snapshot behavior, apply, verification, undo, undo verification, reboot requirement and known side effects.

### Profiles

Profiles are selection-only. Selecting a profile must never automatically Apply or Undo tweaks.

### 986 Doctor

Diagnostics should be read-only by default. Repair actions require preflight, explicit user intent, bounded execution, logs/result inspection and post-repair verification.

### 986 Storage

- Recursive scanning stays out of `explorer.exe`; use the out-of-process scanner.
- Storage review/export is non-destructive. Do not introduce automatic file deletion.
- Shell registration must remain reversible and collision-aware.
- Do not force-restart Explorer to complete an update while the Storage shell DLL is loaded.

### Custom Resolution

- Preserve the safe trial/confirmation/revert model.
- Driver/Windows mode validation is required before keeping a mode.
- Preserve exact original resolution state for Undo.
- Width-driven custom sizing must preserve the intended aspect ratio where that behavior is active.
- Do not use EDID registry hacks, driver patching, watchdog enforcement or forced unsupported panel modes.

### Update Center / bootstrap

- Stable updates must be integrity checked before installation.
- Preserve local user state across updates.
- Fail closed on missing/invalid checksum or incomplete package.
- Current production bootstrap behavior is a deployed runtime dependency; changing bootstrap routing/distribution requires explicit verification and must not be inferred only from repository config.

## 6. Testing and verification

During iteration run the narrowest useful tests first. Before merge, run the full relevant suite.

The repository CI currently validates, as applicable:

- encoding/static rules;
- Tweak Intelligence audit;
- Doctor;
- Profiles;
- Never-Lock behavior and user preference override;
- Wave 2 and single-selection behavior;
- Custom Resolution;
- Storage scanner, registration and shell;
- GUI smoke/headless modes;
- native Storage/Resolution build outputs where release packaging requires them.

At minimum for ordinary tweak work, keep `Static.Tests.ps1`, `NoLock.Tests.ps1` and `PreferenceOverride.Tests.ps1` passing.

A CI pass is not automatically sufficient for hardware/Windows-shell behavior. Require a physical Windows verification gate when a change affects registry state, Explorer/Shell integration, native helper binaries, display modes, install/update behavior, or any behavior whose correctness depends on the actual Windows environment.

Record exact test/run evidence in the internal handoff after meaningful work.

## 7. Pull request and merge workflow

- Open a PR from the focused work branch to `main`.
- Explain behavior changed, safety impact, tests and rollback/recovery path.
- CI must pass before stable promotion.
- If physical Windows validation is required, record that evidence before merge/release.
- Do not merge unresolved safety regressions or a change that contradicts a current LOCK without explicit approval.
- After merge, verify final `main` HEAD rather than assuming the expected commit was produced.

## 8. Release workflow

A stable release requires all of the following:

- application version and tag agree;
- full release validation passes;
- required native payloads build successfully;
- package contents are validated after packaging;
- SHA-256 is generated and independently checked against the authoritative artifact;
- release/runtime install path is exercised when the change affects installation or updating;
- internal handoff is updated with tag, commit, tests, artifact and checksum.

Existing GitHub Release binary assets are currently part of the bootstrap distribution path. They must not be removed or changed casually. The long-term binary distribution model is an explicit architecture decision because project governance treats GitHub primarily as source/version/CI rather than the authoritative binary-history archive.

## 9. Artifact handling

- Generated binary/build history must not be committed into the source tree.
- The maintainer artifact store is authoritative for full artifact history; exact internal host/path details are intentionally not published in this public repository.
- Keep stable `latest`, archived releases, experiments and release metadata logically separated.
- Every promoted artifact must be traceable to an exact verified commit and include version/build metadata and checksum when applicable.
- A secondary storage/service may hold the latest distributable copy, but it is not the authoritative full-history archive.
- Cloud deployment is a deployment surface, not an artifact archive.

## 10. Deployment workflow

For the public bootstrap endpoint:

1. Verify current live behavior before changing configuration.
2. Preserve the working production route until replacement behavior has been tested.
3. Deploy only from a verified source commit/configuration.
4. Validate HTTP status/redirect/content and perform the relevant bootstrap/install smoke test.
5. Record exact runtime evidence and rollback target in the internal handoff.

Do not assume repository infrastructure files prove the currently deployed runtime state; inspect the live endpoint.

## 11. Rollback and recovery

Before risky changes, establish the recovery path. Use the project's existing mechanisms where applicable:

- original-state snapshots and exact Undo for tweaks;
- 15-second trial/revert and original resolution restoration for display changes;
- reversible Storage shell registration;
- checksum-verified reinstall/update while preserving local state;
- previous verified commit/tag/artifact for source or release rollback.

A rollback must itself be verified. Record `ROLLED BACK` rather than claiming the original change succeeded.

## 12. LOCK behavior

A `LOCKED` item is a protected baseline, not a suggestion.

- Do not change a LOCKed feature/UI/workflow/value without explicit user approval.
- A new proposal affecting a LOCKed item is `NEED DECISION` until approved.
- Implementation does not imply verification; verification does not imply LOCK.
- If a later approved decision supersedes a LOCK, preserve the old history and record the transition as `SUPERSEDED` or `ROLLED BACK` as appropriate.

## 13. Handoff behavior for this public repository

The project has exactly one canonical `HANDOFF.md` in the authorized maintainer workspace. Because the repository is public:

- `HANDOFF.md` must never be pushed to GitHub;
- `.gitignore` must protect it from accidental publication;
- do not create `HANDOFF-v2.md`, dated handoffs, release handoffs or per-chat handoffs;
- update the existing file after every meaningful activity;
- keep its top status current and append timestamped history below it;
- unresolved ideas remain `NEED DECISION`; uncertain reconstruction remains `UNVERIFIED`;
- never delete old history to make the file shorter.

Public documentation should contain only project-safe workflow information. Internal topology, private paths, credentials, machine-specific identifiers, operational queue details and private notes belong only in authorized internal state, never in this public repository.

## 14. After every meaningful activity

Update source/docs as needed, test, verify the result, and then update the canonical internal handoff with timestamp, decision state, branch/commit, tests/results, deployment/artifact evidence, known issues and next action. Commit public repository changes only when the repository policy permits them.
