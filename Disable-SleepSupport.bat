@echo off
:: Disable-SleepSupport.bat - Remove power overrides
title HotspotManager - Disable Sleep Support

if "%~1"=="ELEVATED" goto :RUN

:: Check if already Administrator using fsutil
fsutil dirty query %systemdrive% >nul 2>&1
if %errorLevel% equ 0 goto :RUN

echo [HotspotManager] Requesting Administrator privileges to remove power overrides...
echo Elevating to Administrator...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd -ArgumentList '/k \"\"%~f0\"\" ELEVATED' -Verb RunAs"
exit /b

:RUN
cls
echo =======================================================
echo  HotspotManager - Disable Sleep Support
echo =======================================================
echo.
echo Removing power request overrides...
echo.

powercfg /requestsoverride SERVICE "SharedAccess"
powercfg /requestsoverride SERVICE "icssvc"
powercfg /requestsoverride SERVICE "WlanSvc"
powercfg /requestsoverride DRIVER "Microsoft Wi-Fi Direct Virtual Adapter"
powercfg /requestsoverride DRIVER "Microsoft Wi-Fi Direct Virtual Adapter #2"
powercfg /requestsoverride DRIVER "Legacy Kernel Caller"

echo =======================================================
echo [SUCCESS] Overrides removed!
echo Current overrides in system:
echo =======================================================
powercfg /requestsoverride
echo.
echo You can now close this window.
pause
