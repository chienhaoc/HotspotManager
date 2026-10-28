# Install.ps1 - Build (if needed), install HotspotManager.exe to %LOCALAPPDATA%\Programs\HotspotManager
# (per-user, no admin needed), and register Startup + Start Menu shortcuts.
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Join-Path $root 'HotspotManager.exe'
if (-not (Test-Path $src)) { & cmd.exe /c "`"$root\Build.bat`""; if (-not (Test-Path $src)) { throw 'Build failed.' } }

$dir = Join-Path $env:LOCALAPPDATA 'Programs\HotspotManager'
$exe = Join-Path $dir 'HotspotManager.exe'
Get-Process HotspotManager -ErrorAction SilentlyContinue | Stop-Process -Force   # release the file lock
Start-Sleep -Milliseconds 500
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Copy-Item $src $exe -Force

$sh = New-Object -ComObject WScript.Shell
$startup = [Environment]::GetFolderPath('Startup')
$menu    = Join-Path ([Environment]::GetFolderPath('Programs')) 'HotspotManager.lnk'
Remove-Item (Join-Path $startup 'HotspotManager.vbs') -Force -ErrorAction SilentlyContinue   # legacy launcher
foreach ($p in (Join-Path $startup 'HotspotManager.lnk'), $menu) {
    $l = $sh.CreateShortcut($p); $l.TargetPath = $exe; $l.WorkingDirectory = $dir; $l.Save()
}

# Add/Remove Programs entry (per-user)
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\HotspotManager'
New-Item -Path $key -Force | Out-Null
$un = Join-Path $dir 'Uninstall.ps1'
Copy-Item (Join-Path $root 'Uninstall.ps1') $un -Force
Set-ItemProperty $key DisplayName 'Hotspot Manager'
Set-ItemProperty $key DisplayIcon $exe
Set-ItemProperty $key InstallLocation $dir
Set-ItemProperty $key Publisher 'chienhaoc'
Set-ItemProperty $key UninstallString "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$un`""

Start-Process $exe
Write-Host "Installed to $dir (auto-starts on login; also in Start Menu). Started."
