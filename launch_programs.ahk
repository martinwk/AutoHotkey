#Requires AutoHotkey v2.0
; Include utilities for functions
#Include utilities.ahk

; Initialize application paths at startup
VSCodeExePath := FindAppPath("VSCode")
EverythingExePath := FindAppPath("Everything")
FirefoxExePath := FindAppPath("Firefox")
WordExePath := FindAppPath("Word")
LaunchyExePath := FindAppPath("Launchy")
ZoteroExePath := FindAppPath("Zotero")
NotionExePath := FindAppPath("Notion")
TeamsExePath := FindAppPath("Teams")

; Hotkeys using ActivateOrRun function
#Esc::OnlyRun("launchy.exe", LaunchyExePath, "Launchy")

#e::ActivateOrRun("Everything.exe", EverythingExePath, "Everything")

#v::ActivateOrRun("Code.exe", VSCodeExePath, "VS Code")

#f::ActivateOrRun("firefox.exe", FirefoxExePath, "Firefox")

#w::ActivateOrRun("WINWORD.EXE", WordExePath, "Word")

#z::ActivateOrRun("zotero.exe", ZoteroExePath, "Zotero")

#n::ActivateOrRun("Notion.exe", NotionExePath, "Notion")

#t::ActivateOrRun("ms-teams.exe", TeamsExePath, "Teams")