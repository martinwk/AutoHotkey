FindExeRecursive(base, exeName, depth := 3) {
    if (depth < 1)
        return ""
    direct := base . "\" . exeName
    if FileExist(direct)
        return direct
    Loop Files base "\\*", "D" { ; "D" = Directories only
        subDir := A_LoopFileFullPath
        subExe := subDir . "\" . exeName
        if FileExist(subExe)
            return subExe
        ; Recursively search deeper
        found := FindExeRecursive(subDir, exeName, depth - 1)
        if (found != "")
            return found
    }
    return ""
}

FindExeLocations(exeList) {
    result := Map()
    iniFile := A_AppData . "\ahk\paths.ini"
    ; Verzamel alle zoekpaden uit CommonPaths
    searchPaths := []
    pathIndex := 1
    while true {
        pathKey := "Path" . pathIndex
        basePath := IniRead(iniFile, "CommonPaths", pathKey, "ERROR")
        if (basePath = "ERROR")
            break
        searchPaths.Push(ExpandEnvVars(basePath))
        pathIndex++
    }
    ; Zoek voor elke exe
    for exeName in exeList {
        found := ""
        for base in searchPaths {
            ; Zoek voor diepere niveaus als niet gevonden
            for base in searchPaths {
                found := FindExeRecursive(base, exeName, 3)
                if (found != "")
                    break
            }
            if (found != "")
                break
        }
        if (found = "") {
            MsgBox "ERROR: " exeName " not found in any search path or its subfolders!"
        }
        result[exeName] := found


    }
    return result
}
OnlyRun(exeName, locations, appName := "") {
    ; locations is a map of exeName to path
    ; Gebruik executable naam als appName als niet opgegeven
    if (appName = "")
        appName := StrReplace(exeName, ".exe", "")

    appPath := locations[exeName]
    if (appPath != "")
        Run(appPath)
    Else
        MsgBox(appName . " niet gevonden in (" . appPath . ")")
}
ActivateOrRun(exeName, locations, appName := "") {
    ; Gebruik executable naam als appName als niet opgegeven
    ; locations is a map of exeName to path
    if (appName = "")
        appName := StrReplace(exeName, ".exe", "")

    appPath := locations[exeName]

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