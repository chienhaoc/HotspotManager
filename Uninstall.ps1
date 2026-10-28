# Uninstall.ps1 - Remove HotspotManager from Windows Startup and stop it
$startup = [Environment]::GetFolderPath('Startup')
foreach ($n in 'HotspotManager.lnk','HotspotManager.vbs') {
    $t = Join-Path $startup $n
    if (Test-Path $t) { Remove-Item $t -Force; Write-Host "Removed: $t" }
}
Get-Process HotspotManager -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host "Done."
