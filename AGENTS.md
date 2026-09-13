# 986 Windows Utility — Agent Execution Contract

Read this file before starting work in this repository.

## 1. Source-of-truth and recovery

- Do not restart the project from chat history. Inspect the repository, current branch, HEAD commit, releases/tags, CI state, and any existing handoff before changing code.
- Preserve the latest verified baseline. Make the smallest reversible change that satisfies the task.
- Do not claim fixed, passed, deployed, or verified without execution evidence.

## 2. Canonical execution routing

For Windows-host work, **Commander is not the primary path**.

Primary route:

```text
ChatGPT -> connected GitHub plugin -> AbeyyN/986-fastops private queue
        -> host-local 986 FastOps Queue -> FastOps Core -> target Windows host
```

For this project, the normal Windows target is `AbeyyN986` and the preferred lane is `project:986-windows-utility` (or a task-specific child lane).

When submitting a FastOps job, use the routing contract maintained in `AbeyyN/986-fastops`, especially `docs/CHATGPT-ROUTING.md`. A queued job uses strict JSON with the required routing fields (`target`, `kind`, `lane`, `argv`, `timeout_seconds`) and the `fastops:queued` label.

After submission, poll the queue issue until the job is claimed and reaches a terminal result. Treat only the returned execution result/log as proof of success.

## 3. Routing priority

Use this order unless the task itself requires a different surface:

1. **GitHub connector** — repository inspection, branches, commits, PRs, issues, CI/release metadata, and source changes.
2. **986 FastOps** — Windows shell, PowerShell, git, build, test, filesystem, packaging, and other host-local execution.
3. **986 EdgeBridge via FastOps** — browser interaction when the task genuinely requires Microsoft Edge.
4. **SentinelX** — infrastructure/server fallback when that target and operation are appropriate; it is not the normal Windows execution path for this repository.
5. **Remote Desktop Commander** — maintenance or exceptional GUI fallback only.

Do not stop, return a manual patch, or ask the user to restore Commander merely because Commander is offline when FastOps can perform the job.

## 4. Commander fallback rule

Use Commander only when the requested operation cannot be completed through GitHub, FastOps, or EdgeBridge and specifically requires interactive desktop control that those paths cannot provide.

Before falling back to Commander, record why the primary route is insufficient. Commander availability must never be used as the health signal for FastOps.

## 5. Verification discipline

For code changes:

- inspect relevant source and callers first;
- run the narrowest useful tests while iterating;
- run the relevant full verification before completion;
- inspect command output and exit codes;
- verify the final branch/commit after writes;
- keep generated/binary build history out of GitHub unless the repository explicitly tracks that file as source.

For risky Windows changes, perform preflight, preserve recovery/rollback, apply one bounded change, then verify the resulting machine state.
