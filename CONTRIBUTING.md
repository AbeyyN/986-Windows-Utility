# Contributing to 986 Windows Utility

Thanks for helping improve the project. Small, reviewable changes are preferred.

## Before opening a pull request

1. Search existing issues and pull requests.
2. Explain what Windows state is changed and why.
3. Test on a disposable VM or test machine when possible.
4. Confirm the change can be detected, applied, verified and safely undone.
5. Confirm an active tweak remains user-editable after Apply; 986 must not continuously enforce it.
6. Never commit logs, tokens, private paths, machine identifiers or generated state files.

## Tweak acceptance standard

Every new active tweak should document: ID, name, category, risk, supported Windows versions, target state, detection method, snapshot/original-state behaviour, apply method, verification, undo, undo verification, reboot requirement and known side effects.

Active tweaks must prefer ordinary user preference/configuration state over Group Policy enforcement. They must not use a watchdog, scheduled re-apply, service, event subscription or other persistence mechanism to force the target value after Apply.

If a setting can only be implemented through enforcement that disables or greys out normal Windows controls, it should not be accepted as a normal active tweak without an explicit design review and separate UX.

A tweak without a credible rollback path should not be merged as a normal tweak.

## Never-Lock User contract

`Apply Selected` is a one-shot preference change. The user remains free to change that setting later through Windows Settings, Registry Editor or another legitimate tool. 986 must not silently change it back.

## Pull requests

Use a feature branch, keep the diff focused, update tests/docs when behaviour changes, and complete the PR checklist. Maintainers may ask for evidence from a clean Windows VM before merge.

## Commit style

Use concise imperative messages, for example: `Add reversible taskbar search tweak`.

## Development

Run at minimum:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Static.Tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\NoLock.Tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\PreferenceOverride.Tests.ps1
```
