# 986 Doctor

986 Doctor is the diagnostics and repair layer introduced for v0.3.

## Health dashboard

The Doctor report is read-only and currently observes:

- Windows version and build
- CPU snapshot and uptime
- memory availability
- system-drive free space
- pending reboot indicators
- Windows Update, BITS, Defender and Firewall service states
- Microsoft Defender protection state when available
- active IPv4 adapter, gateway and DNS
- Microsoft TCP/443 connectivity

A stopped service is not automatically treated as broken. Windows may start or stop services on demand.

## Status model

- `GOOD` - observed state passes a conservative health rule
- `ATTENTION` - a condition deserves review
- `INFO` - observed state without a failure judgment
- `UNKNOWN` - the signal could not be read reliably

## Repair actions

v0.3 exposes explicit actions for:

- DISM CheckHealth
- DISM ScanHealth
- DISM RestoreHealth
- SFC `/scannow`
- DNS cache flush
- Winsock reset

No repair runs during application launch, Doctor refresh, report export, or headless Doctor scan.

## Preflight and confirmation

Repair preflight checks administrator rights, executable availability, free system-drive space, pending reboot state and repair-source connectivity where relevant.

Actions marked as system-changing require a confirmation dialog before a child repair console starts. Each repair console writes its output to a timestamped log under the local `state/` directory.

Winsock reset is marked as restart-recommended. DISM RestoreHealth may require access to Windows Update or another configured repair source.

## Privacy

Exported Doctor reports include technical health observations, version and OS build. They intentionally omit the Windows username and computer name so reports are safer to attach to public issues.

## Microsoft servicing sequence

For corruption repair, Microsoft documents DISM RestoreHealth followed by System File Checker. 986 Doctor keeps those as separate explicit actions so the user can review preflight state and output between stages.
