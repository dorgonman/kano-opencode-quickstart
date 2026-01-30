# opencode-deps-update.ps1 - Update OpenCode and all dependencies to latest
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\opencode-deps-update.ps1 [-DryRun]

param(
    [switch]$DryRun = $false
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ManagerScript = Join-Path $ScriptDir "opencode-deps-manager.ps1"

if ($DryRun) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ManagerScript -Action update -DryRun
} else {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ManagerScript -Action update
}

exit $LASTEXITCODE
