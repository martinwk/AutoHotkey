#Requires AutoHotkey v2.0

; Lid close: sleep only when no external display is in use.
;
; Windows has one "lid close action" per power source and can't tell whether an
; external display is connected. This script keeps that setting (AC and DC) in
; sync with the display setup, so Windows does the sleeping itself:
;   external display active -> "Do nothing"
;   only the laptop panel   -> "Sleep"
; Letting Windows sleep matters on this laptop: it uses Modern Standby
; (S0 low power idle, no S3), where SetSuspendState hibernates instead.
;
; "External" = any active display path whose output isn't an internal panel, so
; Extend, Duplicate and "Second screen only" all count as external.
;
; Log: %APPDATA%\ahk\lid_sleep.log

global LidDebugLog := true
global LidLogFile := A_AppData "\ahk\lid_sleep.log"
global LidActionExternal := 0    ; 0 = do nothing, 1 = sleep, 2 = hibernate, 3 = shut down
global LidActionNoExternal := 1
global LidState := -1            ; -1 = unknown, 0 = closed, 1 = open
global LidConsoleOn := true      ; display on (from GUID_CONSOLE_DISPLAY_STATE)
global LidLastExternal := -1     ; external display seen at the previous check
global LidStandbyRequested := false  ; standby already started for this lid-closed period

LidGuid(str) {
    buf := Buffer(16)
    DllCall("ole32\CLSIDFromString", "wstr", str, "ptr", buf, "hresult")
    return buf
}
global LidGuidSubButtons := LidGuid("{4F971E89-EEBD-4455-A8DE-9E59040E7347}")      ; SUB_BUTTONS
global LidGuidLidAction := LidGuid("{5CA83367-6E45-459F-A27B-476B1D01C936}")       ; LIDACTION
global LidGuidLidSwitch := LidGuid("{BA3E0F4D-B817-4094-A2D1-D56379E6A0F3}")       ; GUID_LIDSWITCH_STATE_CHANGE
global LidGuidConsoleDisplay := LidGuid("{6FE69556-704A-47A0-8F24-C28D936FDA47}")  ; GUID_CONSOLE_DISPLAY_STATE

LidLog(msg) {
    if LidDebugLog
        try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " " msg "`n", LidLogFile, "UTF-8")
}

; All active display paths as {tech, avail}, or "" when the query fails.
; avail = a monitor is actually connected: when the last display is unplugged
; with the lid closed, Windows keeps its path active but marks it unavailable.
LidActiveOutputs() {
    loop 3 {
        nPaths := 0, nModes := 0
        if DllCall("user32\GetDisplayConfigBufferSizes", "uint", 2, "uint*", &nPaths, "uint*", &nModes)  ; QDC_ONLY_ACTIVE_PATHS
            return ""
        paths := Buffer(72 * nPaths, 0)   ; DISPLAYCONFIG_PATH_INFO
        modes := Buffer(64 * nModes, 0)   ; DISPLAYCONFIG_MODE_INFO
        r := DllCall("user32\QueryDisplayConfig", "uint", 2, "uint*", &nPaths, "ptr", paths
            , "uint*", &nModes, "ptr", modes, "ptr", 0)
        if r = 0 {
            outputs := []
            loop nPaths {
                p := (A_Index - 1) * 72
                outputs.Push({tech: NumGet(paths, p + 36, "UInt")       ; targetInfo.outputTechnology
                    , avail: NumGet(paths, p + 60, "UInt") != 0})        ; targetInfo.targetAvailable
            }
            return outputs
        }
        if r != 122  ; ERROR_INSUFFICIENT_BUFFER: topology changed in between, retry
            return ""
    }
    return ""
}

LidIsInternalOutput(t) => t = 0x80000000 || t = 6 || t = 11 || t = 13  ; internal, LVDS, eDP, UDI embedded

LidOutputName(t) {
    static names := Map(0x80000000, "intern", 6, "intern-LVDS", 11, "intern-eDP", 13, "intern-UDI"
        , 0, "VGA", 4, "DVI", 5, "HDMI", 10, "DisplayPort", 15, "Miracast", 16, "indirect", 17, "virtueel")
    return names.Has(t) ? names[t] : "tech" t
}

LidOnAC() {
    sps := Buffer(12, 0)  ; SYSTEM_POWER_STATUS
    DllCall("kernel32\GetSystemPowerStatus", "ptr", sps)
    s := NumGet(sps, 0, "UChar")
    return s = 1 ? "netspanning" : s = 0 ? "accu" : "onbekend"
}

; Reads the lid action of the active power scheme; first writes `want` (AC and DC) when given.
; Returns {ac, dc}, or "" when the active scheme can't be read.
LidPowerAction(want := -1) {
    pScheme := 0
    if DllCall("powrprof\PowerGetActiveScheme", "ptr", 0, "ptr*", &pScheme, "uint")
        return ""
    try {
        if want >= 0 {
            e1 := DllCall("powrprof\PowerWriteACValueIndex", "ptr", 0, "ptr", pScheme
                , "ptr", LidGuidSubButtons, "ptr", LidGuidLidAction, "uint", want, "uint")
            e2 := DllCall("powrprof\PowerWriteDCValueIndex", "ptr", 0, "ptr", pScheme
                , "ptr", LidGuidSubButtons, "ptr", LidGuidLidAction, "uint", want, "uint")
            e3 := DllCall("powrprof\PowerSetActiveScheme", "ptr", 0, "ptr", pScheme, "uint")  ; apply
            if e1 || e2 || e3
                LidLog("FOUT bij schrijven dekselactie: " e1 "/" e2 "/" e3)
        }
        ac := -1, dc := -1
        DllCall("powrprof\PowerReadACValueIndex", "ptr", 0, "ptr", pScheme
            , "ptr", LidGuidSubButtons, "ptr", LidGuidLidAction, "uint*", &ac, "uint")
        DllCall("powrprof\PowerReadDCValueIndex", "ptr", 0, "ptr", pScheme
            , "ptr", LidGuidSubButtons, "ptr", LidGuidLidAction, "uint*", &dc, "uint")
        return {ac: ac, dc: dc}
    } finally
        DllCall("LocalFree", "ptr", pScheme)
}

LidActionName(a) {
    static names := ["niets", "slaap", "sluimer", "afsluiten"]
    return a >= 0 && a < 4 ? names[a + 1] : a
}

; Brings the lid action in line with the display setup. The periodic check only
; logs when it changes something; every other trigger always logs.
LidSync(reason) {
    outputs := LidActiveOutputs()
    if !IsObject(outputs) {
        LidLog(reason ": schermconfiguratie niet uit te lezen, niets aangepast")
        return
    }
    global LidLastExternal, LidStandbyRequested
    external := false, list := ""
    for o in outputs {
        list .= (list = "" ? "" : ", ") LidOutputName(o.tech) (o.avail ? "" : " (losgekoppeld)")
        if o.avail && !LidIsInternalOutput(o.tech)
            external := true
    }
    want := external ? LidActionExternal : LidActionNoExternal
    externalChanged := external != LidLastExternal
    LidLastExternal := external

    cur := LidPowerAction()
    if !IsObject(cur) {
        LidLog(reason ": actief energieschema niet uit te lezen, niets aangepast")
        return
    }
    changed := cur.ac != want || cur.dc != want
    if changed
        cur2 := LidPowerAction(want)
    if !changed && !externalChanged && reason = "timer"
        return

    lid := LidState = 0 ? "dicht" : LidState = 1 ? "open" : "?"
    msg := reason " | deksel " lid " | " LidOnAC() " | actief: [" list "] | extern: " (external ? "ja" : "nee")
        . " | dekselactie AC=" LidActionName(cur.ac) " DC=" LidActionName(cur.dc)
    if changed
        msg .= " -> " (IsObject(cur2) ? "AC=" LidActionName(cur2.ac) " DC=" LidActionName(cur2.dc) : "schrijven mislukt")
    ; The external display went away while the lid was already closed. Windows only
    ; applies the lid action when the lid closes, so start standby ourselves. Only
    ; while the display is on: an external monitor that dropped out because the
    ; screen was already off (idle timeout) must not put the laptop to sleep.
    if LidState = 0 && !external && reason != "deksel dicht" {
        if !LidConsoleOn
            msg .= " | deksel dicht zonder extern scherm, beeld is al uit: niets gedaan"
        else if LidStandbyRequested
            msg .= " | deksel dicht zonder extern scherm, stand-by al eerder gestart"
        else {
            msg .= " | deksel dicht zonder extern scherm: stand-by gestart (beeldscherm uit)"
            LidStandbyRequested := true
            SetTimer(LidEnterStandby, -500)
        }
    }
    LidLog(msg)
}

; On Modern Standby, turning the display off starts standby.
LidEnterStandby() {
    DllCall("user32\PostMessage", "ptr", 0xFFFF, "uint", 0x112, "ptr", 0xF170, "ptr", 2)  ; HWND_BROADCAST, WM_SYSCOMMAND, SC_MONITORPOWER, off
}

LidGuidEquals(p, guid) {
    loop 2
        if NumGet(p, (A_Index - 1) * 8, "Int64") != NumGet(guid, (A_Index - 1) * 8, "Int64")
            return false
    return true
}

LidOnPowerBroadcast(wParam, lParam, *) {
    global LidState, LidConsoleOn, LidStandbyRequested
    switch wParam {
        case 0x4:     ; PBT_APMSUSPEND
            LidLog("systeem gaat in slaapstand")
        case 0x12:    ; PBT_APMRESUMEAUTOMATIC
            LidLog("systeem wordt wakker")
            SetTimer(LidSync.Bind("na wakker worden"), -2000)
        case 0x8013:  ; PBT_POWERSETTINGCHANGE: POWERBROADCAST_SETTING {GUID, DataLength, Data}
            data := NumGet(lParam, 20, "UInt")
            if LidGuidEquals(lParam, LidGuidLidSwitch) {
                prev := LidState
                LidState := data
                if prev = -1  ; Windows sends the current state right after registering
                    LidLog("deksel is " (data ? "open" : "dicht") " (beginstand)")
                else if data = 0
                    LidSync("deksel dicht")
                else {
                    LidStandbyRequested := false
                    LidLog("deksel open")
                }
            } else if LidGuidEquals(lParam, LidGuidConsoleDisplay) {
                LidConsoleOn := data != 0  ; 0 = off, 1 = on, 2 = dimmed
                ; Modern Standby sends no PBT_APMSUSPEND: the console display turning
                ; off right after the lid closes is the sign the system went to standby.
                LidLog("beeldscherm " (data = 0 ? "uit" : data = 1 ? "aan" : "gedimd")
                    . (data = 0 && LidState = 0 ? " (deksel dicht: moderne stand-by)" : ""))
            }
    }
}

; Debounced: a topology change fires several WM_DISPLAYCHANGE messages in a row.
LidOnDisplayChange(*) {
    static fn := LidSync.Bind("schermwijziging")  ; same object each time, so SetTimer restarts it
    SetTimer(fn, -1500)
}

LidLog("=== script gestart ===")
OnMessage(0x218, LidOnPowerBroadcast)   ; WM_POWERBROADCAST
OnMessage(0x7E, LidOnDisplayChange)     ; WM_DISPLAYCHANGE
DllCall("user32\RegisterPowerSettingNotification", "ptr", A_ScriptHwnd, "ptr", LidGuidLidSwitch, "uint", 0, "ptr")
DllCall("user32\RegisterPowerSettingNotification", "ptr", A_ScriptHwnd, "ptr", LidGuidConsoleDisplay, "uint", 0, "ptr")
LidSync("start")
SetTimer(LidSync.Bind("timer"), 10000)  ; catches changes without WM_DISPLAYCHANGE (display unplugged with lid closed, settings changed by hand)
