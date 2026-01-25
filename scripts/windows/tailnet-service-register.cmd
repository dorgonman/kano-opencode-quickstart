@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%tailnet-service.ps1"

if not exist "%PS1%" (
  echo ERROR: Missing script: %PS1%
  pause
  exit /b 2
)

rem Ensure elevation (service install/remove requires admin).
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { Start-Process -Verb RunAs -FilePath $env:ComSpec -ArgumentList '/c','\"\"%~f0\"\"' } catch { Write-Host $_.Exception.Message; exit 2 }"
  exit /b %errorlevel%
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Action bootstrap
if errorlevel 1 (
  echo.
  echo ERROR: Register/bootstrap failed.
  pause
  exit /b 2
)

echo.
echo OK: Service installed and started.
pause
exit /b 0
