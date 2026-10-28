# HotspotManager 📶

[English](README.md) | 繁體中文說明

一款輕量化、純原生的 Windows 系統匣（System Tray）行動熱點管理程式。  
使用 **原生 C# (.NET Framework) + Windows WinRT API** 開發（直接使用 Windows 內建的 `csc.exe` 編譯，常駐僅約 34 MB 記憶體）— **100% 原生、零外部依賴、免額外安裝 SDK**。

---

## ✨ 主要功能

- 🟢 **系統匣常駐 (System Tray)**：
  - 動態圖示狀態指示：🟢 綠色（熱點開啟）、🔴 紅色（熱點關閉）、🟡 黃色（操作中／等待連線）
  - 右鍵選單：快速開啟控制面板、啟動熱點、停止熱點、修復網路連線、睡眠支援切換、結束程式
  - 雙擊系統匣圖示即可快速顯示/隱藏控制面板
- 🎛️ **現代化控制面板**：
  - 單一動態 **開關按鈕 (Toggle Button)**，直覺切換熱點狀態
  - 即時顯示熱點狀態、SSID、密碼及當前網際網路來源 Profile
  - 支援 DPI 自動縮放與視窗自由調整大小
- 📱 **連線裝置追蹤**：
  - 清晰列表顯示：主機名稱 (Hostname)、IP 位址、MAC 位址
  - ⏱️ **連線時長 (Connected Time)**：自動記錄並計算每台裝置的已連線時間
- 🔄 **WAN 斷線自動復原 (WAN Auto-Recovery)**：
  - 外網斷線時自動停止熱點，避免連線裝置懸掛於無效網路
  - 當外網（如 iPhone USB 網路）重新連線 (WAN UP) 時，立即**自動重新啟動熱點分享**
- 🛠️ **網路修復與快取清理 (Repair Network)**：
  - 內建 `Repair Network (Fix No Internet)` 按鈕與右鍵選單項目
  - 一鍵清除 ARP 與 DNS Client 快取，並自動重置 WLAN 服務與熱點連線綁定，徹底解決「已連線但無網際網路」問題
- 💤 **內建睡眠支援切換 (Allow PC Sleep)**：
  - 直接整合於系統匣右鍵選單（`Allow PC Sleep`）與主面板狀態，可一鍵開啟/關閉 Windows 電源覆寫規則 (`powercfg /requestsoverride`)
  - 徹底解除 Windows 行動熱點對電腦睡眠的阻擋，讓電腦能順利進入睡眠並於喚醒時無縫恢復熱點連線
- ⚡ **極致輕量資源佔用**：
  - 純 C# 原生執行檔，常駐記憶體僅約 34 MB，執行緒 9 條（原先腳本版約需 131 MB 記憶體與 21 條執行緒）
  - 面板隨需建立（關閉即釋放記憶體），並採用動態輪詢機制（平常 5 秒，面板開啟時 2 秒）
- 💾 **設定持久化記憶**：
  - 自動儲存並還原視窗大小與表格欄位寬度（儲存於 `%LOCALAPPDATA%\HotspotManager\config.ini`）

---

## 💻 系統需求

- **作業系統**：Windows 10 / 11
- **.NET Framework**：4.5+（Windows 10/11 內建）
- **權限需求**：一般使用者權限即可（正常使用不需系統管理員權限）

---

## 🚀 快速開始

### 1. 下載專案 (Clone)

```powershell
git clone https://github.com/chienhaoc/HotspotManager.git C:\git\HotspotManager
cd C:\git\HotspotManager
```

### 2. 編譯執行檔 (Build)

直接執行 `Build.bat`，即可使用系統內建的 `csc.exe` 編譯出 `HotspotManager.exe`：

```cmd
Build.bat
```

### 3. 安裝與設定開機自動啟動（推薦）

執行 `Install.ps1`，會將 `HotspotManager.exe` 安裝至 `%LOCALAPPDATA%\Programs\HotspotManager`，並在「開機啟動」與「開始功能表」建立捷徑，同時向 Windows 應用程式清單完成註冊：

```powershell
powershell -ExecutionPolicy Bypass -File .\Install.ps1
```

如需完整移除應用程式與開機自啟：

```powershell
powershell -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

---

## 🛠️ 技術原理

Windows 行動熱點 API 封裝於 WinRT 命名空間 (`Windows.Networking.NetworkOperators` 與 `Windows.Networking.Connectivity`)。  
`HotspotManager.cs` 將 WinRT 的異步作業橋接至標準 .NET Task，並透過原生 WinForms 繪製深色主題 UI 與系統匣圖示。

使用者設定（視窗尺寸、欄寬）會自動儲存於 `%LOCALAPPDATA%\HotspotManager\config.ini`。

---

## 📁 檔案結構

```
HotspotManager/
├── HotspotManager.cs    # C# 原始碼
├── Build.bat            # 編譯腳本 (使用 Windows 內建 csc.exe)
├── Install.ps1          # 安裝至應用程式目錄並設定開機自啟
├── Uninstall.ps1        # 完整解除安裝腳本
├── README.md            # 英文說明文件
├── README.zh-TW.md      # 繁體中文說明文件
├── CONTRIBUTING.md      # 貢獻指南
├── CHANGELOG.md         # 版本更新日誌
└── LICENSE              # Apache License 2.0
```

---

## 📄 授權條款

本專案採用 [Apache License 2.0](LICENSE) 授權條款。
