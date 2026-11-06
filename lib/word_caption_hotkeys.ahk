#Requires AutoHotkey v2.0

; Ctrl+Shift+C in Word: Insert Caption when a picture/shape is selected,
; otherwise Insert Cross-reference. Both dialogs are opened through Word's own
; key bindings in Normal.dotm (Ctrl+Alt+Shift+C = InsertCaption,
; Ctrl+Shift+C = InsertCrossReference) rather than Dialogs().Show via COM,
; which would block this script until the modal dialog is closed.

#HotIf WinActive("ahk_exe WINWORD.EXE ahk_class OpusApp")
$^+c::WordCaptionOrCrossRef()
#HotIf

WordCaptionOrCrossRef() {
    try selType := ComObjActive("Word.Application").Selection.Type
    catch
        selType := 0
    if (selType = 7 || selType = 8)  ; wdSelectionInlineShape, wdSelectionShape
        Send("^!+c")
    else
        Send("^+c")
}
