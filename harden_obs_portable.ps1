<#
.SYNOPSIS
    Hardens Portable OBS Studio configuration against Windows reinstalls, hardware changes, and path drift.
.DESCRIPTION
    1. Ensures portable_mode.txt anchor exists.
    2. Cleans crash sentinel files to avoid Safe Mode prompts.
    3. Strips rogue [Locations] overrides introduced by OBS 33 migrations.
    4. Enforces FirstRun=false in user.ini.
    5. Normalizes global audio devices to "default" (immune to Windows WASAPI GUID churn).
    6. Normalizes recording paths away from C:\Users\* to dedicated persistent storage (D:\OBS_Recordings).
    7. Generates run_obs.bat launcher wrapper.
    8. Maintains git baseline tracking.
#>

[CmdletBinding()]
param(
    [string]$ObsRoot = "C:\fitxategiak\aplikazioak\tresnak\obs_studio"
)

$ErrorActionPreference = "Stop"

Write-Host "==> Hardening Portable OBS at: $ObsRoot" -ForegroundColor Cyan

# 1. Ensure portable mode marker
$portableMarker = Join-Path $ObsRoot "portable_mode.txt"
if (-not (Test-Path $portableMarker)) {
    New-Item -ItemType File -Path $portableMarker -Force | Out-Null
    Write-Host "  [+] Created portable_mode.txt" -ForegroundColor Green
} else {
    Write-Host "  [ok] portable_mode.txt present" -ForegroundColor Gray
}

# 2. Clean crash sentinels
$sentinelDir = Join-Path $ObsRoot "config\obs-studio\.sentinel"
if (Test-Path $sentinelDir) {
    Remove-Item (Join-Path $sentinelDir "*") -Force -ErrorAction SilentlyContinue
    Write-Host "  [ok] Cleared crash sentinels" -ForegroundColor Green
}

# 3. Strip [Locations] in global.ini
$globalIni = Join-Path $ObsRoot "config\obs-studio\global.ini"
if (Test-Path $globalIni) {
    $content = Get-Content $globalIni -Raw
    if ($content -match '\[Locations\]') {
        $content = $content -replace '(?ms)^\[Locations\].*?(?=^\[|\Z)', ''
        [System.IO.File]::WriteAllText((Resolve-Path $globalIni), $content.TrimEnd() + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
        Write-Host "  [+] Stripped [Locations] override from global.ini" -ForegroundColor Green
    } else {
        Write-Host "  [ok] global.ini clean (no [Locations] override)" -ForegroundColor Gray
    }
}

# 4. Enforce FirstRun=false in user.ini
$userIni = Join-Path $ObsRoot "config\obs-studio\user.ini"
if (Test-Path $userIni) {
    $content = Get-Content $userIni -Raw
    if ($content -match 'FirstRun=true') {
        $content = $content -replace 'FirstRun=true', 'FirstRun=false'
        [System.IO.File]::WriteAllText((Resolve-Path $userIni), $content, [System.Text.Encoding]::UTF8)
        Write-Host "  [+] Set FirstRun=false in user.ini" -ForegroundColor Green
    } else {
        Write-Host "  [ok] user.ini FirstRun is false" -ForegroundColor Gray
    }
}

# 5. Normalise audio devices in scenes to "default"
$sceneFile = Join-Path $ObsRoot "config\obs-studio\basic\scenes\Untitled.json"
if (Test-Path $sceneFile) {
    $json = Get-Content $sceneFile -Raw -Encoding utf8 | ConvertFrom-Json
    $modified = $false
    if ($json.DesktopAudioDevice1 -and $json.DesktopAudioDevice1.settings.device_id -ne "default") {
        $json.DesktopAudioDevice1.settings.device_id = "default"
        $modified = $true
    }
    if ($json.AuxAudioDevice1 -and $json.AuxAudioDevice1.settings.device_id -ne "default") {
        $json.AuxAudioDevice1.settings.device_id = "default"
        $modified = $true
    }
    if ($modified) {
        $updatedJson = ConvertTo-Json -InputObject $json -Depth 100
        [System.IO.File]::WriteAllText((Resolve-Path $sceneFile), $updatedJson, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  [+] Normalized audio endpoints to 'default' in scenes" -ForegroundColor Green
    } else {
        Write-Host "  [ok] Scenes audio endpoints already set to 'default'" -ForegroundColor Gray
    }
}

# 6. Normalize recording output paths to persistent storage
$storageRoot = "D:\OBS_Recordings"
if (-not (Test-Path $storageRoot)) {
    New-Item -ItemType Directory -Path $storageRoot -Force | Out-Null
}
$stdDir = Join-Path $storageRoot "Standard"
$shortsDir = Join-Path $storageRoot "Shorts_Raw"
if (-not (Test-Path $stdDir)) { New-Item -ItemType Directory -Path $stdDir -Force | Out-Null }
if (-not (Test-Path $shortsDir)) { New-Item -ItemType Directory -Path $shortsDir -Force | Out-Null }

$p1920 = Join-Path $ObsRoot "config\obs-studio\basic\profiles\1920\basic.ini"
if (Test-Path $p1920) {
    $c = Get-Content $p1920 -Raw
    $c = $c -replace 'FilePath=.*', "FilePath=D:/OBS_Recordings/Standard"
    $c = $c -replace 'RecFilePath=.*', "RecFilePath=D:/OBS_Recordings/Standard"
    $c = $c -replace 'FFFilePath=.*', "FFFilePath=D:/OBS_Recordings/Standard"
    [System.IO.File]::WriteAllText((Resolve-Path $p1920), $c, [System.Text.Encoding]::UTF8)
    Write-Host "  [ok] Profile 1920 output paths updated to D:/OBS_Recordings/Standard" -ForegroundColor Gray
}

$p2560 = Join-Path $ObsRoot "config\obs-studio\basic\profiles\2560\basic.ini"
if (Test-Path $p2560) {
    $c = Get-Content $p2560 -Raw
    $c = $c -replace 'FilePath=.*', "FilePath=D:/OBS_Recordings/Shorts_Raw"
    $c = $c -replace 'RecFilePath=.*', "RecFilePath=D:/OBS_Recordings/Shorts_Raw"
    $c = $c -replace 'FFFilePath=.*', "FFFilePath=D:/OBS_Recordings/Shorts_Raw"
    [System.IO.File]::WriteAllText((Resolve-Path $p2560), $c, [System.Text.Encoding]::UTF8)
    Write-Host "  [ok] Profile 2560 output paths updated to D:/OBS_Recordings/Shorts_Raw" -ForegroundColor Gray
}

# 7. Ensure launcher wrapper exists
$launcherBat = Join-Path $ObsRoot "run_obs.bat"
if (-not (Test-Path $launcherBat)) {
    $batContent = @"
@echo off
cd /d "%~dp0"
if not exist "portable_mode.txt" type nul > "portable_mode.txt"
if exist "config\obs-studio\.sentinel\*" del /q "config\obs-studio\.sentinel\*"
powershell -NoProfile -ExecutionPolicy Bypass -Command "`$g = 'config\obs-studio\global.ini'; if (Test-Path `$g) { `$c = Get-Content `$g -Raw; if (`$c -match '\[Locations\]') { `$c = `$c -replace '(?ms)^\[Locations\].*?(?=^\[|\Z)', ''; [System.IO.File]::WriteAllText((Resolve-Path `$g), `$c.TrimEnd() + [Environment]::NewLine, [System.Text.Encoding]::UTF8) } }"
start "" "bin\64bit\obs64.exe" --portable
"@
    [System.IO.File]::WriteAllText($launcherBat, $batContent, [System.Text.Encoding]::ASCII)
    Write-Host "  [+] Created run_obs.bat" -ForegroundColor Green
} else {
    Write-Host "  [ok] run_obs.bat launcher verified" -ForegroundColor Gray
}

# 8. Git sync
$configDir = Join-Path $ObsRoot "config\obs-studio"
if (Test-Path (Join-Path $configDir ".git")) {
    Push-Location $configDir
    try {
        $status = git status --porcelain
        if ($status) {
            git add .
            git commit -m "chore: automated portable configuration sync"
            Write-Host "  [+] Git changes committed cleanly" -ForegroundColor Green
        } else {
            Write-Host "  [ok] Git working tree in equilibrium" -ForegroundColor Gray
        }
    } finally {
        Pop-Location
    }
}

Write-Host "==> Portable OBS hardening complete. System in equilibrium." -ForegroundColor Green
