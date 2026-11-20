#Requires AutoHotkey v2.0

; Respond to the selected meeting request in classic Outlook's mail list:
;   a       accept, opens the response so you can add a message, then Send
;   Ctrl+A  accept and send the response right away (no message)
;   d       decline, opens the response so you can add a message
;   Ctrl+D  decline and send right away
; Only while the mail list has focus (not the search box, reading pane or a
; compose window) and exactly one meeting request is selected; otherwise the
; key goes through to Outlook (Ctrl+A = select all, Ctrl+D = delete).
; Dry run shows a tooltip instead of responding.
global MeetingDryRun := false

#HotIf WinActive("ahk_exe OUTLOOK.EXE ahk_class rctrl_renwnd32") && OutlookListFocused()
a::RespondOrPassThrough(3, false, "a")   ; olMeetingAccepted
^a::RespondOrPassThrough(3, true, "a")
d::RespondOrPassThrough(4, false, "d")   ; olMeetingDeclined
^d::RespondOrPassThrough(4, true, "d")
#HotIf

; Win32 only (no COM): #HotIf runs in the keyboard hook, see
; outlook_report_hotkeys.ahk. Keeps typing elsewhere free of COM latency.
OutlookListFocused() {
    try return WinGetClass(ControlGetFocus("A")) = "OutlookGrid"
    return false
}

RespondOrPassThrough(response, sendNow, key) {
    if (req := SelectedMeetingRequest())
        RespondToMeeting(req, response, sendNow)
    else
        Send("{Blind}" key)
}

; Returns the selected meeting request, or "" if the selection is anything else
; (a normal mail, a cancellation or response, several items, an inspector).
SelectedMeetingRequest() {
    try {
        app := ComObjActive("Outlook.Application")
        if app.ActiveWindow().Class != 34  ; olExplorer
            return ""
        sel := app.ActiveExplorer().Selection
        if sel.Count != 1
            return ""
        item := sel.Item(1)
        if item.Class = 53 && InStr(item.MessageClass, "IPM.Schedule.Meeting.Request") = 1  ; olMeetingRequest
            return item
    }
    return ""
}

RespondToMeeting(req, response, sendNow) {
    what := (response = 3 ? "Accept" : "Decline") (sendNow ? " (send now)" : " (edit response)")
    if MeetingDryRun {
        ToolTip("Dry run: would " what " '" req.Subject "'")
        SetTimer(() => ToolTip(), -3000)
        return
    }
    try {
        appt := req.GetAssociatedAppointment(true)
        reply := appt.Respond(response, true)  ; fNoUI: returns the response item
        ; Outlook's own buttons remove the request from the Inbox after responding.
        ; With an edited response, only do that once it's actually sent, so
        ; closing the window without sending leaves the request in the Inbox.
        if sendNow {
            reply.Send()
            try req.Delete()
        } else {
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
