@echo off
:: Enable-SleepSupport.bat - Allow Windows to Sleep while Mobile Hotspot is Active
title HotspotManager - Enable Sleep Support

if "%~1"=="ELEVATED" goto :RUN

:: Check if already Administrator using fsutil
fsutil dirty query %systemdrive% >nul 2>&1
if %errorLevel% equ 0 goto :RUN

echo [HotspotManager] Requesting Administrator privileges to configure power overrides...
echo Elevating to Administrator...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd -ArgumentList '/k \"\"%~f0\"\" ELEVATED' -Verb RunAs"
exit /b

:RUN
cls
echo =======================================================
echo  HotspotManager - Enable Sleep Support
echo =======================================================
echo.
echo Applying power request overrides for Windows Mobile Hotspot services and drivers...
echo.

powercfg /requestsoverride SERVICE "SharedAccess" System Awaymode
powercfg /requestsoverride SERVICE "icssvc" System Awaymode
powercfg /requestsoverride SERVICE "WlanSvc" System Awaymode
powercfg /requestsoverride DRIVER "Microsoft Wi-Fi Direct Virtual Adapter" System Awaymode
powercfg /requestsoverride DRIVER "Microsoft Wi-Fi Direct Virtual Adapter #2" System Awaymode
powercfg /requestsoverride DRIVER "Legacy Kernel Caller" System Awaymode

echo =======================================================
echo [SUCCESS] Sleep overrides applied successfully!
echo Current overrides in system:
echo =======================================================
powercfg /requestsoverride
echo.
echo Windows will now be able to enter Sleep mode normally while Hotspot is running.
echo You can now close this window.
pause
