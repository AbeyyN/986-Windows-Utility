# Security Policy

986 Windows Utility changes Windows configuration and therefore treats security and rollback defects as high priority.

## Supported versions

Only the latest public release is actively supported during the alpha stage.

## Reporting a vulnerability

Do **not** open a public GitHub issue for a vulnerability that could enable privilege abuse, unsafe command execution, persistence, destructive rollback or supply-chain compromise.

Report privately through GitHub's security reporting facilities when enabled, or contact the maintainer through the public profile contact channel.

Include: affected version, Windows version/build, reproduction steps, impact, logs with secrets removed, and any proposed fix.

## Scope

Security reports include unsafe elevation, command injection, untrusted remote code execution, broken snapshot/undo behaviour, insecure update/bootstrap behaviour and sensitive-data leakage.

Never include passwords, tokens, private keys or personal data in reports.