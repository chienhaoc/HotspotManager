Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File ""E:\git\HotspotManager\HotspotManager.ps1""", 0, False
