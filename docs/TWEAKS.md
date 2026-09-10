# Shipped Tweaks

v0.5 catalog: **25 active preference tweaks** plus **4 legacy policy entries that are Undo-only**.

All active tweaks are one-shot Windows preferences: `UserEditable=true`, `Enforcement=None`. 986 does not keep re-applying a target after the user changes it manually.

| ID | Category | Name | Balanced |
|---|---|---|---|
| show-ext | Explorer | Show file extensions | yes |
| show-hidden | Explorer | Show hidden files | no |
| open-thispc | Explorer | Open File Explorer to This PC | yes |
| hide-recent | Explorer | Hide recent files in Quick Access | no |
| hide-frequent | Explorer | Hide frequent folders in Quick Access | no |
| disable-adid | Privacy | Disable advertising ID | yes |
| disable-tailored | Privacy | Disable tailored experiences | yes |
| disable-feedback | Privacy | Disable Windows feedback prompts | yes |
| disable-tips | Privacy | Disable Windows tips and suggestions | yes |
| disable-silentapps | Privacy | Disable silent suggested-app installs | yes |
| disable-pane-suggestions | Privacy | Disable Start/System pane suggestions | yes |
| disable-subscribed | Privacy | Disable subscribed suggestion content | yes |
| disable-lock-spotlight | Privacy | Disable rotating lock-screen Spotlight | no |
| startup-delay | Performance | Disable Explorer startup delay | yes |
| disable-game-capture | Gaming | Disable Xbox/Game DVR capture | no |
| taskbar-end-task | Taskbar | Enable taskbar End task | yes |
| hide-task-view | Taskbar | Hide Task View button | yes |
| hide-taskbar-search | Taskbar | Hide taskbar Search | yes || show-clock-seconds | Taskbar | Show seconds in system tray clock | no |
| start-more-pins | Start | Use more pins in Start | no |
| disable-start-recommendations | Start | Disable Start recommendations | yes |
| enable-game-mode | Gaming | Enable Game Mode | no |
| disable-transparency | Personalization | Disable transparency effects | no |
| dark-apps | Personalization | Use dark mode for apps | no |
| dark-system | Personalization | Use dark mode for Windows | no |

## Legacy Undo-only entries

These are retained only for users who have a pre-v0.5 original-state snapshot. They cannot be newly applied.

| ID | Previous behavior | v0.5 behavior |
|---|---|---|
| disable-activity-feed | Policy value | Undo-only |
| disable-publish-activity | Policy value | Undo-only |
| disable-upload-activity | Policy value | Undo-only |
| disable-consumer | Policy value | Undo-only |

`taskbar-end-task` enables the Windows 11 End task command; using End task can discard unsaved application work.

See [NO-LOCK.md](NO-LOCK.md) for the permanent user-control baseline. The source remains authoritative; compatibility and side-effect documentation will continue to tighten toward v1.0.