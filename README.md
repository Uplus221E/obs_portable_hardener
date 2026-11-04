# obs_portable_hardener

> **Anti-drift hardening and Windows reinstall survival harness for Portable OBS Studio.**  
> Enforces path invariance, normalizes dynamic WASAPI audio endpoints, purges rogue `%APPDATA%` migrations, and guarantees deterministic persistence across clean OS reinstalls.

---

## ⚡ The Problem: The "Portable" Illusion in OBS Studio

Extracting an OBS Studio zip archive or placing it on a secondary drive does **not** make it immune to Windows reinstalls. In practice, four subtle failure modes routinely cause settings to disappear:

1. **The OBS 33 Beta Migration Leak**: In OBS Studio 33+, configuration migration routines write hardcoded absolute paths (`Configuration=C:\Users\<user>\AppData\Roaming`) into `global.ini` under `[Locations]`, silently breaking portability and redirecting saves to the `C:` drive.
2. **WASAPI Hardware GUID Churn**: When Windows is reinstalled, the operating system generates brand-new internal 128-bit GUIDs (`{0.0.0.00000000}.{...}`) for all audio devices. Profiles bound to specific hardware endpoints fail to start or default to silent.
3. **Username / `%USERPROFILE%` Drift**: Standard file pickers encourage selecting default folders like `C:\Users\<username>\Videos`. When Windows is reinstalled under a new username or machine name, all recording paths throw fatal write errors.
4. **The Setup Wizard Trap (`FirstRun=true`)**: Leftover flags in `user.ini` cause OBS to open with the full-screen Auto-Configuration Wizard, leading users to believe all profiles and scene collections were lost.

---

## 🛡️ The Solution: Automated Hardening

`obs_portable_hardener` provides an idempotent, one-command PowerShell harness and launcher wrapper that audits and repairs the OBS portable directory in under a second:

| Invariant | Mechanism | Failure Prevented |
| :--- | :--- | :--- |
| **Portable Anchor** | Asserts `portable_mode.txt` at root | OBS falling back to `%APPDATA%\obs-studio` |
| **Path Invariance** | Normalizes output paths to dedicated NVMe storage (`D:\OBS_Recordings`) | Broken recordings after username changes (`C:\Users\<old>`) |
| **WASAPI Normalization** | Replaces static hardware GUIDs with `"default"` | Silent audio captures after clean Windows installs |
| **Migration Guard** | Regex-purges `[Locations]` blocks from `global.ini` | OBS 33 beta redirecting scene collections back to `C:` |
| **Crash Sanitization** | Wipes transient `.sentinel` crash artifacts | Spurious "Start in Safe Mode" dialogs on startup |
| **Git Baseline** | Automates `.gitignore` and revision tracking in `config/` | Undetected configuration drift or corrupted scene files |

---

## 🚀 Quick Start

### 1. Run the Hardening Harness

Run directly in PowerShell (no installation required):

```powershell
powershell -ExecutionPolicy Bypass -File "C:\fitxategiak\aplikazioak\tresnak\obs_studio\harden_obs_portable.ps1"
```

*By default, the script targets `C:\fitxategiak\aplikazioak\tresnak\obs_studio`. You can pass any custom directory via the `-ObsRoot` parameter:*

```powershell
.\harden_obs_portable.ps1 -ObsRoot "D:\Tools\obs-studio"
```

### 2. Launching OBS Studio

Always launch OBS via the included [`run_obs.bat`](./run_obs.bat) wrapper:

```bat
:: run_obs.bat
@echo off
cd /d "%~dp0"
if not exist "portable_mode.txt" type nul > "portable_mode.txt"
if exist "config\obs-studio\.sentinel\*" del /q "config\obs-studio\.sentinel\*"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$g = 'config\obs-studio\global.ini'; if (Test-Path $g) { $c = Get-Content $g -Raw; if ($c -match '\[Locations\]') { $c = $c -replace '(?ms)^\[Locations\].*?(?=^\[|\Z)', ''; [System.IO.File]::WriteAllText((Resolve-Path $g), $c.TrimEnd() + [Environment]::NewLine, [System.Text.Encoding]::UTF8) } }"
start "" "bin\64bit\obs64.exe" --portable
```

---

## ⚙️ Architecture & File Layout

```text
obs_studio/
├── bin/64bit/obs64.exe      # Upstream binary
├── portable_mode.txt         # Root portable mode anchor
├── run_obs.bat               # Hardened launch wrapper
├── harden_obs_portable.ps1  # Automated audit & sanitization harness
└── config/obs-studio/        # Git-tracked configuration repository
    ├── .gitignore            # Excludes logs, dumps, and Chromium cookies
    ├── global.ini            # Stripped of rogue [Locations] overrides
    ├── user.ini              # Enforces FirstRun=false
    └── basic/
        ├── profiles/         # 1920 & 2560 profiles pointing to persistent storage
        └── scenes/           # Untitled.json with normalized WASAPI "default" audio
```

---

## 📜 Technical Invariants

1. **Lindy-Tested Primitives**: Zero external dependencies. Operates strictly via native PowerShell and standard stream transformations.
2. **Deterministic Output Storage**: Output paths are decoupled from OS user folders and routed to persistent NVMe arrays.
3. **Zero DPAPI Assumptions**: Stream keys (`service.json`) are maintained in flat JSON files rather than ephemeral Chromium browser cookies that fail across OS reinstall boundaries.
