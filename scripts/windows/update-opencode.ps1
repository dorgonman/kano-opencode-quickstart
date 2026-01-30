# update-opencode.ps1 - Update OpenCode and all plugins to latest versions
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\update-opencode.ps1 [-DryRun]

param(
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Get-Item (Join-Path $ScriptDir "..\..")).FullName

function Test-Command {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# Check prerequisites
if (-not (Test-Command "bun")) {
    Write-Error "ERROR: bun not found in PATH."
    Write-Host "Hint : Install Bun from https://bun.sh" -ForegroundColor Yellow
    exit 2
}

if (-not (Test-Command "opencode")) {
    Write-Error "ERROR: opencode not found in PATH."
    Write-Host "Hint : Install OpenCode first" -ForegroundColor Yellow
    exit 2
}

Write-Host "=== OpenCode Update Script ===" -ForegroundColor Cyan
Write-Host "RepoRoot: $RepoRoot"
Write-Host ""

if ($DryRun) {
    Write-Host "INFO: Dry-run mode enabled (no actual updates)" -ForegroundColor Yellow
    Write-Host ""
}

# Step 1: Update OpenCode CLI
Write-Host "[1/3] Updating OpenCode CLI..." -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "  [DRY-RUN] Would run: bun install -g opencode-ai@latest" -ForegroundColor Yellow
} else {
    $result = & bun install -g opencode-ai@latest 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] OpenCode CLI updated successfully" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] OpenCode CLI update failed (continuing anyway)" -ForegroundColor Yellow
    }
}
Write-Host ""

# Step 2: Update oh-my-opencode
Write-Host "[2/3] Updating oh-my-opencode..." -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "  [DRY-RUN] Would run: bun install -g oh-my-opencode@latest" -ForegroundColor Yellow
} else {
    $result = & bun install -g oh-my-opencode@latest 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] oh-my-opencode updated successfully" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] oh-my-opencode update failed (may not be installed globally)" -ForegroundColor Yellow
    }
}
Write-Host ""

# Step 3: Update repo-local plugin dependencies
Write-Host "[3/3] Updating repo-local plugin dependencies..." -ForegroundColor Cyan
$PackageJsonPath = Join-Path $RepoRoot ".opencode\package.json"
if (-not (Test-Path $PackageJsonPath)) {
    Write-Host "  [WARN] No .opencode/package.json found, skipping plugin updates" -ForegroundColor Yellow
} else {
    if ($DryRun) {
        Write-Host "  [DRY-RUN] Would run: cd .opencode && bun update" -ForegroundColor Yellow
    } else {
        Push-Location (Join-Path $RepoRoot ".opencode")
        Write-Host "  Current dependencies:"
        & bun pm ls 2>$null
        Write-Host ""
        Write-Host "  Updating all dependencies to latest..."
        $result = & bun update 2>&1
        Write-Host ""
        Write-Host "  Updated dependencies:"
        & bun pm ls 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Plugin dependencies updated" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Plugin update had issues" -ForegroundColor Yellow
        }
        Pop-Location
    }
}
Write-Host ""

# Step 4: Show versions
Write-Host "=== Current Versions ===" -ForegroundColor Cyan
if (Test-Command "opencode") {
    $opencodeVersion = (opencode --version 2>$null) -join ""
    Write-Host "OpenCode CLI: $opencodeVersion"
}
if (Test-Command "oh-my-opencode") {
    $omoVersion = (oh-my-opencode --version 2>$null) -join ""
    Write-Host "oh-my-opencode: $omoVersion"
}
if (Test-Path $PackageJsonPath) {
    Write-Host ""
    Write-Host "Plugin dependencies:"
    Push-Location (Join-Path $RepoRoot ".opencode")
    & bun pm ls 2>$null | Select-Object -First 20
    Pop-Location
}
Write-Host ""

if ($DryRun) {
    Write-Host "[OK] Dry-run completed (no changes made)" -ForegroundColor Green
} else {
    Write-Host "[OK] Update completed" -ForegroundColor Green
}
