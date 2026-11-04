@echo off
cd /d "%~dp0"

:: 1. Ensure portable mode marker exists
if not exist "portable_mode.txt" type nul > "portable_mode.txt"

:: 2. Clean crash sentinels to prevent Safe Mode prompt
if exist "config\obs-studio\.sentinel\*" del /q "config\obs-studio\.sentinel\*"

:: 3. Strip rogue [Locations] block if OBS 33 migration ever re-injects it
powershell -NoProfile -ExecutionPolicy Bypass -Command "$g = 'config\obs-studio\global.ini'; if (Test-Path $g) { $c = Get-Content $g -Raw; if ($c -match '\[Locations\]') { $c = $c -replace '(?ms)^\[Locations\].*?(?=^\[|\Z)', ''; [System.IO.File]::WriteAllText((Resolve-Path $g), $c.TrimEnd() + [Environment]::NewLine, [System.Text.Encoding]::UTF8) } }"

:: 4. Launch OBS Studio with explicit portable flag
start "" "bin\64bit\obs64.exe" --portable
