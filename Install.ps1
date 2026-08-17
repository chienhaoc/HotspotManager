# Install.ps1 - Add HotspotManager to Windows Startup
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$startupDir = [Environment]::GetFolderPath('Startup')
$targetVbs  = Join-Path $startupDir "HotspotManager.vbs"

$vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File ""$scriptRoot\HotspotManager.ps1""", 0, False
"@

Set-Content -Path $targetVbs -Value $vbsContent -Encoding ASCII
Write-Host "Installed: HotspotManager will auto-start on login."
Write-Host "Startup entry: $targetVbs"
