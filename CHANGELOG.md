# Changelog

All notable changes to SharedComputing will be documented in this file.

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
