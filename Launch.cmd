@echo off
setlocal
cd /d "%~dp0"
set "WARDENS_GODOT=C:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64"
if not exist "%WARDENS_GODOT%_console.exe" goto missing_engine
if not exist "work" mkdir "work"
if not exist "work\.gdignore" type nul > "work\.gdignore"
echo Preparing Wormhole Wardens assets...
"%WARDENS_GODOT%_console.exe" --headless --editor --import --path "." --quit > "work\import.log" 2>&1
if errorlevel 1 goto import_failed
findstr /C:"ERROR:" "work\import.log" >nul
if not errorlevel 1 goto import_failed
start "Wormhole Wardens" "%WARDENS_GODOT%.exe" --path "." --log-file "work/game.log"
exit /b 0
:missing_engine
echo Godot was not found at "%WARDENS_GODOT%_console.exe".
echo Update WARDENS_GODOT in this launcher to match your installation.
pause
exit /b 1
:import_failed
echo Asset preparation failed:
type "work\import.log"
pause
exit /b 1
