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
- [lib/outlook_report_hotkeys.ahk](lib/outlook_report_hotkeys.ahk) — report
  the selected mail through the ribbon's Report menu: `Alt+S` → Report Junk
  (KeyTip `Alt,H,R1,J`), `Alt+P` → Report Phishing (`Alt,H,R1,P`). Only
  active in classic Outlook's main window with a mail item selected (checked
  via COM: `ActiveWindow` is an Explorer, selection is a `MailItem`, no inline
  reply open), so not in calendar view or while composing a mail. The menu is
  opened and the item clicked via UI Automation (dropdown by AutomationId
  `ReportMenuButton_Dropdown`, item by its KeyTip), so it doesn't wait on
  Office's KeyTip timing. If the Report button isn't in the UIA tree because
  another ribbon tab is active, it selects the Home tab (AutomationId
  `TabMail`) first; if the button is still missing (ribbon collapsed) it
  falls back to sending the KeyTips. If the menu has no such item it shows a
  tooltip. After a report it clicks OK on Outlook's "Thanks for reporting"
  dialog (matched on that title only, so no confirmation dialog is ever
  answered automatically).
  - The COM mail check runs inside the hotkey, not in `#HotIf`: `#HotIf`
    runs in the keyboard hook, where COM calls to Outlook fail with
    `RPC_E_CANTCALLOUT_ININPUTSYNCCALL` (that caused a ping and no action).
    When the check fails, the key is passed through to Outlook (Alt+S stays
    Send in a compose window).
  - `ReportDryRun := true` (currently off): opens the menu and shows a
    tooltip naming the item it would click, without reporting anything, on
    every path including the KeyTip fallback. Turn it on when testing. `ReportDebugLog` logs every check to
    `%TEMP%\outlook_report_hotkeys.log`, plus every report step with the
    elapsed milliseconds.
  - Timeout (`ReportTimeoutMs`, 10 s): a UIA call once hung for ~33 s. Once
    the timeout passes, the report is aborted at the next step, before the
    click or the KeyTip fallback, and the menu is collapsed. A tray
    notification says that nothing was reported. A watchdog timer shows the
    notification even while a call is still hanging, because COM pumps
    messages while it waits. If the click itself is what hangs, the
    notification asks you to check whether the mail was reported.
- [lib/outlook_meeting_hotkeys.ahk](lib/outlook_meeting_hotkeys.ahk) —
  respond to the selected meeting request in classic Outlook's mail list:
  `A` accept and open the response to add a message (then Send yourself),
  `Ctrl+A` accept and send right away, `D` decline with message, `Ctrl+D`
  decline and send right away. Via Outlook COM
  (`GetAssociatedAppointment(true).Respond(3|4, true)` then `.Display()` or
  `.Send()`); afterwards the request is deleted from the Inbox, as Outlook's
  own buttons do. With an edited response (`A`/`D`) that only happens once
  the response is actually sent (`MeetingReplyWatcher` listens to the
  response item's `Send` event via `ComObjConnect`), so closing it without
  sending leaves the request in the Inbox. Only when the mail list itself has focus (focused control
  `OutlookGrid`, checked in `#HotIf` without COM so typing elsewhere isn't
  slowed down) and exactly one `IPM.Schedule.Meeting.Request` is selected;
  otherwise the key goes through (`Ctrl+A` = select all, `Ctrl+D` = delete).
  The same keys work in an open meeting window (title ends in
  ` - Meeting`): on an opened request, and on the calendar item of a meeting
  you were invited to (`MeetingStatus` = olMeetingReceived; there's no
  request to delete then). The window is closed after responding, like
  Outlook's own buttons do. A new meeting you're writing yourself has the
  same title, so a 300 ms timer (`CheckMeetingWindow`) classifies each newly
  active `- Meeting` window+title over COM in the background, and the keys
  only act in windows classified as a received meeting. (Checking in the
  hotkey itself dropped a/d keys typed while the COM call ran.) Outlook pads
  inspector titles with trailing spaces, hence the `RTrim`.
  - Declining (`D`) removes the appointment from the calendar right away,
    even if you then close the response without sending it.
  - A window left open while the item was answered elsewhere points to an
    item that no longer exists; responding then fails with a tooltip
    ("moved or deleted"). Reopen the item.
  `MeetingDryRun := true` shows a tooltip instead of responding.
  - Can't be tested end to end with an invite to yourself: Exchange moves
    a request sent to its own organizer straight to Deleted Items, and the
    organizer can't respond to it.
- [lib/word_table_hotkeys.ahk](lib/word_table_hotkeys.ahk) — Word table
  chords starting with `` Ctrl+` `` (Ctrl may stay held): `C` inserts a
  column to the right, `R` a row below, `D, C` deletes the current
  column(s), `D, R` the current row(s). Done via Word COM
  (`Selection.InsertColumnsRight`, `InsertRowsBelow`, `Columns/Rows.Delete`).
  Only when the cursor is in a table (`Selection.Information[12]`; note the
  square brackets, it's a parameterized property); otherwise `` Ctrl+` `` is
  passed through to Word, where it's the grave-accent prefix (`` Ctrl+`, E ``
  = è). The follow-up keys are swallowed and time out after 2 s.
- [lib/word_caption_hotkeys.ahk](lib/word_caption_hotkeys.ahk) — Word
  `Ctrl+Shift+C`: Insert Caption when a picture/shape is selected
  (`Selection.Type` 7/8), otherwise Insert Cross-reference. It only sends
  keys; the dialogs come from Word key bindings in `Normal.dotm` (calling
  `Dialogs().Show` over COM would block the script while the dialog is open).
  Those bindings live in Word, not in this repo (File > Options > Customize
  Ribbon > Keyboard shortcuts):
  - `Ctrl+Shift+C` → `InsertCrossReference`
  - `Ctrl+Alt+Shift+C` → `InsertCaption` (used by the script)
  - `Ctrl+Shift+P` → `InsertPicture` (replaces Font Size)
  - `Ctrl+Shift+T` → `TableInsertTable` (replaces Unhang)
  - `Ctrl+Shift+F` → `InsertFootnote`
- [lib/utilities.ahk](lib/utilities.ahk) — shared helpers: exe path lookup
  (`FindExeLocations`, searches the folders listed in `paths.ini`),
  `ActivateOrRun`/`OnlyRun`, `CloseAllWindows`.
- [paths.ini](paths.ini) — search roots used by `FindExeLocations` to locate
  the executables in `exeList` (in `launch_programs.ahk`). Environment
  variables (`%USERPROFILE%`, `%LOCALAPPDATA%`, `%PROGRAMDATA%`, …) are
  expanded by `ExpandEnvVars`. Notion isn't in `exeList`: Win+N uses
  `%LOCALAPPDATA%\Programs\Notion\Notion.exe` if that exists (regular
  per-user install), otherwise the Store (MSIX) app via its AppUserModelID
  (`shell:AppsFolder\com.notion.app.desktop.notion_…!…`), since Store apps
  under `WindowsApps` can't be searched or run directly.

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
- **Resilient log writes**: `LogSegment` retries `FileAppend` (5x, 200ms
  apart) before giving up, and falls back to `window_log_<yyyy-MM>_failed.txt`
  if the main log is still locked. See the fix below for why this matters.

### Fixed: a locked log file could permanently wedge the tracker (2026-09-10)

The log file lives on a OneDrive-synced Desktop, and OneDrive briefly locks
a file mid-sync. `FileAppend` in `LogSegment` had no error handling, so a
sharing-violation on one write threw an uncaught exception *before*
`CheckWindow` updated `lastKey` — meaning every later tick kept trying (and
failing) to log that same stale segment, and no new segment ever got
recorded again. Observed 2026-09-10: tracking silently stopped for 90+
minutes after one such error; the process was still running, just
permanently stuck.

Fixed with `AppendWithRetry` (retry + side-file fallback, see above) so a
transient lock can no longer take down the tracker. Verified by holding an
exclusive lock on the log file with a test script: the write no longer
throws, falls back to the `_failed` file while locked, and resumes writing
to the real log automatically once the lock is released — no restart
needed.

### Fixed: `GetUIAProp` crashed on elements without a name (2026-10-29)

UIA returns a `VT_BSTR` with a null pointer for an empty Name, and
`StrGet(0)` throws. `GetUIAProp` now checks the pointer first. Found while
inspecting the Outlook ribbon; the same crash could also hit `GetBrowserURL`.

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
