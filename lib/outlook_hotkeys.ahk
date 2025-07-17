#Requires AutoHotkey v2.0

recentRightClick := true

; Rechterklik activeren als Outlook actief is
#HotIf WinActive("ahk_class rctrl_renwnd32")
~RButton::{
    ; MsgBox('rechterklik')
    recentRightClick := true
    SetTimer(() => recentRightClick := false, -1000) ; reset na 1 seconde
}
#HotIf

; Ctrl+D werkt alleen in Outlook EN na rechterklik
#HotIf recentRightClick
; #HotIf WinActive("ahk_class rctrl_renwnd32")
^d::{
    ; MsgBox('ctrl+d')
    ; Sleep(100)
    Send("e")
    Sleep(200)
    Send("d")
    Sleep(200)
    Send("{Enter}")
;     ; Sleep(500)
;     ; Send("{Enter}")
}
#HotIf