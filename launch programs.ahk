; For large example file see:
;   https://github.com/xypha/AHK-v2-scripts/blob/main/Showcase.ahk

#Requires AutoHotkey v2.0
#Esc::
{
    Run "C:\Users\korevma\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Launchy\Launchy"
}
#z:: {
If WinExist("ahk_exe zotero.exe")
    WinActivate
Else
    Run "C:\Program Files\Zotero\zotero.exe"
}
#w:: {
If WinExist("ahk_exe WINWORD.exe")
    WinActivate
Else
    Run "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Word"
}
#n::
{
If WinExist("ahk_exe Notion.exe")
    WinActivate
Else
    Run "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Notion"
}
#t::
{
If WinExist("ahk_exe ms-teams.exe")
    WinActivate
Else
    Run "C:\Users\korevma\AppData\Local\Microsoft\WindowsApps\ms-teams.exe"
}
#v::
{
If WinExist("ahk_exe Code.exe")
    WinActivate
Else
    Run "C:\Users\korevma\AppData\Local\Programs\Microsoft VS Code\Code.exe"
}

