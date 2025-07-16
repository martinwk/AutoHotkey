#Requires AutoHotkey v2.0
; Include utilities for functions
#Include utilities.ahk

; Initialize application paths at startup
VSCodeExePath := FindAppPath("VSCode")
EverythingExePath := FindAppPath("Everything")
FirefoxExePath := FindAppPath("Firefox")
WordExePath := FindAppPath("Word")
LaunchyExePath := FindAppPath("Launchy")
ZoteroExePath := FindAppPath("Zotero")
NotionExePath := FindAppPath("Notion")
TeamsExePath := FindAppPath("Teams")

; hotkey to sleep windows
#q::
{
    ; Activate the taskbar, open the Win+X menu, and select 'Sleep'
    WinActivate "ahk_class Shell_TrayWnd"
    Send "#x"
    Sleep 100
    Send "us"
}

; hotkey to close all windows and shut down
#+x:: ;Wnd+Shft+x
{
    CloseAllWindows()
}

; hotkey to close all windows and shut down
#+q:: ;Wnd+Shft+q
{
    CloseAllWindows()
    ; Prompt the user to enter shutdown time in minutes (or cancel)
    result := InputBox("Enter time to shutdown in minutes or cancel to cancel shutdown", "Shutdown", , 60)
    ; If user cancels or times out, abort any scheduled shutdown
    if (result.Result = "Cancel" || result.Result = "Timeout") {
        ; Cancels shutdown
        Run(A_ComSpec ' /c shutdown -a')
        Return
    }
    ; Otherwise, schedule shutdown after specified minutes
    a := result.Value * 60
    Run(A_ComSpec ' /c shutdown -s -t ' a)
}

; Hotkeys using ActivateOrRun function or OnlyRun function if you do not want to activate
; (sometimes that does not work)

#Esc::OnlyRun("launchy.exe", LaunchyExePath, "Launchy")

#e::ActivateOrRun("Everything.exe", EverythingExePath, "Everything")

#v::ActivateOrRun("Code.exe", VSCodeExePath, "VS Code")

#f::ActivateOrRun("firefox.exe", FirefoxExePath, "Firefox")

#w::ActivateOrRun("WINWORD.EXE", WordExePath, "Word")

#z::ActivateOrRun("zotero.exe", ZoteroExePath, "Zotero")

#n::ActivateOrRun("Notion.exe", NotionExePath, "Notion")

#t::ActivateOrRun("ms-teams.exe", TeamsExePath, "Teams")