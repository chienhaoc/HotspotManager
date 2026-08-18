@echo off
:: Enable-SleepSupport.bat - Allow Windows to Sleep while Mobile Hotspot is Active
echo [HotspotManager] Requesting Administrator privileges to configure power overrides...

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Elevating to Administrator...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

echo Applying power request overrides for Windows Mobile Hotspot services and drivers...
powercfg /requestsoverride SERVICE "SharedAccess" System Awaymode
powercfg /requestsoverride SERVICE "icssvc" System Awaymode
powercfg /requestsoverride SERVICE "WlanSvc" System Awaymode
powercfg /requestsoverride DRIVER "Microsoft Wi-Fi Direct Virtual Adapter" System Awaymode
powercfg /requestsoverride DRIVER "Microsoft Wi-Fi Direct Virtual Adapter #2" System Awaymode
powercfg /requestsoverride DRIVER "Legacy Kernel Caller" System Awaymode

echo.
echo =======================================================
echo [SUCCESS] Sleep overrides applied successfully!
echo Current overrides:
echo =======================================================
powercfg /requestsoverride
echo.
echo Windows will now be able to enter Sleep mode normally while Hotspot is running.
pause
