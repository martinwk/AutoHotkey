# CLAUDE.md

## Deployment

After successfully testing a change, and in any case before/with every commit, run `copy_ahk_to_startup.bat` to deploy the scripts to the startup folder. **Every commit requires this run, and it must be done from PowerShell or cmd (not Git Bash).** Changes to the `.ahk` files in `lib/` only take effect after this runs — editing the repo alone does not update the running scripts.

- `copy_ahk_to_startup.bat` is not found by its bare name from PowerShell/cmd;
  call it by its full path. It ends with `pause`, so pipe input to it:
  `'' | cmd /c "C:\Users\korevma\Repositories\AutoHotkey\copy_ahk_to_startup.bat"`
- Deploying only copies files. The running script (`main.ahk` in the Startup
  folder) has to be reloaded to pick up the changes.

## Documentation

Before every commit, update [README.md](README.md) to reflect the changes in that commit (new/changed hotkeys, behavior, files, or deployment steps). Keep it in sync with the code — don't let it drift.

## AutoHotkey executable

AutoHotkey v2 is installed **per-user**, not in Program Files:

```text
%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey64.exe
```

From Git Bash: `"$LOCALAPPDATA/Programs/AutoHotkey/v2/AutoHotkey64.exe"`.

- Syntax check without running: `AutoHotkey64.exe //ErrorStdOut //validate script.ahk`
  (double slashes in Git Bash, otherwise MSYS rewrites `/x` into a path).
- Run a test script and capture output: write with `FileAppend(text, "*")` and
  run with `//ErrorStdOut ... 2>&1 | cat`.
- Put test scripts in the session scratchpad, not in the repo. Create the
  directory first (`mkdir -p`); it does not always exist yet.

## Outlook COM (classic Outlook)

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
