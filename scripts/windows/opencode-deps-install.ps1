# opencode-deps-install.ps1 - Install OpenCode dependencies (first-time setup)
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\opencode-deps-install.ps1 [-DryRun]

param(
    [switch]$DryRun = $false
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ManagerScript = Join-Path $ScriptDir "opencode-deps-manager.ps1"

if ($DryRun) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ManagerScript -Action install -DryRun
} else {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ManagerScript -Action install
}

exit $LASTEXITCODE
