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
    rem Remove existing contents in destination lib folder to ensure a clean copy
    if exist "%APPDATA_AHK%\lib\*" (
        echo Removing existing contents from %APPDATA_AHK%\lib...
        for /d %%X in ("%APPDATA_AHK%\lib\*") do rd /s /q "%%~X"
        del /q "%APPDATA_AHK%\lib\*.*" 2>nul
    )

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