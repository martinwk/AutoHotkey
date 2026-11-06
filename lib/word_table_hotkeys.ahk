#Requires AutoHotkey v2.0

; Table chords in Word, all starting with Ctrl+` (Ctrl may stay held):
;   Ctrl+`, C     insert column right of the cursor
;   Ctrl+`, R     insert row below the cursor
;   Ctrl+`, D, C  delete the current column(s)
;   Ctrl+`, D, R  delete the current row(s)
; Outside a table Ctrl+` goes through to Word, where it is the grave-accent
; prefix (Ctrl+`, E = è). The follow-up keys time out after 2 s.

#HotIf WinActive("ahk_exe WINWORD.EXE ahk_class OpusApp")
^`::WordTableChord()
#HotIf

WordTableChord() {
    try {
        word := ComObjActive("Word.Application")
        inTable := word.Selection.Information[12]  ; wdWithInTable
    } catch {
        inTable := false
    }
    if !inTable {
        Send("{Blind}^``")
        return
    }
    switch WordChordKey() {
        case "c": WordTableAction(word, "InsertColumn")
        case "r": WordTableAction(word, "InsertRow")
        case "d":
            switch WordChordKey() {
                case "c": WordTableAction(word, "DeleteColumn")
                case "r": WordTableAction(word, "DeleteRow")
            }
    }
}

; Waits for the next non-modifier key and returns its name ("" on timeout).
; The key is blocked, so it never reaches the document.
WordChordKey() {
    ih := InputHook("T2")
    ih.KeyOpt("{All}", "ES")
    ih.KeyOpt("{LCtrl}{RCtrl}{LShift}{RShift}{LAlt}{RAlt}{LWin}{RWin}", "-E-S")
    ih.Start()
    ih.Wait()
    return ih.EndReason = "EndKey" ? StrLower(ih.EndKey) : ""
}

WordTableAction(word, action) {
    try {
        sel := word.Selection
        switch action {
            case "InsertColumn": sel.InsertColumnsRight()
            case "InsertRow": sel.InsertRowsBelow(1)
            case "DeleteColumn": sel.Columns.Delete()
            case "DeleteRow": sel.Rows.Delete()
        }
    } catch as e {
        ToolTip("Word table: " action " failed: " e.Message)
        SetTimer(() => ToolTip(), -3000)
    }
}
