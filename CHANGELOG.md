# Changelog 📜

All notable changes to the HotspotManager project will be documented in this file.

## [2.0.0] - 2026-10-28

### Changed
- **Complete C# Rewrite**: Rewrote the entire project from PowerShell 5.1/VBScript into a single native C# (.NET Framework) Windows application (`HotspotManager.exe`), eliminating console flashing and `0xc0000142` launch failures completely.
- **Dramatically Reduced Resource Usage**:
  - Memory consumption dropped from ~131 MB to ~34 MB (working set) / ~25 MB (private bytes).
  - Background threads reduced from 21 to 9.
  - Idle CPU usage dropped to ~0%.
- **Lazy UI & Dynamic Polling**: The control panel form is now constructed on-demand and fully collected when closed; refresh interval dynamically adjusts between 5s (tray idle) and 2s (panel active).
- **Proper Application Installation**: `Install.ps1` installs `HotspotManager.exe` to `%LOCALAPPDATA%\Programs\HotspotManager`, registers Start Menu shortcuts, and adds a per-user entry in Windows Settings / Apps.
- **Config Migration**: Migrated configuration format from JSON to lightweight INI at `%LOCALAPPDATA%\HotspotManager\config.ini`.

### Added
- **Build Script (`Build.bat`)**: Single-click build tool using Windows' built-in `csc.exe` without requiring external SDKs or tools.
- **Repair Network Action**: One-click `Repair Network (Fix No Internet)` in both the tray context menu and main window to flush ARP and DNS client caches and reset WLAN AutoConfig services.

## [1.1.0] - 2026-08-18

### Added
- **WAN Auto-Recovery**: Automatically restarts Mobile Hotspot sharing as soon as WAN connectivity (e.g. iPhone USB network) comes back online.
- **Sleep & Suspend Power Management**: Registers `SystemEvents.PowerModeChanged` to immediately stop hotspot sharing when the PC enters Sleep/Suspend, preventing network adapter power request locks and allowing Windows to sleep cleanly.
- **Auto-Resume on Wake**: Automatically resumes hotspot sharing after the computer wakes from sleep.
- Faster 4s refresh cycle for prompt WAN recovery detection.

## [1.0.0] - 2026-08-12

### Added
- Native System Tray application for Windows Mobile Hotspot built with PowerShell 5.1 and WinForms.
- Dynamic color-coded tray icon (Green = On, Red = Off, Yellow = Busy).
- Double-click tray icon to show/hide panel; right-click context menu for quick actions.
- Single toggle button for intuitive Start/Stop hotspot control.
- Connected devices table with Hostname, IP Address, MAC Address, and **Connected Duration**.
- DPI-aware, responsive resizable layout using `TableLayoutPanel`.
- Configuration persistence (`%LOCALAPPDATA%\HotspotManager\config.json`) for window dimensions and column widths.
- VBScript wrapper (`HotspotManager.vbs`) for silent background launching without console windows.
- Auto-start installer (`Install.ps1`) and uninstaller (`Uninstall.ps1`).
- Dual English & Traditional Chinese documentation (`README.md` & `README.zh-TW.md`).
