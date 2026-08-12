# Install.ps1 - Add HotspotManager to Windows Startup
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$startupDir  = [Environment]::GetFolderPath('Startup')
$vbsContent  = "Set WshShell = CreateObject(`"WScript.Shell`")`nWshShell.Run `"powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"`"`"$scriptRoot\HotspotManager.ps1`"`"`"`", 0, False"
Set-Content -Path "$startupDir\HotspotManager.vbs" -Value $vbsContent -Encoding ASCII
Write-Host "Installed: HotspotManager will auto-start on login."
Write-Host "Startup entry: $startupDir\HotspotManager.vbs"
