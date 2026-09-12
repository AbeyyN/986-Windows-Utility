# WinUtil Audit for 986 v0.6

Audit source: current `ChrisTitusTech/winutil` `config/tweaks.json`, reviewed 2026-09-12.

986 uses WinUtil as a reference catalog only. A WinUtil tweak is not copied automatically; it must also satisfy the 986 Never-Lock and exact-Undo contract.

## Accepted for Wave 2

| 986 tweak | WinUtil reference | Why accepted |
|---|---|---|
| always-show-scrollbars | Scrollbars Always Visible | normal HKCU accessibility preference; manual Settings toggle exists |
| show-battery-percentage | System Tray Battery Percentage | normal HKCU preference; manual Power & battery toggle exists |
| center-taskbar | Taskbar Centered Icons | normal HKCU preference; manual Taskbar alignment control exists |
| enable-window-snapping | Window Snapping | normal HKCU preference; manual Multitasking toggle exists |
| disable-storage-sense | Storage Sense - Disable | normal HKCU preference; manual Storage Sense toggle exists |

All five passed real Apply -> Verify -> Undo exact-original round-trip testing on AbeyyN986, Windows 11 build 26200.

## Already covered by 986

File extensions, hidden files, Task View, taskbar Search, End task, dark theme preferences and several other current WinUtil preferences already map to shipped 986 tweaks.
## Deferred for a compound-tweak engine

- Mouse Acceleration: three related registry values must be treated as one transaction.
- File Explorer Home and Gallery removal: three values across shell namespace and Explorer preferences.
- Visual Effects - Best Performance: many coupled values and visible side effects.
- Game Mode compatibility: current WinUtil writes both `AllowAutoGameMode` and `AutoGameModeEnabled`; 986 v0.5 currently manages only `AutoGameModeEnabled`. This needs snapshot-schema-safe compound support rather than an ad-hoc second write.

## Rejected from Wave 2

- Start Menu Bing Search: no consistent current Windows Settings toggle to satisfy the manual-user-control rule.
- Sticky Keys `Flags`: bitmask can represent multiple sub-options; a blunt target can alter more than one user choice.
- Background Apps global disable: Windows 11 exposes per-app background controls rather than a stable global manual control.
- Widgets removal: current WinUtil removes AppX packages; that is not a normal reversible preference tweak.
- Policy, service, scheduled-task and privilege-workaround candidates: outside the v0.6 active preference baseline.

The acceptance filter remains: ordinary user preference, no persistent enforcement, exact snapshot/Undo, and real Windows validation before promotion.
