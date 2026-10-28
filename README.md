# HotspotManager 📶

[繁體中文說明](README.zh-TW.md) | English

A lightweight, native Windows system tray application for managing the built-in **Mobile Hotspot** feature.  
Built using a single native **C# (.NET Framework) tray application + Windows WinRT API** (compiled directly via `csc.exe` built into Windows, ~34 MB RAM) — **100% native, zero external dependencies, no SDK required**.

---

## ✨ Features

- 🟢 **System Tray Integration**:
  - Live color-coded tray icon: 🟢 Green (Hotspot On), 🔴 Red (Hotspot Off), 🟡 Yellow (Busy / Waiting)
  - Right-click context menu: Start / Stop Hotspot, Repair Network, Allow PC Sleep, Open Panel, Exit
  - Double-click tray icon to toggle control panel visibility
- 🎛️ **Modern Control Panel**:
  - Single adaptive **Toggle Button** (Start/Stop) with instant visual feedback
  - Real-time status display: State, SSID, Password, and Internet Source profile
  - DPI-aware, responsive layout that supports window resizing
- 📱 **Connected Devices Tracking**:
  - Displays connected device details: Hostname, IP Address, MAC Address
  - ⏱️ **Connection Duration**: Tracks how long each device has been connected
- 🔄 **WAN Auto-Recovery**:
  - Automatically resumes hotspot sharing as soon as WAN connectivity (e.g. iPhone USB tethering) is restored (WAN UP)
  - Auto-stops when WAN drops to avoid leaving clients connected to a dead network
- 🛠️ **Network Repair & Cache Flush**:
  - Built-in `Repair Network (Fix No Internet)` button and tray action
  - Automatically clears ARP and DNS client caches and re-initializes WLAN / tethering bindings when network conflicts arise
- 💤 **Integrated Sleep Support (Allow PC Sleep)**:
  - Built-in one-click toggle in the tray context menu (`Allow PC Sleep`) to configure Windows `powercfg /requestsoverride`
  - Unblocks Windows from sleeping while Mobile Hotspot is running, allowing the PC to sleep and wake smoothly without driver hangs
- ⚡ **Ultra-Low Resource Footprint**:
  - Pure C# executable using only ~34 MB RAM and ~9 threads (down from ~131 MB and 21 threads in earlier scripting implementations)
  - Lazy panel creation and dynamic polling intervals (5s idle, 2s when panel is open)
- 💾 **Persistent Settings**:
  - Automatically saves and restores your preferred window dimensions and column widths in `%LOCALAPPDATA%\HotspotManager\config.ini`

---

## 💻 Requirements

- **OS**: Windows 10 / 11
- **.NET Framework**: 4.5+ (built into Windows 10 & 11)
- **Permissions**: Standard user privileges (no administrator rights required for normal operation)

---

## 🚀 Quick Start

### 1. Clone the repository

```powershell
git clone https://github.com/chienhaoc/HotspotManager.git C:\git\HotspotManager
cd C:\git\HotspotManager
```

### 2. Build

Run `Build.bat` to compile `HotspotManager.exe` using Windows' built-in C# compiler (`csc.exe`):

```cmd
Build.bat
```

### 3. Install & Auto-Start (Recommended)

Run `Install.ps1` to install `HotspotManager.exe` into `%LOCALAPPDATA%\Programs\HotspotManager`, create shortcuts in Startup and Start Menu, and register with Windows Settings:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install.ps1
```

To uninstall completely:

```powershell
powershell -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

---

## 🛠️ How It Works

Windows Mobile Hotspot APIs are exposed via WinRT namespaces (`Windows.Networking.NetworkOperators` & `Windows.Networking.Connectivity`).  
`HotspotManager.cs` bridges WinRT asynchronous operations directly into standard .NET tasks and renders a clean, dark-themed WinForms UI.

Settings are persisted locally at `%LOCALAPPDATA%\HotspotManager\config.ini`.

---

## 📁 Repository Structure

```
HotspotManager/
├── HotspotManager.cs    # Application source code (C#)
├── Build.bat            # Compiles HotspotManager.exe (using built-in csc.exe)
├── Install.ps1          # Installs to %LOCALAPPDATA%\Programs & adds to Startup
├── Uninstall.ps1        # Uninstalls application, shortcuts, and settings
├── README.md            # English Documentation
├── README.zh-TW.md      # Traditional Chinese Documentation
├── CONTRIBUTING.md      # Guidelines for contributors
├── CHANGELOG.md         # Version release history
└── LICENSE              # Apache License 2.0
```

---

## 📄 License

This project is licensed under the [Apache License 2.0](LICENSE).
