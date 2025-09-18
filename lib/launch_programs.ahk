#Requires AutoHotkey v2.0
; Include utilities for functions
#Include utilities.ahk

; Initialize application paths at startup
; List of all exe's used in hotkeys
exeList := [
    "Code.exe",
    "Everything.exe",
    "firefox.exe",
    "WINWORD.EXE",
    "launchy.exe",
    "zotero.exe",
    "Notion.exe",
    "ms-teams.exe",
    "Spotify.exe"
]

; Find locations for all exe's
locations := FindExeLocations(exeList)
; for exe, path in locations
;     MsgBox(exe ": " path)

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

#Esc::OnlyRun("launchy.exe", locations, "Launchy")

#e::ActivateOrRun("Everything.exe", locations, "Everything")

#v::ActivateOrRun("Code.exe", locations, "VS Code")

#f::ActivateOrRun("firefox.exe", locations, "Firefox")

#w::ActivateOrRun("WINWORD.EXE", locations, "Word")

#z::ActivateOrRun("zotero.exe", locations, "Zotero")

#n::ActivateOrRun("Notion.exe", locations, "Notion")

#t::ActivateOrRun("ms-teams.exe", locations, "Teams")

#s::ActivateOrRun("Spotify.exe", locations, "Spotify")