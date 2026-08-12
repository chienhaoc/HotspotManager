# Changelog 📜

All notable changes to the HotspotManager project will be documented in this file.

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
