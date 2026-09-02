# Install.ps1 - Add HotspotManager to Windows Startup & Configure Power Overrides
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$startupDir = [Environment]::GetFolderPath('Startup')
$targetVbs  = Join-Path $startupDir "HotspotManager.vbs"

$vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""$scriptRoot\HotspotManager.ps1""", 0, False
"@

Set-Content -Path $targetVbs -Value $vbsContent -Encoding ASCII
Write-Host "Installed: HotspotManager will auto-start on login."
Write-Host "Startup entry: $targetVbs"

# Try to apply power request overrides if elevated
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Host "`nApplying sleep request overrides for Mobile Hotspot services..."
    powercfg /requestsoverride SERVICE "SharedAccess" System Awaymode
    powercfg /requestsoverride SERVICE "icssvc" System Awaymode
    powercfg /requestsoverride SERVICE "WlanSvc" System Awaymode
    powercfg /requestsoverride DRIVER "Microsoft Wi-Fi Direct Virtual Adapter" System Awaymode
    powercfg /requestsoverride DRIVER "Microsoft Wi-Fi Direct Virtual Adapter #2" System Awaymode
    powercfg /requestsoverride DRIVER "Legacy Kernel Caller" System Awaymode
    Write-Host "Sleep overrides applied successfully."
} else {
    Write-Host "`n[Note] To allow Windows to Sleep while Hotspot is running, run 'Enable-SleepSupport.bat' as Administrator."
}
