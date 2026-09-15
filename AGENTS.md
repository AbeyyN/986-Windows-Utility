# 986 Windows Utility — Agent Execution Contract

Read this file and `WORKFLOW.md` before starting work in this repository.

## 1. Source of truth and recovery

- Do not restart the project from chat history.
- Inspect the repository, current branch, HEAD commit, releases/tags, CI state and relevant docs/tests before changing code.
- Internal maintainers must also read the canonical local `HANDOFF.md` when available in the authorized maintainer workspace. It is intentionally excluded from this public repository.
- Preserve the latest verified baseline and any current LOCK.
- Make the smallest reversible change that satisfies the task.
- Do not claim fixed, passed, deployed, released or verified without execution evidence.

## 2. Workflow authority

`WORKFLOW.md` is the public, versioned engineering workflow for this project. It defines lifecycle, branching/versioning, verification gates, release/deployment discipline, artifact handling, rollback/recovery, LOCK behavior and handoff rules.

If an internal operational runbook exists for an authorized maintainer environment, follow it without publishing private topology, host identifiers, credentials, private repository names, queue details or machine-specific operational data here.

## 3. Verification discipline

For code changes:

- inspect relevant source and callers first;
- run the narrowest useful tests while iterating;
- run the relevant full verification before completion;
- inspect command output and exit codes;
- verify the final branch/commit after writes;
- keep generated/binary build history out of Git source unless a file is intentionally tracked as source;
- require physical Windows validation when behavior depends on registry state, Explorer/Shell integration, display modes, native helpers or install/update behavior.

For risky Windows changes, perform preflight, preserve recovery/rollback, apply one bounded change, then verify resulting machine state.

## 4. Public repository boundary

This repository is public. Do not commit operational handoffs, logs, tokens, credentials, private paths, private hostnames, machine identifiers, generated local state or internal infrastructure routing details.

`HANDOFF.md` is specifically excluded from publication and is protected by `.gitignore` for maintainer workspaces.
