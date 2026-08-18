# HotspotManager 📶

[中文說明](README.zh-TW.md) | English

A lightweight, native Windows system tray application for managing the built-in **Mobile Hotspot** feature.  
Built using pure **PowerShell 5.1 + WinForms + Windows WinRT API** — **100% native, zero external dependencies**.

---

## ✨ Features

- 🟢 **System Tray Integration**:
  - Live color-coded tray icon: 🟢 Green (Hotspot On), 🔴 Red (Hotspot Off), 🟡 Yellow (Busy)
  - Right-click context menu to Start / Stop hotspot, Open Panel, or Exit
  - Double-click tray icon to toggle control panel visibility
- 🎛️ **Modern Control Panel**:
  - Single adaptive **Toggle Button** (Start/Stop) with state feedback
  - Real-time status display: State, SSID, Password, and Internet Source profile
  - DPI-aware, responsive layout that supports window resizing
- 📱 **Connected Devices Tracking**:
  - Displays connected device details: Hostname, IP Address, MAC Address
  - ⏱️ **Connection Duration**: Tracks how long each device has been connected
- 🔄 **WAN Auto-Recovery**:
  - Automatically turns hotspot back on as soon as WAN connectivity (e.g. iPhone USB tethering) is restored (WAN UP)
  - Shows clear waiting state when WAN is disconnected
- 💤 **Integrated Sleep Support (Allow PC Sleep)**:
  - Built-in one-click toggle in the tray context menu (`Allow PC Sleep`) to configure Windows `powercfg /requestsoverride`
  - Unblocks Windows from sleeping while Mobile Hotspot is running, allowing the PC to sleep and wake smoothly without driver hangs
- 💾 **Persistent Settings**:
  - Automatically saves and restores your preferred window dimensions and column widths
- 🚀 **Silent Launcher**:
  - Includes a VBScript wrapper (`HotspotManager.vbs`) to start silently without flashing console windows
  - One-click installer (`Install.ps1`) to add to Windows Startup

---

## 💻 Requirements

- **OS**: Windows 10 / 11
- **PowerShell**: PowerShell 5.1 (built-in)
- **Permissions**: Standard user privileges (no admin rights required for normal operation)

---

## 🚀 Quick Start

### 1. Clone the repository

```powershell
git clone https://github.com/chienhaoc/HotspotManager.git E:\git\HotspotManager
cd E:\git\HotspotManager
```

### 2. Run directly

Double-click **`HotspotManager.vbs`** to launch silently in the background. Look for the Wi-Fi icon in your system tray (near the clock).

### 3. Enable Auto-Start on Login (Optional)

Run `Install.ps1` to add a silent shortcut to your Windows Startup folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install.ps1
```

To remove from startup:

```powershell
powershell -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

---

## 🛠️ How It Works

Windows Mobile Hotspot APIs are exposed via WinRT namespaces (`Windows.Networking.NetworkOperators` & `Windows.Networking.Connectivity`).  
`HotspotManager.ps1` dynamically loads these WinRT classes via Reflection (`[System.WindowsRuntimeSystemExtensions]::AsTask`) and renders a dark-themed WinForms UI entirely within native PowerShell.

Settings are persisted locally at `%LOCALAPPDATA%\HotspotManager\config.json`.

---

## 📁 Repository Structure

```
HotspotManager/
├── HotspotManager.ps1   # Main PowerShell application
├── HotspotManager.vbs   # Silent VBScript launcher (no console window)
├── Install.ps1          # Adds HotspotManager to Windows Startup
├── Uninstall.ps1        # Removes HotspotManager from Windows Startup
├── README.md            # English Documentation
├── README.zh-TW.md      # Traditional Chinese Documentation
├── CONTRIBUTING.md      # Guidelines for contributors
├── CHANGELOG.md         # Version release history
└── LICENSE              # MIT License
```

---

## 📄 License

Distributed under the [Apache License 2.0](LICENSE).
