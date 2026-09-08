# Contributing to 986 Windows Utility

Thanks for helping improve the project. Small, reviewable changes are preferred.

## Before opening a pull request

1. Search existing issues and pull requests.
2. Explain what Windows state is changed and why.
3. Test on a disposable VM or test machine when possible.
4. Confirm the change can be detected, applied, verified and safely undone.
5. Never commit logs, tokens, private paths, machine identifiers or generated state files.

## Tweak acceptance standard

Every new tweak should document: ID, name, category, risk, supported Windows versions, target state, detection method, snapshot/original-state behaviour, apply method, verification, undo, undo verification, reboot requirement and known side effects.

A tweak without a credible rollback path should not be merged as a normal tweak.

## Pull requests

Use a feature branch, keep the diff focused, update tests/docs when behaviour changes, and complete the PR checklist. Maintainers may ask for evidence from a clean Windows VM before merge.

## Commit style

Use concise imperative messages, for example: `Add reversible taskbar search tweak`.

## Development

Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Static.Tests.ps1` before submitting.