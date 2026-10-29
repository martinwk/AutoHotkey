#Requires AutoHotkey v2.0

; Report the selected mail via the Home ribbon's Report button (KeyTips
; Alt,H,R1 then J = junk / P = phishing). Only active in classic Outlook's
; main window with a mail selected: not in calendar/contacts views, not in a
; compose/reply window and not while replying inline in the reading pane.
; Testing aids: dry run opens the menu and shows what would be clicked without
; reporting anything; every check is logged to %TEMP%\outlook_report_hotkeys.log.
global ReportDryRun := true
global ReportDebugLog := true

ReportLog(msg) {
    if ReportDebugLog
        try FileAppend(FormatTime(, "HH:mm:ss") "." A_MSec " " msg "`n", A_Temp "\outlook_report_hotkeys.log")
}

#HotIf WinActive("ahk_exe OUTLOOK.EXE ahk_class rctrl_renwnd32")
!s::ReportOrPassThrough("J", "s")
!p::ReportOrPassThrough("P", "p")
#HotIf

; #HotIf runs inside the keyboard hook, where COM calls to Outlook fail with
; RPC_E_CANTCALLOUT_ININPUTSYNCCALL, so the mail check happens here instead and
; the key goes through to Outlook when it doesn't apply (e.g. Alt+S = Send in a
; compose window).
ReportOrPassThrough(menuKey, hotkeyKey) {
    if OutlookMailSelected()
        ReportSelectedMail(menuKey)
    else
        Send("{Blind}" hotkeyKey)
}

; Clicks Report > <item> via UI Automation instead of typing the KeyTips, so we
; never wait on Office's KeyTip timing (it pauses after an ambiguous letter).
; The menu items have no AutomationId, so match them on their KeyTip, which is
; also language independent.
ReportSelectedMail(key) {
    static uia := ComObject("{FF48DBA4-60EF-4201-AA87-54103EEF594E}", "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")  ; CUIAutomation
    root := 0, dropdown := 0, expander := 0, item := 0, invoker := 0
    try {
        ComCall(6, uia, "ptr", WinActive("A"), "ptr*", &root)  ; ElementFromHandle
        dropdown := UIAFindFirst(uia, root, 30011, "ReportMenuButton_Dropdown")  ; AutomationId
        if !dropdown {
            ReportLog("report " key ": dropdown not found in " WinGetTitle("A") ", sending KeyTips")
            ; Ribbon collapsed or another tab open: the KeyTips switch to Home themselves.
            if ReportDryRun {
                ToolTip("Dry run: Report button not found, would send KeyTips !hr1" key)
                SetTimer(() => ToolTip(), -3000)
            } else
                SendKeyTips("!hr1" key)
            return
        }
        ComCall(16, dropdown, "int", 10005, "ptr*", &expander)  ; GetCurrentPattern(ExpandCollapse)
        ComCall(3, expander)  ; Expand
        ; The menu items appear in the tree a moment after expanding.
        Loop 40 {
            if (item := UIAFindFirst(uia, root, 30007, "Alt, H, R 1, " key))  ; AccessKey
                break
            Sleep(25)
        }
        ReportLog("report " key ": item " (item ? "found: " GetUIAProp(item, 30005) : "not found"))
        if (item && ReportDryRun) {
            ComCall(4, expander)  ; Collapse
            ToolTip("Dry run: would click '" GetUIAProp(item, 30005) "'")
            SetTimer(() => ToolTip(), -3000)
        } else if item {
            ComCall(16, item, "int", 10000, "ptr*", &invoker)  ; GetCurrentPattern(Invoke)
            ComCall(3, invoker)  ; Invoke
        } else {
            ComCall(4, expander)  ; Collapse
            ToolTip("Report menu has no '" key "' option for this mail")
            SetTimer(() => ToolTip(), -2000)
        }
    } catch as e
        ReportLog("report " key ": error " e.Message)
    for p in [invoker, item, expander, dropdown, root]
        if (p)
            ObjRelease(p)
}

; FindFirst(TreeScope_Descendants) on a string property; returns 0 if not found.
UIAFindFirst(uia, el, propId, value) {
    var := Buffer(24, 0)
    NumPut("ushort", 8, var, 0)  ; VT_BSTR
    NumPut("ptr", bstr := DllCall("oleaut32\SysAllocString", "str", value, "ptr"), var, 8)
    cond := 0, found := 0
    try {
        ComCall(23, uia, "int", propId, "ptr", var, "ptr*", &cond)  ; CreatePropertyCondition
        ComCall(5, el, "int", 4, "ptr", cond, "ptr*", &found)  ; FindFirst
    }
    if (cond)
        ObjRelease(cond)
    DllCall("oleaut32\SysFreeString", "ptr", bstr)
    return found
}

; Fallback when the Report button isn't in the UIA tree. KeyTips drop keys that
; arrive too fast, so send them one by one with a delay.
SendKeyTips(keys) {
    SetKeyDelay(50, 20)
    SendEvent(keys)
}

OutlookMailSelected() {
    if !WinActive("ahk_exe OUTLOOK.EXE ahk_class rctrl_renwnd32") {
        ReportLog("check: active window is " WinGetProcessName("A") " / " WinGetClass("A"))
        return false
    }
    t := A_TickCount
    try {
        app := ComObjActive("Outlook.Application")
        if app.ActiveWindow().Class != 34 {  ; olExplorer (not an Inspector)
            ReportLog("check: active Outlook window is not the main window")
            return false
        }
        explorer := app.ActiveExplorer()
        selection := explorer.Selection
        ok := !explorer.ActiveInlineResponse
            && selection.Count > 0 && selection.Item(1).Class = 43  ; olMail
        ReportLog("check: " (ok ? "OK" : "no mail selected / inline reply")
            " (count=" selection.Count ", " A_TickCount - t " ms)")
        return ok
    } catch as e {
        ReportLog("check: COM error after " A_TickCount - t " ms: " e.Message)
    }
    return false
}
