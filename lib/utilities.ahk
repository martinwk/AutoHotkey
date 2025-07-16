OnlyRun(exeName, appPath, appName := "") {
    ; Gebruik executable naam als appName als niet opgegeven
    if (appName = "")
        appName := StrReplace(exeName, ".exe", "")

    if (appPath != "")
        Run(appPath)
    Else
        MsgBox(appName . " niet gevonden in (" . appPath . ")")
}
ActivateOrRun(exeName, appPath, appName := "") {
    ; Gebruik executable naam als appName als niet opgegeven
    if (appName = "")
        appName := StrReplace(exeName, ".exe", "")

    If WinExist("ahk_exe " . exeName)
        WinActivate()
    Else if (appPath != "")
        Run(appPath)
    Else
        MsgBox(appName . " niet gevonden in (" . appPath . ")")
}

ExpandEnvVars(path) {
    ; Vervang alle gangbare omgevingsvariabelen
    result := StrReplace(path, "%USERPROFILE%", EnvGet("USERPROFILE"))
    result := StrReplace(result, "%USERNAME%", EnvGet("USERNAME"))
    result := StrReplace(result, "%LOCALAPPDATA%", EnvGet("LOCALAPPDATA"))
    result := StrReplace(result, "%PROGRAMFILES%", EnvGet("PROGRAMFILES"))
    result := StrReplace(result, "%PROGRAMFILES(X86)%", EnvGet("PROGRAMFILES(X86)"))
    result := StrReplace(result, "%APPDATA%", EnvGet("APPDATA"))
    return result
}

FindAppPath(appName) {
    iniFile := A_AppData . "\ahk\paths.ini"

    ; Haal de subfolder/executable op voor de applicatie
    subPath := IniRead(iniFile, "Applications", appName, "")
    if (subPath = "")
        ; MsgBox("ini File:" . subPath)
        return ""

    ; Probeer eerst CommonPaths
    pathIndex := 1
    while true {
        pathKey := "Path" . pathIndex
        basePath := IniRead(iniFile, "CommonPaths", pathKey, "ERROR")

        if (basePath = "ERROR")
            break

        expandedPath := ExpandEnvVars(basePath)
        fullPath := expandedPath . "\" . subPath

        ; MsgBox(expandedPath)
        if FileExist(fullPath) {
            return fullPath
        }

        pathIndex++
    }

    ; Probeer daarna SpecialPaths
    Loop Parse, "Adobe,MicrosoftOffice,MicrosoftLocal,MicrosoftWindowsApps,StartMenuPrograms,ProgramDataStartMenu,Steam", "," {
        specialPath := IniRead(iniFile, "SpecialPaths", A_LoopField, "ERROR")
        if (specialPath = "ERROR")
            continue

        expandedPath := ExpandEnvVars(specialPath)
        fullPath := expandedPath . "\" . subPath

        if FileExist(fullPath) {
            return fullPath
        }
    }

    return ""
}

CloseAllWindows() {
    for hwnd in WinGetList() {
        title := WinGetTitle(hwnd)
        exe := WinGetProcessName(hwnd)
        ; Skip empty titles, Program Manager, and VSCode (Code.exe)
        if (title = "" || title = "Program Manager" || exe = "Code.exe")
            continue
        try WinClose(hwnd)
    }
}