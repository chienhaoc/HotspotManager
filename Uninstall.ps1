# Uninstall.ps1 - Remove HotspotManager (shortcuts, install folder, Add/Remove Programs entry)
$startup = [Environment]::GetFolderPath('Startup')
$menu    = [Environment]::GetFolderPath('Programs')
Get-Process HotspotManager -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500
foreach ($t in "$startup\HotspotManager.lnk", "$startup\HotspotManager.vbs", "$menu\HotspotManager.lnk") {
    if (Test-Path $t) { Remove-Item $t -Force; Write-Host "Removed: $t" }
}
Remove-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\HotspotManager' -Recurse -Force -ErrorAction SilentlyContinue
$dir = Join-Path $env:LOCALAPPDATA 'Programs\HotspotManager'
# This script may itself live in $dir, so delete the folder after it exits.
Start-Process cmd.exe -ArgumentList "/c timeout /t 2 /nobreak >nul & rmdir /s /q `"$dir`"" -WindowStyle Hidden
Write-Host "Done."
