# HotspotManager 📶

[English](README.md) | 繁體中文說明

一款輕量化、純原生的 Windows 系統匣（System Tray）行動熱點管理小程式。  
使用 **PowerShell 5.1 + WinForms + Windows WinRT API** 開發 — **100% 原生、零外部依賴、免安裝**。

---

## ✨ 主要功能

- 🟢 **系統匣常駐 (System Tray)**：
  - 動態圖示狀態指示：🟢 綠色（熱點開啟）、🔴 紅色（熱點關閉）、🟡 黃色（操作處理中）
  - 右鍵選單：快速開啟控制面板、啟動熱點、停止熱點、結束程式
  - 雙擊系統匣圖示即可快速顯示/隱藏控制面板
- 🎛️ **現代化控制面板**：
  - 單一動態 **開關按鈕 (Toggle Button)**，直覺切換熱點狀態
  - 即時顯示熱點狀態、SSID、密碼及當前網際網路來源 Profile
  - 支援 DPI 自動縮放與視窗自由調整大小
- 📱 **連線裝置追蹤**：
  - 清晰列表顯示：主機名稱 (Hostname)、IP 位址、MAC 位址
  - ⏱️ **連線時長 (Connected Time)**：自動記錄並計算每台裝置的已連線時間
- 💾 **設定持久化記憶**：
  - 自動儲存並還原您調整好的視窗大小與表格欄位寬度
- 🚀 **靜默啟動**：
  - 附帶 VBScript 啟動器 (`HotspotManager.vbs`)，執行時完全不跳出黑色的 CMD/PowerShell 視窗
  - 提供一鍵開機自啟設定腳本 (`Install.ps1`)

---

## 💻 系統需求

- **作業系統**：Windows 10 / 11
- **PowerShell**：PowerShell 5.1（Windows 內建）
- **權限需求**：一般使用者權限即可（不需要系統管理員權限）

---

## 🚀 快速開始

### 1. 下載專案 (Clone)

```powershell
git clone https://github.com/chienhaoc/HotspotManager.git E:\git\HotspotManager
cd E:\git\HotspotManager
```

### 2. 直接執行

雙擊 **`HotspotManager.vbs`** 即可在背景靜默啟動。啟動後會在右下角系統匣（工作列時鐘旁）看到 Wi-Fi 形狀的圖示。

### 3. 設定開機自動啟動（可選）

執行 `Install.ps1` 即可將靜默啟動捷徑自動寫入 Windows 開機啟動資料夾：

```powershell
powershell -ExecutionPolicy Bypass -File .\Install.ps1
```

如需移除開機自啟：

```powershell
powershell -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

---

## 🛠️ 技術原理

Windows 行動熱點 API 封裝於 WinRT 命名空間 (`Windows.Networking.NetworkOperators` 與 `Windows.Networking.Connectivity`)。  
`HotspotManager.ps1` 透過 Reflection (`[System.WindowsRuntimeSystemExtensions]::AsTask`) 在原生 PowerShell 中調用 WinRT 異步介面，並以 WinForms 繪製深色主題 UI。

使用者設定（視窗尺寸、欄寬）會自動儲存於 `%LOCALAPPDATA%\HotspotManager\config.json`。

---

## 📁 檔案結構

```
HotspotManager/
├── HotspotManager.ps1   # PowerShell 主程式
├── HotspotManager.vbs   # 靜默啟動器 (不顯示 CMD 視窗)
├── Install.ps1          # 設定開機自啟腳本
├── Uninstall.ps1        # 移除開機自啟腳本
├── README.md            # 英文說明文件
├── README.zh-TW.md      # 繁體中文說明文件
├── CONTRIBUTING.md      # 貢獻指南
├── CHANGELOG.md         # 版本更新日誌
└── LICENSE              # MIT 開源授權條款
```

---

## 📄 授權條款

本專案採用 [Apache License 2.0](LICENSE) 開源授權。
