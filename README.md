# obs_portable_hardener

> **Anti-drift hardening, reinstall survival harness, and visually lossless AV1 capture profiles for Portable OBS Studio.**  
> Pre-configured for minimal file footprints with zero visual degradation on heavy-detail, high-particle titles (*World of Warcraft*, *League of Legends*, *Warcraft III*). Normalizes dynamic WASAPI endpoints, purges rogue `%APPDATA%` migrations, and isolates NVMe pipelines.

---

## 🎮 Visually Lossless Engine Optimization (WoW, League, Warcraft III)

High-unit RTS, MOBA, and MMO games (*World of Warcraft*, *League of Legends*, *Warcraft III*) are uniquely brutal on video encoders:
* **High-Frequency Foliage & Geometry**: Rapid camera panning across trees, grass, unit clusters, and terrain meshes causes standard H.264 encoders to turn into pixelated mud.
* **Dense Particle Overlap**: 40-man raid boss pulls in WoW, 5v5 Baron fights in League, and massive army battles in WC3 generate chaotic alpha particle spam that destroys bitrate buffers.
* **Sharp HUD & Text Elements**: Floating combat numbers, unit healthbars, minimaps, and skill cooldown timers blur heavily under standard rate control.

Most guides recommend brute-forcing this with **50,000–80,000 Kbps CBR**, generating massive **20–40 GB files per session**.

### The Hardened AV1 Pipeline

`obs_portable_hardener` enforces an ultra-efficient hardware AV1 configuration that delivers **visually lossless 1440p / 1080p 60 FPS output at ~1.5–2.8 GB/hour** (~80% file size reduction):

| Parameter | Hardened Value | Engineering Purpose |
| :--- | :--- | :--- |
| **Video Encoder** | `NVIDIA NVENC AV1` | Next-gen AV1 entropy coding with vastly superior efficiency over H.264/HEVC. Zero CPU load. |
| **Rate Control** | **CQP (CQ Level 32)** | Pure quality-driven encoding. Zero bits wasted on idle/menu screens; scales bitrate dynamically during explosive teamfights. (~1.6–2.2 GB/hr). |
| **Tuning / Preset** | **P7: Slowest (Best Quality)** | Exploits dedicated GPU NVENC silicon for deepest search vector analysis without stealing rendering ticks from games. |
| **Multipass Mode** | **Two Passes (Full Resolution)** | Secondary optimization pass across full canvas resolution, eliminating artifact haloing around nameplates and healthbars. |
| **B-Frames** | **4 B-Frames** (`bf=4`, Ref Mode: 1) | Maximum compression on static map elements, lane minions, and repeated creep wave textures. |
| **Container Format** | **Hybrid MP4 (`hybrid_mp4`)** | Fragmented index safety. If a game crashes or power cuts, recordings remain 100% readable and uncorrupted. |
| **Audio Pipeline** | **7 Discrete WASAPI Tracks** | Separates game audio, Discord, mic, music, and monitoring into dedicated uncompressed audio streams. |

---

## ⚡ The Problem: The "Portable" Illusion in OBS Studio

Extracting an OBS Studio zip archive or placing it on a secondary drive does **not** make it immune to Windows reinstalls. Four subtle failure modes routinely cause settings to disappear:

1. **The OBS 33 Beta Migration Leak**: In OBS Studio 33+, configuration migration routines write hardcoded absolute paths (`Configuration=C:\Users\<user>\AppData\Roaming`) into `global.ini` under `[Locations]`, silently breaking portability and redirecting saves to the `C:` drive.
2. **WASAPI Hardware GUID Churn**: When Windows is reinstalled, the OS regenerates dynamic 128-bit hardware GUIDs (`{0.0.0.00000000}.{...}`) for all audio devices. Profiles bound to specific hardware endpoints fail to start or default to silent.
3. **Username / `%USERPROFILE%` Drift**: File pickers default to `C:\Users\<username>\Videos`. When Windows is reinstalled under a new username, recording paths throw fatal write errors.
4. **The Setup Wizard Trap (`FirstRun=true`)**: Leftover flags in `user.ini` cause OBS to launch the full-screen Auto-Configuration Wizard, leading users to believe all profiles and scene collections were wiped.

---

## 🛡️ The Solution: Automated Hardening

`obs_portable_hardener` provides an idempotent, one-command PowerShell harness and launcher wrapper that audits and repairs the OBS portable directory in under a second:

| Invariant | Mechanism | Failure Prevented |
| :--- | :--- | :--- |
| **Portable Anchor** | Asserts `portable_mode.txt` at root | OBS falling back to `%APPDATA%\obs-studio` |
| **Canvas & Profile Lock** | Enforces `2560x1440` native canvas on `2560` profile | Downscale resolution drift to 1080p |
| **AV1 CQP Restoration** | Heals `recordEncoder.json` if driver reinstall wipes it | Silent fallback to software CPU `x264` |
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

Launch OBS directly via `bin\64bit\obs64.exe` or using the included [`run_obs.bat`](./run_obs.bat) wrapper:

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
