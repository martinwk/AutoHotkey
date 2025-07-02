@echo off
setlocal

:: Stap 1: Bepaal het pad van dit script
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_NAME=main.ahk"
set "EXE_NAME=autohotkey_main.exe"

:: Stap 2: Pad naar de AutoHotkey compiler (aanpassen indien anders)
set "AHK_COMPILER=C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"

:: Stap 3: Compileer het .ahk script
taskkill /im %EXE_NAME%
"%AHK_COMPILER%" /in "%SCRIPT_DIR%%SCRIPT_NAME%" /out "%SCRIPT_DIR%%EXE_NAME%"

:: Stap 4: Kopieer naar de Windows Startup folder
set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
copy /Y "%SCRIPT_DIR%%EXE_NAME%" "%STARTUP_FOLDER%\"
copy /Y "%SCRIPT_DIR%*.ini" "%STARTUP_FOLDER%\"
@REM FOR %%I in (%SCRIPT_DIR%*.ini) DO COPY /Y "%%I" "%STARTUP_FOLDER%\"

echo Script is gecompileerd en toegevoegd aan de Startup folder.
pause
