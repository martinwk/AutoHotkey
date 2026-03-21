#Requires AutoHotkey v2.0

GetCurrentYearWeek() {
    return FormatTime(A_Now, "yyyy") "-" Format("{:02}", (A_YDay - 1) // 7 + 1)
}

debug := true

GetOutlookPreviewSubject() {
    try ol := ComObjActive("Outlook.Application")
    catch
        MsgBox("Unable to connect to Outlook.")

    if (debug) {
        MsgBox("Outlook COM object: " . ComObjType(ol) . "\nVersion: " . ol.Version)
    }

    try {
        exp := ol.ActiveExplorer()
        sel := exp.Selection
        if (sel.Count >= 1) {
            item := sel.Item(1)
            return item.Subject
        }
    } catch {
        if (debug)
            MsgBox("Error reading Outlook selection")
        return ""
    }
    return ""
}

global lastWindow := "", lastStartTime := A_Now, lastWeek := GetCurrentYearWeek()
global logFile := A_Desktop "\window_log_" lastWeek ".txt"

CheckWindow() {
    global lastWindow, lastStartTime, logFile, lastWeek
    idleMs := A_TimeIdlePhysical
    try {
        current := WinGetTitle("A")
    } catch {
        current := "Desktop"
    }

    ; if (InStr(current, "Outlook")) {
    ;     subject := GetOutlookPreviewSubject()
    ;     if (subject != "")
    ;         current := "Outlook: " subject
    ; }

    current := (idleMs > 60000) ? "Idle" : current
    current := (current != "") ? current : "Untitled"

    if (current != lastWindow) {
        if (lastWindow != "") {
            endTime := A_Now
            duration := DateDiff(endTime, lastStartTime, "Seconds")
            durationMin := duration // 60
            currentWeek := GetCurrentYearWeek()
            if (currentWeek != lastWeek) {
                logFile := A_Desktop "\window_log_" currentWeek ".txt"
                lastWeek := currentWeek
            }
            FileAppend(Format("{1} - {2} | {3:03} min | {4}`n", FormatTime(lastStartTime, "yyyy-MM-dd HH:mm:ss"), FormatTime(endTime, "yyyy-MM-dd HH:mm:ss"), durationMin, lastWindow), logFile, "UTF-8")
        }
        lastWindow := current
        lastStartTime := A_Now
    }
}

SetTimer(CheckWindow, 1000)
CheckWindow()  ; Run once at start