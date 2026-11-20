#Requires AutoHotkey v2.0

; Respond to a meeting request in classic Outlook, either the one selected in
; the mail list or the one open in its own window:
;   a       accept, opens the response so you can add a message, then Send
;   Ctrl+A  accept and send the response right away (no message)
;   d       decline, opens the response so you can add a message
;   Ctrl+D  decline and send right away
; In the main window only while the mail list has focus (not the search box or
; reading pane) and exactly one meeting request is selected; otherwise the key
; goes through to Outlook (Ctrl+A = select all, Ctrl+D = delete).
; Dry run shows a tooltip instead of responding.
global MeetingDryRun := false

#HotIf WinActive("ahk_exe OUTLOOK.EXE ahk_class rctrl_renwnd32") && (OutlookListFocused() || IsMeetingWindow())
a::RespondOrPassThrough(3, false, "a")   ; olMeetingAccepted
^a::RespondOrPassThrough(3, true, "a")
d::RespondOrPassThrough(4, false, "d")   ; olMeetingDeclined
^d::RespondOrPassThrough(4, true, "d")
#HotIf

; The #HotIf checks are Win32 only (no COM): #HotIf runs in the keyboard hook,
; see outlook_report_hotkeys.ahk. This also keeps typing elsewhere free of COM
; latency.
OutlookListFocused() {
    try return WinGetClass(ControlGetFocus("A")) = "OutlookGrid"
    return false
}

; Result of CheckMeetingWindow per window+title (the up/down arrows show
; another item in the same window): true if it shows a meeting to respond to.
global MeetingWindows := Map()

IsMeetingWindow() {
    try return MeetingWindows.Get(WinActive("A") "|" WinGetTitle("A"), false)
    return false
}

; Timer: classifies a newly active "<subject> - Meeting" window over COM, in the
; background. A meeting you're writing yourself has the same title; doing this
; check in the hotkey instead dropped the a/d keys typed while it ran. Until
; the window is classified the keys simply go through.
CheckMeetingWindow() {
    try {
        if !(hwnd := WinActive("ahk_exe OUTLOOK.EXE ahk_class rctrl_renwnd32"))
            return
        title := WinGetTitle(hwnd)
        ; Outlook pads inspector titles with trailing spaces.
        if SubStr(RTrim(title), -10) != " - Meeting" || MeetingWindows.Has(key := hwnd "|" title)
            return
        if MeetingWindows.Count > 200
            MeetingWindows.Clear()
        MeetingWindows[key] := !!MeetingRequestInFocus()
    }
}
SetTimer(CheckMeetingWindow, 300)

RespondOrPassThrough(response, sendNow, key) {
    if (found := MeetingRequestInFocus())
        RespondToMeeting(found, response, sendNow)
    else
        Send("{Blind}" key)
}

; Returns {req, appt, inspector} for the meeting in the active window, or ""
; if it is anything else (a normal mail, a cancellation or response, a meeting
; you organize, several items):
; - meeting window: the open request (req) or the open calendar item of a
;   meeting you were invited to (appt, req = ""); inspector = that window
; - main window: the only selected item, if it's a request (inspector = "")
MeetingRequestInFocus() {
    IsRequest(item) => item.Class = 53 && InStr(item.MessageClass, "IPM.Schedule.Meeting.Request") = 1  ; olMeetingRequest
    try {
        app := ComObjActive("Outlook.Application")
        win := app.ActiveWindow()
        if win.Class = 35 {  ; olInspector
            if IsRequest(item := win.CurrentItem)
                return {req: item, appt: "", inspector: win}
            if item.Class = 26 && item.MeetingStatus = 3  ; olAppointment, olMeetingReceived
                return {req: "", appt: item, inspector: win}
            return ""
        }
        if win.Class != 34  ; olExplorer
            return ""
        sel := app.ActiveExplorer().Selection
        if sel.Count = 1 && IsRequest(item := sel.Item(1))
            return {req: item, appt: "", inspector: ""}
    }
    return ""
}

RespondToMeeting(found, response, sendNow) {
    req := found.req, inspector := found.inspector
    what := (response = 3 ? "Accept" : "Decline") (sendNow ? " (send now)" : " (edit response)")
    if MeetingDryRun {
        ToolTip("Dry run: would " what " '" (req ? req.Subject : found.appt.Subject) "'"
            (inspector ? " (open window)" : ""))
        SetTimer(() => ToolTip(), -3000)
        return
    }
    try {
        appt := req ? req.GetAssociatedAppointment(true) : found.appt
        reply := appt.Respond(response, true)  ; fNoUI: returns the response item
        ; Like Outlook's own buttons, close the request's window after responding.
        ; A request has no edits (olDiscard); a calendar item is saved (olSave) so
        ; its new response status isn't thrown away.
        if inspector
            try inspector.Close(req ? 1 : 0)
        ; Outlook's own buttons remove the request from the Inbox after responding.
        ; With an edited response, only do that once it's actually sent, so
        ; closing the window without sending leaves the request in the Inbox.
        if sendNow {
            reply.Send()
            if req
                try req.Delete()
        } else {
            if req
                MeetingReplyWatcher(reply, req)
            reply.Display()
        }
    } catch as e {
        ToolTip("Meeting " what " failed: " e.Message)
        SetTimer(() => ToolTip(), -4000)
    }
}

; Listens to the response item's events: deletes the request when the response
; is sent, and stops listening when its window closes (sent or not).
class MeetingReplyWatcher {
    static active := Map()  ; keeps watchers (and their COM objects) alive

    __New(reply, req) {
        this.reply := reply, this.req := req
        MeetingReplyWatcher.active[ObjPtr(this)] := this
        ComObjConnect(reply, this)
    }

    ; COM event handlers; AutoHotkey passes the source object as last parameter.
    Send(cancel, item) {
        ; Delete outside the event handler, after Outlook has sent the response.
        SetTimer(MeetingReplyWatcher.DeleteRequest.Bind(MeetingReplyWatcher, this.req), -500)
    }

    static DeleteRequest(req) {
        try req.Delete()
    }

    Close(cancel, item) {
        ComObjConnect(this.reply)
        MeetingReplyWatcher.active.Delete(ObjPtr(this))
    }
}
