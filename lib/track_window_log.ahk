#Requires AutoHotkey v2.0

GetCurrentYearMonth() {
    return FormatTime(A_Now, "yyyy-MM")
}

GetOutlookPreviewSubject() {
    ; Classic Outlook only; the new Outlook (olk.exe) has no COM interface
    try {
        ol := ComObjActive("Outlook.Application")
        sel := ol.ActiveExplorer().Selection
        if (sel.Count >= 1)
            return sel.Item(1).Subject
    }
    return ""
}

; Subject of the calendar appointment running right now, "" if none.
; Used as the segment detail while in a call, so meetings map to their agenda entry.
GetCurrentAppointment() {
    try {
        ol := ComObjActive("Outlook.Application")
        items := ol.GetNamespace("MAPI").GetDefaultFolder(9).Items  ; olFolderCalendar
        items.Sort("[Start]")
        items.IncludeRecurrences := true  ; requires the Sort above, per Outlook docs
        ; Restrict parses the date in the system locale; change the format here if this
        ; always comes back empty on a non-US locale.
        now := FormatTime(A_Now, "MM/dd/yyyy HH:mm")
        for item in items.Restrict("[Start] <= '" now "' AND [End] > '" now "'")
            return item.Subject
    }
    return ""
}

GetCurrentAppointmentCached() {
    static val := "", checked := 0
    if (A_TickCount - checked > 30000) {
        val := GetCurrentAppointment()
        checked := A_TickCount
    }
    return val
}

; RegRead() on this AutoHotkey build throws "(1630) Data of this type is not
; supported" on REG_QWORD values, which LastUsedTimeStop/Start are — so plain
; RegRead() silently (via the try/catch below) never finds a live mic user.
; Read the QWORD via RegGetValueW instead.
RegReadQWORD(subkey, valueName) {
    static HKEY_CURRENT_USER := 0x80000001
    static RRF_RT_QWORD := 0x48
    buf := Buffer(8, 0)
    size := 8
    result := DllCall("advapi32\RegGetValueW", "ptr", HKEY_CURRENT_USER, "wstr", subkey, "wstr", valueName, "uint", RRF_RT_QWORD, "ptr", 0, "ptr", buf, "uint*", &size)
    if (result != 0)
        throw Error("RegGetValue failed: " result)
    return NumGet(buf, 0, "int64")
}

; Windows tracks live microphone use in the CapabilityAccessManager consent store:
; a subkey with LastUsedTimeStop = 0 means that app has the mic open right now.
; Returns the app using the mic ("ms-teams.exe", "MSTeams", ...) or "" if none.
GetMicUserApp() {
    static base := "SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone"
    Loop Reg, "HKCU\" base "\NonPackaged", "K" {
        try {
            if (RegReadQWORD(base "\NonPackaged\" A_LoopRegName, "LastUsedTimeStop") = 0) {
                SplitPath(StrReplace(A_LoopRegName, "#", "\"), &exe)
                return exe
            }
        }
    }
    Loop Reg, "HKCU\" base, "K" {
        if (A_LoopRegName = "NonPackaged")
            continue
        try {
            if (RegReadQWORD(base "\" A_LoopRegName, "LastUsedTimeStop") = 0)
                return RegExReplace(A_LoopRegName, "_.*$")  ; strip the package-id suffix
        }
    }
    return ""
}

GetMicUserAppCached() {
    static val := "", checked := 0
    if (A_TickCount - checked > 5000) {
        val := GetMicUserApp()
        checked := A_TickCount
    }
    return val
}

IsBrowser(proc) {
    static browsers := Map("chrome.exe", 1, "msedge.exe", 1, "firefox.exe", 1, "brave.exe", 1, "opera.exe", 1, "vivaldi.exe", 1)
    return browsers.Has(StrLower(proc))
}

; Reads the URL of the active tab via UI Automation: browsers expose each tab as a
; Document element whose Value is the URL. Preloaded/background tabs also appear in
; the tree, so prefer the on-screen document whose name matches the window title.
GetBrowserURL(hwnd) {
    static uia := ComObject("{FF48DBA4-60EF-4201-AA87-54103EEF594E}", "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")  ; CUIAutomation
    winTitle := ""
    try winTitle := WinGetTitle(hwnd)
    url := "", firstVisible := "", firstAny := "", root := 0, cond := 0, arr := 0
    try {
        ComCall(6, uia, "ptr", hwnd, "ptr*", &root)  ; ElementFromHandle
        var := Buffer(24, 0)
        NumPut("ushort", 3, var, 0)   ; VT_I4
        NumPut("int", 50030, var, 8)  ; UIA_DocumentControlTypeId
        ComCall(23, uia, "int", 30003, "ptr", var, "ptr*", &cond)  ; CreatePropertyCondition(UIA_ControlTypePropertyId, Document)
        ComCall(6, root, "int", 4, "ptr", cond, "ptr*", &arr)  ; FindAll(TreeScope_Descendants)
        if (arr) {
            ComCall(3, arr, "int*", &len := 0)  ; get_Length
            Loop len {
                ComCall(4, arr, "int", A_Index - 1, "ptr*", &el := 0)  ; GetElement
                if (!el)
                    continue
                name := GetUIAProp(el, 30005), val := GetUIAProp(el, 30045), off := GetUIAProp(el, 30022)
                ObjRelease(el)
                if (val = "")
                    continue
                if (firstAny = "")
                    firstAny := val
                if (off != "true" && firstVisible = "")
                    firstVisible := val
                ; The active tab's document name is the leading part of the window title.
                ; Don't require on-screen here: Firefox marks everything offscreen when unfocused.
                if (name != "" && InStr(winTitle, name) = 1) {
                    url := val
                    break
                }
            }
        }
    }
    for p in [arr, cond, root]
        if (p)
            ObjRelease(p)
    return (url != "") ? url : (firstVisible != "") ? firstVisible : firstAny
}

GetUIAProp(el, propId) {
    out := Buffer(24, 0)
    ComCall(10, el, "int", propId, "ptr", out)  ; GetCurrentPropertyValue
    vt := NumGet(out, 0, "ushort")
    val := ""
    if (vt = 8)  ; VT_BSTR
        val := StrGet(NumGet(out, 8, "ptr"))
    else if (vt = 11)  ; VT_BOOL
        val := NumGet(out, 8, "short") ? "true" : "false"
    DllCall("oleaut32\VariantClear", "ptr", out)
    return val
}

; Full path of the open document/folder, so the importer can map files to projects
; (the window title only shows the base name, which is often ambiguous).
GetDocumentPath(proc, hwnd) {
    switch StrLower(proc) {
        case "winword.exe":
            try return ComObjActive("Word.Application").ActiveDocument.FullName
        case "excel.exe":
            try return ComObjActive("Excel.Application").ActiveWorkbook.FullName
        case "powerpnt.exe":
            try return ComObjActive("PowerPoint.Application").ActivePresentation.FullName
        case "explorer.exe":
            try {
                for w in ComObject("Shell.Application").Windows {
                    if (w.HWND = hwnd)
                        return w.Document.Folder.Self.Path
                }
            }
    }
    return ""
}

global lastKey := "", lastTitle := "", lastProcess := "", lastDetail := ""
global lastStartTime := A_Now, lastMonth := GetCurrentYearMonth(), lastWasIdle := false
global sessionLocked := false
global logFile := A_Desktop "\window_log_" lastMonth ".txt"

CurrentLogFile() {
    global logFile, lastMonth
    currentMonth := GetCurrentYearMonth()
    ; IsSet: the mark hotkey can fire while the auto-execute section (which assigns
    ; the globals) is still busy in an earlier #Include of main.ahk
    if (!IsSet(lastMonth) || currentMonth != lastMonth) {
        logFile := A_Desktop "\window_log_" currentMonth ".txt"
        lastMonth := currentMonth
    }
    return logFile
}

LogSegment(endTime := "") {
    global lastKey, lastTitle, lastProcess, lastDetail, lastStartTime
    if (lastKey = "")
        return
    if (endTime = "")
        endTime := A_Now
    durationMin := DateDiff(endTime, lastStartTime, "Seconds") // 60
    ; Title goes last: it may contain "|" itself, so importers should split on the first 4 pipes
    ; only. Detail is sanitized because it can now hold window titles (idle segments) too.
    FileAppend(Format("{1} - {2} | {3:03} min | {4} | {5} | {6}`n", FormatTime(lastStartTime, "yyyy-MM-dd HH:mm:ss"), FormatTime(endTime, "yyyy-MM-dd HH:mm:ss"), durationMin, lastProcess, StrReplace(lastDetail, "|", "/"), lastTitle), CurrentLogFile(), "UTF-8")
}

CheckWindow() {
    global lastKey, lastTitle, lastProcess, lastDetail, lastStartTime, lastWasIdle, sessionLocked
    idleMs := A_TimeIdlePhysical
    try {
        title := WinGetTitle("A")
    } catch {
        title := "Desktop"
    }
    proc := ""
    try proc := WinGetProcessName("A")

    isIdle := (idleMs > 60000)
    detail := ""
    if (sessionLocked) {
        ; Locked screen = definitely away; unlocked idle (below) may still be reading
        title := "Locked"
        proc := ""
    } else if (isIdle) {
        ; No input but the mic is live: a call, not a break. Log who holds the mic
        ; (the foreground window may be something else entirely) plus the running
        ; calendar appointment, so the importer can bill the meeting.
        micApp := GetMicUserAppCached()
        if (micApp != "") {
            title := "InCall"
            proc := micApp
            detail := GetCurrentAppointmentCached()
        } else {
            ; Unlocked idle: keep the foreground window (proc stays, title moves to
            ; detail) so the importer can classify "idle in a reading app" as reading
            ; instead of a break.
            detail := title
            title := "Idle"
        }
    } else if (title = "") {
        title := "Untitled"
    }

    ; Outlook: poll the selected mail every tick so each mail becomes its own segment
    if (!isIdle && StrLower(proc) = "outlook.exe")
        detail := GetOutlookPreviewSubject()

    key := title "|" proc "|" detail
    if (key != lastKey) {
        boundary := A_Now
        ; Entering idle/call: the break really started when input stopped, not when
        ; the 60s threshold fired, so backdate the boundary by the idle time.
        if (isIdle && !lastWasIdle) {
            boundary := DateAdd(A_Now, -(idleMs // 1000), "Seconds")
            if (DateDiff(boundary, lastStartTime, "Seconds") < 0)
                boundary := lastStartTime
        }
        LogSegment(boundary)
        ; Browser URL / document path is read once at segment start; COM is too heavy to poll every second
        if (detail = "" && !isIdle) {
            hwnd := WinExist("A")
            detail := IsBrowser(proc) ? GetBrowserURL(hwnd) : GetDocumentPath(proc, hwnd)
        }
        lastKey := key
        lastTitle := title
        lastProcess := proc
        lastDetail := detail
        lastStartTime := boundary
        lastWasIdle := (isIdle || sessionLocked)
    }
}

; Lock/unlock arrives as WM_WTSSESSION_CHANGE; CheckWindow picks the flag up on its next tick
SessionChanged(wParam, lParam, msg, hwnd) {
    global sessionLocked
    if (wParam = 7)       ; WTS_SESSION_LOCK
        sessionLocked := true
    else if (wParam = 8)  ; WTS_SESSION_UNLOCK
        sessionLocked := false
}

; Ctrl+Alt+Insert: append a "MARK | <project>" line. The importer can treat marks as
; ground truth and attribute the segments that follow to that project.
^!Insert:: {
    static lastProject := ""
    ib := InputBox("Bill time from now to project:", "Mark project", "w300 h110", lastProject)
    if (ib.Result != "OK" || Trim(ib.Value) = "")
        return
    lastProject := Trim(ib.Value)
    FileAppend(Format("{1} | MARK | {2}`n", FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"), lastProject), CurrentLogFile(), "UTF-8")
}

FlushOnExit(reason, code) {
    global lastKey
    LogSegment()
    lastKey := ""  ; prevent double logging if multiple exit callbacks fire
}

OnExit(FlushOnExit)
DllCall("wtsapi32\WTSRegisterSessionNotification", "ptr", A_ScriptHwnd, "uint", 0)  ; NOTIFY_FOR_THIS_SESSION
OnMessage(0x02B1, SessionChanged)  ; WM_WTSSESSION_CHANGE
SetTimer(CheckWindow, 1000)
CheckWindow()  ; Run once at start
