# Uninstall.ps1 - Remove HotspotManager from Windows Startup
$startupDir = [Environment]::GetFolderPath('Startup')
$target     = "$startupDir\HotspotManager.vbs"
if (Test-Path $target) {
    Remove-Item $target -Force
    Write-Host "Removed: $target"
} else {
    Write-Host "Not found in Startup folder."
}
# Kill any running instance
Get-Process powershell -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -eq '' } |
    ForEach-Object { $_.Kill() }
Write-Host "Done."
