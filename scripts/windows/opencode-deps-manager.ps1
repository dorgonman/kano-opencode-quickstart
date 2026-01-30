# opencode-deps-manager.ps1 - Unified OpenCode dependency manager
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\opencode-deps-manager.ps1 -Action [install|update|status] [-DryRun]

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("install", "update", "status", "check")]
    [string]$Action = "status",
    
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Get-Item (Join-Path $ScriptDir "..\..")).FullName

function Test-Command {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Print-Status {
    Write-Host "=== Environment Status ===" -ForegroundColor Cyan
    Write-Host "RepoRoot  : $RepoRoot"
    
    if (Test-Command "opencode") {
        $opencodeVersion = (opencode --version 2>$null) -join ""
        Write-Host "opencode  : OK ($opencodeVersion)"
    } else {
        Write-Host "opencode  : MISSING" -ForegroundColor Yellow
    }
    
    if (Test-Command "bun") {
        $bunVersion = (bun --version 2>$null) -join ""
        Write-Host "bun       : OK ($bunVersion)"
    } else {
        Write-Host "bun       : MISSING" -ForegroundColor Yellow
    }
    
    if (Test-Command "tailscale") {
        Write-Host "tailscale : OK"
    } else {
        Write-Host "tailscale : MISSING"
    }
    
    if (Test-Command "oh-my-opencode") {
        $omoVersion = (oh-my-opencode --version 2>$null) -join ""
        Write-Host "oh-my-opencode: OK ($omoVersion)"
    }
    
    $PackageJsonPath = Join-Path $RepoRoot ".opencode\package.json"
    if (Test-Path $PackageJsonPath) {
        Write-Host ""
        Write-Host "Repo-local plugins:"
        Push-Location (Join-Path $RepoRoot ".opencode")
        & bun pm ls 2>$null | Select-Object -First 10
        Pop-Location
    }
    Write-Host ""
}

function Install-Dependencies {
    Write-Host "=== Installing Dependencies ===" -ForegroundColor Cyan
    
    # Check prerequisites
    if (-not (Test-Command "bun")) {
        Write-Error "ERROR: bun not found in PATH."
        Write-Host "Hint : Install Bun from https://bun.sh" -ForegroundColor Yellow
        return 2
    }
    
    # Install repo-local plugin dependencies
    $OpencodeDir = Join-Path $RepoRoot ".opencode"
    if (-not (Test-Path $OpencodeDir)) {
        New-Item -ItemType Directory -Path $OpencodeDir | Out-Null
    }
    
    $PackageJsonPath = Join-Path $RepoRoot ".opencode\package.json"
    if (-not (Test-Path $PackageJsonPath)) {
        Write-Error "ERROR: Missing $PackageJsonPath"
        Write-Host "Hint : This repo expects plugin deps to be declared there." -ForegroundColor Yellow
        return 2
    }
    
    Write-Host "[1/1] Installing repo-local plugin dependencies..." -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host "  [DRY-RUN] Would run: cd .opencode && bun install" -ForegroundColor Yellow
    } else {
        Push-Location (Join-Path $RepoRoot ".opencode")
        & bun install
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Plugin dependencies installed" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Plugin installation had issues" -ForegroundColor Yellow
        }
        Pop-Location
    }
    Write-Host ""
}

function Update-Dependencies {
    Write-Host "=== Updating Dependencies ===" -ForegroundColor Cyan
    
    # Check prerequisites
    if (-not (Test-Command "bun")) {
        Write-Error "ERROR: bun not found in PATH."
        Write-Host "Hint : Install Bun from https://bun.sh" -ForegroundColor Yellow
        return 2
    }
    
    if (-not (Test-Command "opencode")) {
        Write-Error "ERROR: opencode not found in PATH."
        Write-Host "Hint : Install OpenCode first" -ForegroundColor Yellow
        return 2
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
}

# Main logic
switch ($Action.ToLower()) {
    "status" {
        Print-Status
    }
    "check" {
        Print-Status
    }
    "install" {
        Print-Status
        Install-Dependencies
        if ($DryRun) {
            Write-Host "[OK] Dry-run completed (no changes made)" -ForegroundColor Green
        } else {
            Write-Host "[OK] Installation completed" -ForegroundColor Green
        }
    }
    "update" {
        Print-Status
        Update-Dependencies
        if ($DryRun) {
            Write-Host "[OK] Dry-run completed (no changes made)" -ForegroundColor Green
        } else {
            Write-Host "[OK] Update completed" -ForegroundColor Green
        }
    }
    default {
        Write-Host "Usage: opencode-deps-manager.ps1 -Action [install|update|status] [-DryRun]" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Actions:"
        Write-Host "  install  - Install dependencies from package.json (first-time setup)"
        Write-Host "  update   - Update all dependencies to latest versions"
        Write-Host "  status   - Show current environment and dependency status"
        Write-Host ""
        Write-Host "Options:"
        Write-Host "  -DryRun  - Preview what would be done without making changes"
        exit 2
    }
}
