@echo off
rem Builds HotspotManager.exe with the .NET Framework compiler that ships with Windows (no SDK needed).
setlocal
set FW=%windir%\Microsoft.NET\Framework64\v4.0.30319
set GAC=%windir%\Microsoft.NET\assembly\GAC_MSIL
set WINMD=%windir%\System32\WinMetadata
set RT=%GAC%\System.Runtime\v4.0_4.0.0.0__b03f5f7f11d50a3a\System.Runtime.dll
set TASKS=%GAC%\System.Threading.Tasks\v4.0_4.0.0.0__b03f5f7f11d50a3a\System.Threading.Tasks.dll
set IOP=%GAC%\System.Runtime.InteropServices.WindowsRuntime\v4.0_4.0.0.0__b03f5f7f11d50a3a\System.Runtime.InteropServices.WindowsRuntime.dll

"%FW%\csc.exe" /nologo /target:winexe /optimize+ /platform:anycpu /out:"%~dp0HotspotManager.exe" ^
  /r:"%RT%" /r:"%TASKS%" ^
  /r:"%WINMD%\Windows.Foundation.winmd" /r:"%WINMD%\Windows.Networking.winmd" ^
  /r:System.Windows.Forms.dll /r:System.Drawing.dll ^
  "%~dp0HotspotManager.cs"
if errorlevel 1 (echo Build FAILED & exit /b 1)
echo Built %~dp0HotspotManager.exe
