param(
  [ValidateSet("install", "check", "status")]
  [string]$Action = "install"
)

$ErrorActionPreference = "Stop"

function Test-Command {
  param([Parameter(Mandatory = $true)][string]$Name)
  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-RepoRoot {
  $scriptDir = Split-Path -Parent $PSCommandPath
  return (Resolve-Path (Join-Path $scriptDir "..")).Path
}

function Print-Status {
  $repoRoot = Get-RepoRoot
  Write-Host ("RepoRoot  : {0}" -f $repoRoot)
  Write-Host ("opencode  : {0}" -f ($(if (Test-Command opencode) { "OK" } else { "MISSING" })))
  Write-Host ("bun       : {0}" -f ($(if (Test-Command bun) { "OK" } else { "MISSING" })))
  Write-Host ("tailscale : {0}" -f ($(if (Test-Command tailscale) { "OK" } else { "MISSING" })))
}

function Install-PluginDeps {
  $repoRoot = Get-RepoRoot
  $opencodeDir = Join-Path $repoRoot ".opencode"
  $pkg = Join-Path $opencodeDir "package.json"

  New-Item -ItemType Directory -Force -Path $opencodeDir | Out-Null

  if (-not (Test-Path $pkg)) {
    throw "Missing file: $pkg"
  }

  if (-not (Test-Command bun)) {
    throw "bun not found in PATH. Install Bun, then re-run: powershell -File scripts\\prerequisite.ps1 -Action install"
  }

  Push-Location $opencodeDir
  try {
    Write-Host "INFO: Installing .opencode plugin dependencies via bun..."
    & bun install
    if ($LASTEXITCODE -ne 0) { throw "bun install failed (exit=$LASTEXITCODE)" }
    Write-Host "OK: bun install completed."
  }
  finally {
    Pop-Location
  }
}

if ($Action -in @("check", "status")) {
  Print-Status
  exit 0
}

Print-Status
Install-PluginDeps