# Install.ps1 - Build (if needed) and add HotspotManager.exe to Windows Startup
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe  = Join-Path $root 'HotspotManager.exe'
if (-not (Test-Path $exe)) { & cmd.exe /c "`"$root\Build.bat`""; if (-not (Test-Path $exe)) { throw 'Build failed.' } }

$startup = [Environment]::GetFolderPath('Startup')
Remove-Item (Join-Path $startup 'HotspotManager.vbs') -Force -ErrorAction SilentlyContinue   # legacy launcher
$lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $startup 'HotspotManager.lnk'))
$lnk.TargetPath = $exe; $lnk.WorkingDirectory = $root; $lnk.Save()
Write-Host "Installed: $exe will auto-start on login."
Write-Host "Sleep support can be toggled from the tray menu ('Allow PC Sleep')."
