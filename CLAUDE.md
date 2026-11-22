# CLAUDE.md

## Deployment

After successfully testing a change, and in any case before/with every commit, run `copy_ahk_to_startup.bat` to deploy the scripts to the startup folder. **Every commit requires this run, and it must be done from PowerShell or cmd (not Git Bash).** Changes to the `.ahk` files in `lib/` only take effect after this runs — editing the repo alone does not update the running scripts.

- The repo is used on more than one laptop, with a different Windows user name
  on each (e.g. `korevma`, `mwkor`). Never hard-code a user path; use
  `$env:USERPROFILE` / `%USERPROFILE%` (or the actual repo root).
- `copy_ahk_to_startup.bat` is not found by its bare name from PowerShell/cmd;
  call it by its full path. It ends with `pause`, so pipe input to it:
  `'' | cmd /c "$env:USERPROFILE\Repositories\AutoHotkey\copy_ahk_to_startup.bat"`
- Deploying only copies files. The running script (`main.ahk` in the Startup
  folder) has to be reloaded to pick up the changes: stop the running
  `AutoHotkey64.exe` process for `main.ahk` and start it again with the
  executable found below.
- The deployed copy can lag far behind the repo on a laptop that hasn't been
  deployed in a while. Check first (`diff` the Startup `main.ahk` against the
  repo's) and tell the user which scripts a deploy would newly activate.

## Documentation

Before every commit, update [README.md](README.md) to reflect the changes in that commit (new/changed hotkeys, behavior, files, or deployment steps). Keep it in sync with the code — don't let it drift.

## AutoHotkey executable

Where AutoHotkey v2 is installed differs per laptop. Use the first one that
exists:

```text
%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey64.exe   (per-user install)
%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe            (machine-wide install)
```

From Git Bash:

```sh
AHK="$LOCALAPPDATA/Programs/AutoHotkey/v2/AutoHotkey64.exe"
[ -f "$AHK" ] || AHK="$PROGRAMFILES/AutoHotkey/v2/AutoHotkey64.exe"
```

Or look at the path of the running process:
`Get-Process AutoHotkey* | Select-Object Path`.

- Syntax check without running: `AutoHotkey64.exe //ErrorStdOut //validate script.ahk`
  (double slashes in Git Bash, otherwise MSYS rewrites `/x` into a path).
- Run a test script and capture output: write with `FileAppend(text, "*")` and
  run with `//ErrorStdOut ... 2>&1 | cat`.
- Put test scripts in the session scratchpad, not in the repo. Create the
  directory first (`mkdir -p`); it does not always exist yet.

## Outlook COM (classic Outlook)

- **Always ask before testing in Outlook yourself**, every time, even if
  permission was given earlier in the session: the user may be working in
  Outlook. Ask whether you may test it yourself or whether the user will
  test it manually; in the latter case give a concrete list of what to test.
  This covers anything that touches Outlook's UI (opening windows/drafts,
  changing folder or selection, activating the window, sending keys).

- `ComObjActive("Outlook.Application")` works from a test script while
  Outlook is running, so Outlook logic can be tested live.
- The `Explorer` object has **no `HWND` property** (throws). To check whether
  the main window is active, use `app.ActiveWindow().Class = 34` (olExplorer;
  Inspector = 35).
- Item classes: `MailItem` = 43, `AppointmentItem` = 26, `MeetingItem` = 53.

## UI Automation (ribbon)

- Outlook is in English. The ribbon can be inspected and driven live with UIA
  (raw `ComCall`, see `GetBrowserURL` / `UIAFindFirst`).
- **Never dump the whole Outlook tree** with FindAll + TrueCondition: the mail
  list makes it take minutes. Use `FindFirst` with a Name, AutomationId (30011)
  or AccessKey (30007) condition instead (~100–300 ms).
- A ribbon *group* and its button can have the same Name (`Report` is both),
  so look things up by AutomationId where one exists.
- Dropdown menu items only show up in the main window's tree after the
  dropdown is expanded (ExpandCollapse pattern). They often have no
  AutomationId, but their AccessKey is the KeyTip path, e.g. `Alt, H, R 1, P`.
- **When testing, never perform the final action** (reporting, deleting,
  sending, moving mail): open/close menus and locate the item, but stop
  before the click. This includes fallback paths that send KeyTips/keys, and
  simulated hotkey presses against the running script: only do those with
  `ReportDryRun := true` (or an equivalent dry run) covering *every* code path.
  On 2026-10-29 a test press went through an unguarded KeyTip fallback and
  reported a real newsletter as phishing.
