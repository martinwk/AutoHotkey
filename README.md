# AutoHotkey Setup

Personal AutoHotkey v2 scripts: app-launcher hotkeys, Outlook shortcuts, and a
window/time tracker that logs activity for billing.

## Layout

- [main.ahk](main.ahk) — entry point, `#Include`s the scripts below from
  `%A_AppData%\ahk\lib\` (the *deployed* copy, not this repo directly — see
  Deployment).
- [lib/launch_programs.ahk](lib/launch_programs.ahk) — `Win+<key>` hotkeys to
  launch/activate apps (Everything, Firefox, Notion, PowerPoint, Spotify,
  Teams, VS Code, Word, Zotero), plus `Win+Q` (sleep), `Win+Shift+Q`
  (close all windows + scheduled shutdown), `Win+Shift+X` (close all
  windows), `Win+PrintScreen` → `Win+Shift+S`.
- [lib/track_window_log.ahk](lib/track_window_log.ahk) — window/time tracker,
  see below.
- [lib/outlook_hotkeys.ahk](lib/outlook_hotkeys.ahk) — Outlook `Ctrl+D`
  delete-after-right-click helper. **Currently disabled** (commented out in
  `main.ahk`).
- [lib/utilities.ahk](lib/utilities.ahk) — shared helpers: exe path lookup
  (`FindExeLocations`, searches the folders listed in `paths.ini`),
  `ActivateOrRun`/`OnlyRun`, `CloseAllWindows`.
- [paths.ini](paths.ini) — search roots used by `FindExeLocations` to locate
  the executables in `exeList` (in `launch_programs.ahk`).

## Window/time tracker (`track_window_log.ahk`)

Runs a 1-second timer (`CheckWindow`) that watches the foreground window and
appends a line to a log file whenever it changes. Each line is one segment:

```
<start> - <end> | <NNN> min | <process> | <detail> | <title>
```

- Log file: `%OneDrive Desktop%\window_log_<yyyy-MM>.txt` (one file per
  month, rolls over automatically).
- **Idle detection**: no keyboard/mouse input for 60s (`A_TimeIdlePhysical`)
  marks the segment idle. The idle boundary is backdated to when input
  actually stopped, not when the 60s threshold fired.
- **In-call detection**: while idle, if any app currently holds the
  microphone (per
  `HKCU\...\CapabilityAccessManager\ConsentStore\microphone`, see
  `GetMicUserApp`), the segment is logged as `InCall` (with the running
  Outlook calendar appointment as detail) instead of `Idle`. This only
  catches the moments Windows' consent store reports the mic as actively
  open — see the caveat below.
- **Locked session**: `Locked` while the workstation is locked
  (`WM_WTSSESSION_CHANGE`).
- **Outlook**: while active, the segment detail is the subject of the
  currently selected mail (classic Outlook only, via COM).
- **Browsers**: the active tab's URL is read once per segment via UI
  Automation (`GetBrowserURL`).
- **Office/Explorer documents**: the full file/folder path is read once per
  segment (`GetDocumentPath`) for Word, Excel, PowerPoint, Explorer.
- **Manual billing mark**: `Ctrl+Alt+Insert` prompts for a project name and
  appends a `MARK | <project>` line, so the importer can attribute
  subsequent segments to that project.

### Fixed: `InCall` never fired (2026-09-07)

Until 2026-09-07, `InCall` had never appeared in any log file, despite known
Teams calls happening during idle stretches. Root cause: `LastUsedTimeStop`/
`LastUsedTimeStart` in the consent store are `REG_QWORD` values, and
`RegRead()` on this AutoHotkey v2 build (2.0.19) throws `(1630) Data of this
type is not supported` on QWORDs — silently swallowed by `GetMicUserApp`'s
`try`, so it always returned `""`, for every app, not just Teams. Confirmed
live: during an active Teams call, `RegRead` on `MSTeams_8wekyb3d8bbwe`'s
`LastUsedTimeStop` threw that exact error while `idleMs` was well past the
60s threshold.

Fixed by reading the QWORD via `RegGetValueW` (`RegReadQWORD` in
`track_window_log.ahk`) instead of `RegRead()`. Verified against the same
live call: correctly returned `MSTeams`.

## Deployment

Nothing in this repo runs directly — `main.ahk` includes files from
`%A_AppData%\ahk\lib\`, a separate deployed copy. After editing, deploy with:

- [copy_ahk_to_startup.bat](copy_ahk_to_startup.bat) — copies `*.ini` to
  `%APPDATA%\ahk\`, `*.ahk` to `%APPDATA%\ahk\lib\` and the Startup folder,
  and `lib/` to `%APPDATA%\ahk\lib\` (source of truth for day-to-day use).
- [compile_and_copy.bat](compile_and_copy.bat) — compiles `main.ahk` to
  `autohotkey_main.exe` via the AutoHotkey `Ahk2Exe` compiler and copies it
  (plus `.ini`/`lib`) to Startup. Use only if the plain-script deployment
  doesn't seem to be picking up changes; the comment at the top of the file
  suggests falling back to the GUI compiler if this fails in debug mode.

See [CLAUDE.md](CLAUDE.md) for when these must be run.
