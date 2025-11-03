@echo off
setlocal enabledelayedexpansion

echo ========================================
echo   AutoHotkey Script Deployment
echo ========================================
echo.

REM Define paths
set "APPDATA_AHK=%APPDATA%\ahk"
set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "CURRENT_DIR=%~dp0"

echo Current directory: %CURRENT_DIR%
echo AppData AHK folder: %APPDATA_AHK%
echo Startup folder: %STARTUP_FOLDER%
echo.

REM Create AppData\ahk folder if it doesn't exist
if not exist "%APPDATA_AHK%" (
    echo Creating AppData\ahk directory...
    mkdir "%APPDATA_AHK%"
    if errorlevel 1 (
        echo ERROR: Failed to create AppData\ahk directory
        pause
        exit /b 1
    )
    echo Directory created successfully.
) else (
    echo AppData\ahk directory already exists.
)

echo.

REM copy all .ini files to AppData\ahk
echo Copying .ini files to AppData\ahk...
set "ini_found=0"
for %%f in ("%CURRENT_DIR%*.ini") do (
    if exist "%%f" (
        set "ini_found=1"
        echo Copying: %%~nxf
        copy "%%f" "%APPDATA_AHK%\" >nul
        if errorlevel 1 (
            echo WARNING: Failed to copy %%~nxf
        ) else (
            echo Successfully copied: %%~nxf
        )
    )
)

if !ini_found! == 0 (
    echo No .ini files found in current directory.
) else (
    echo All .ini files copied successfully.
)

echo.

REM Copy *.ahk to startup folder
if exist "%CURRENT_DIR%*.ahk" (
    echo Copying *.ahk to startup folder...
    copy "%CURRENT_DIR%*.ahk" "%STARTUP_FOLDER%\" >nul
    if errorlevel 1 (
        echo ERROR: Failed to copy *.ahk to startup folder
        pause
        exit /b 1
    ) else (
        echo Successfully copied *.ahk to startup folder.
    )
) else (
    echo ERROR: *.ahk not found in current directory
    pause
    exit /b 1
)


REM Copy lib-folder (recursively) to %APPDATA%\ahk\lib
if exist "%CURRENT_DIR%lib" (
    echo Copying lib folder to %APPDATA_AHK%\lib...
    xcopy "%CURRENT_DIR%lib" "%APPDATA_AHK%\lib" /E /I /Y >nul
    if errorlevel 1 (
        echo ERROR: Failed to copy lib folder to %APPDATA_AHK%\lib
        pause
        exit /b 1
    ) else (
        echo Successfully copied lib folder to %APPDATA_AHK%\lib.
    )
) else (
    echo ERROR: lib folder not found in current directory
    pause
    exit /b 1
)

:: Create a shortcut to the BluetoothDeviceConnector script in the AppData lib folder
set "BT_FOLDER=%APPDATA_AHK%\lib\BluetoothDeviceConnector"
if not exist "%BT_FOLDER%" (
    echo BluetoothDeviceConnector folder not found at %BT_FOLDER% - creating it...
    mkdir "%BT_FOLDER%"
)

:: Try to find AutoHotkey executable (search common ProgramFiles locations)
set "AHK_EXE="
for %%D in ("%ProgramFiles%" "%ProgramFiles(x86)%") do (
    set "candidate=%%~D\AutoHotkey\v2\AutoHotkey.exe"
    if exist "!candidate!" (
        if "!AHK_EXE!"=="" set "AHK_EXE=!candidate!"
    )
)

if "%AHK_EXE%"=="" (
    echo WARNING: AutoHotkey executable not found in Program Files. Shortcut will not be created.
) else (
    echo Creating shortcut for BluetoothDeviceConnector in %BT_FOLDER%...
    powershell -NoProfile -Command "$W=New-Object -ComObject WScript.Shell; $s=$W.CreateShortcut('%BT_FOLDER%\\BluetoothDeviceConnector.lnk'); $s.TargetPath='%AHK_EXE%'; $s.Arguments='"%APPDATA_AHK%\\lib\\BluetoothDeviceConnector\\bluetooth_device_connector.ahk"'; $s.WorkingDirectory='%BT_FOLDER%'; $s.Save()"
    if errorlevel 1 (
        echo ERROR: Failed to create shortcut.
    ) else (
        echo Shortcut created: %BT_FOLDER%\BluetoothDeviceConnector.lnk
    )
)

:: Also copy the shortcut to the user's Desktop and to this repository folder
set "SHORTCUT=%BT_FOLDER%\BluetoothDeviceConnector.lnk"
if exist "%SHORTCUT%" (
    set "DESKTOP=%USERPROFILE%\Desktop"
    echo Copying shortcut to Desktop: %DESKTOP%
    copy /Y "%SHORTCUT%" "%DESKTOP%\" >nul
    if errorlevel 1 (
        echo WARNING: Failed to copy shortcut to Desktop (%DESKTOP%)
    ) else (
        echo Shortcut copied to Desktop.
    )

    echo Copying shortcut to repo folder: %CURRENT_DIR%
    copy /Y "%SHORTCUT%" "%CURRENT_DIR%" >nul
    if errorlevel 1 (
        echo WARNING: Failed to copy shortcut to repo folder (%CURRENT_DIR%)
    ) else (
        echo Shortcut copied to repo folder.
    )
) else (
    echo No shortcut found to copy to Desktop or repo folder.
)

echo.
echo ========================================
echo   Deployment completed successfully!
echo ========================================
echo.
echo Files deployed:
echo - INI files copied to: %APPDATA_AHK%
echo - *.ahk copied to: %STARTUP_FOLDER%
echo - lib folder copied to: %APPDATA_AHK%\lib
echo.
echo Your AutoHotkey script will now run automatically at startup.
echo.
pause