# Changelog

All notable changes to SharedComputing will be documented in this file.

## [2026-04-06] — ResNet50 Install Pipeline & UX

### Added
- Added end-to-end `ResNet50` support for LAN training path (UI selection -> backend/master config -> worker model construction).
- Added in-app install flow for supported architectures (`ResNet18`, `ResNet50`) from Screen 2.

### Changed
- Updated architecture availability messaging so `ResNet18` and `ResNet50` are treated as supported models.
- Upgraded model installer pipeline to async + progress-tracked status (`GET /models/install/{model}` returns status/progress/error/path).
- Added install progress labels in the UI (e.g., `Installing 37%`) and polling until completion/failure.

### Fixed
- Fixed local repo path detection in the macOS app so model-install checks resolve correctly in common workspace locations.
- Fixed installer SSL certificate handling in backend downloads using `certifi` so weight downloads complete reliably.

## [2026-04-06] — Screen 3 Telemetry Pipeline Fix

### Changed
- Fixed Screen 3 worker telemetry parsing to match backend worker fields (`last_cpu_pct`, `last_ram_used_gb`, `ram_total_gb`, `last_gpu_pct`, `last_temp_c`) with fallback compatibility for older keys.
- Updated local RAM usage calculation in the macOS app to an Activity-Monitor-like estimate (`internal - purgeable + wired + compressed`) for more intuitive values.
- Updated run-status handling in the UI to support backend statuses (`succeeded`, `failed`, `stopped`) while keeping compatibility with legacy labels.
- Updated `worker.py` metrics collection so RAM sent to the master/backend prefers an Activity-Monitor-like value (`wired + active + compressed`) when available, with automatic fallback to `psutil`'s `used` value on unsupported platforms.

### Notes
- This resolves misleading RAM/telemetry values on the Connect page caused by key mismatches and differing memory accounting semantics.
- `worker.py` still reports GPU as `None` (N/A in UI) because no stable cross-platform GPU percentage API is currently wired for workers.

## [2025-03-11] — 4-Screen UI Restructuring

### Added
- **Sequential Mode**: Wizard-style navigation with step indicators (1→2→3→4) and Next/Back buttons
- **4-Screen Mode**: 2×2 debug grid showing all screens simultaneously, toggled via toolbar
- **Screen 1 — Dataset & Environment Setup**: Dataset picker, Python path, master.py path, Python version check (TEMP)
- **Screen 2 — Model & Training**: Training hyperparameters (rounds, epochs, batch, LR, timeout), model selector dropdown (TEMP), device info panel (TEMP)
- **Screen 3 — Device Connection**: Master IP display, worker count, Start/Stop/Begin Training controls, network topology visualization (TEMP), per-worker detail cards (TEMP)
- **Screen 4 — Results & Logs**: Training log with auto-scroll, DB results table (TEMP), LAN/WiFi connection toggle (TEMP)
- **TEMP badges**: Orange indicators on all placeholder components for future implementation

### Changed
- Restructured `ContentView.swift` from a single `HSplitView` (SetupPanel + LogPanel) into 4 separate screen views with a top toolbar
- `TrainerViewModel` extended with `currentScreen`, `viewMode`, `pythonVersion`, `selectedModel`, `connectionType` state
- Minimum window size increased from 700×600 to 900×700 to accommodate new layout

### Unchanged
- `master.py`, `worker.py`, `run.py` — no backend changes
- All FastAPI endpoints and federated training logic remain identical
