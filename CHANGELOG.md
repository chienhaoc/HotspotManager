# Changelog 📜

All notable changes to the HotspotManager project will be documented in this file.

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
