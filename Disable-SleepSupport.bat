@echo off
:: Disable-SleepSupport.bat - Remove power overrides
echo [HotspotManager] Requesting Administrator privileges to remove power overrides...

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Elevating to Administrator...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

echo Removing power request overrides...
powercfg /requestsoverride SERVICE "SharedAccess"
powercfg /requestsoverride SERVICE "icssvc"
powercfg /requestsoverride SERVICE "WlanSvc"
powercfg /requestsoverride DRIVER "Microsoft Wi-Fi Direct Virtual Adapter"
powercfg /requestsoverride DRIVER "Microsoft Wi-Fi Direct Virtual Adapter #2"
powercfg /requestsoverride DRIVER "Legacy Kernel Caller"

echo.
echo =======================================================
echo [SUCCESS] Overrides removed!
echo =======================================================
powercfg /requestsoverride
pause
