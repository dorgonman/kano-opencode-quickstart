param(
  [ValidateSet("bootstrap", "install", "uninstall", "start", "stop", "status", "logs", "diagnose")]
  [string]$Action = "bootstrap",

  [string]$Name = "opencode-tailnet",
  [int]$Port = 5096,
  [int]$TsHttpsPort = 9443,
  [int]$Tail = 200
)

$ErrorActionPreference = "Stop"

function Test-Command {
  param([Parameter(Mandatory = $true)][string]$CommandName)
  return $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Get-RepoRoot {
  $scriptDir = Split-Path -Parent $PSCommandPath
  # scripts/windows -> repo root is ../..
  return (Resolve-Path (Join-Path $scriptDir "..\\..")).Path
}

function Get-BashPath {
  $bash = Get-Command "bash.exe" -ErrorAction SilentlyContinue
  if ($null -ne $bash) { return $bash.Source }

  $bash = Get-Command "bash" -ErrorAction SilentlyContinue
  if ($null -ne $bash) { return $bash.Source }

  throw "bash not found. Install Git for Windows (Git Bash) or add bash.exe to PATH."
}

function Get-NssmPath {
  $nssm = Get-Command "nssm.exe" -ErrorAction SilentlyContinue
  if ($null -ne $nssm) { return $nssm.Source }
  return $null
}

function Get-DirOfCommand {
  param([Parameter(Mandatory = $true)][string]$CommandName)
  $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
  if ($null -eq $cmd) { return $null }
  return (Split-Path -Parent $cmd.Source)
}

function Is-Admin {
  return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Relaunch-Elevated {
  param([Parameter(Mandatory = $true)][string]$Action)

  $args = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $PSCommandPath,
    "-Action",
    $Action,
    "-Name",
    $Name,
    "-Port",
    $Port,
    "-TsHttpsPort",
    $TsHttpsPort,
    "-Tail",
    $Tail
  )

  Start-Process -Verb RunAs -FilePath "powershell.exe" -ArgumentList $args
}

function Ensure-Admin {
  param([Parameter(Mandatory = $true)][string]$Action)

  if (Is-Admin) { return }
  Write-Host "Administrator privileges required for '$Action'. Relaunching elevated..." -ForegroundColor Yellow
  Relaunch-Elevated -Action $Action
  exit 0
}

function Test-ServiceExists {
  param([Parameter(Mandatory = $true)][string]$ServiceName)
  & sc.exe query $ServiceName *> $null
  return ($LASTEXITCODE -eq 0)
}

function Remove-ServiceBestEffort {
  param([Parameter(Mandatory = $true)][string]$ServiceName)

  try { & sc.exe stop $ServiceName *> $null } catch { }
  try { & sc.exe delete $ServiceName *> $null } catch { }

  $nssmPath = Get-NssmPath
  if ($null -ne $nssmPath) {
    try { & $nssmPath remove $ServiceName confirm *> $null } catch { }
  }
}

function Get-EnvBlock {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $repoOpencodeDir = Join-Path $RepoRoot ".opencode"
  $xdgConfig = Join-Path $RepoRoot ".opencode\xdg\config"
  $xdgData = Join-Path $RepoRoot ".opencode\xdg\data"
  $xdgCache = Join-Path $RepoRoot ".opencode\xdg\cache"

  $repoBunInstall = if ($env:BUN_INSTALL) { $env:BUN_INSTALL } else { Join-Path $env:USERPROFILE ".bun" }
  $repoBunBin = Join-Path $repoBunInstall "bin"

  $opencodeDir = Get-DirOfCommand -CommandName "opencode"
  $tailscaleDir = Get-DirOfCommand -CommandName "tailscale"
  $bunDir = Get-DirOfCommand -CommandName "bun"

  $extraDirs = @($repoBunBin, $opencodeDir, $tailscaleDir, $bunDir) | Where-Object { $_ -and ($_ -ne "") } | Select-Object -Unique
  $path = ($env:PATH + ";" + ($extraDirs -join ";"))

  # Force repo-local writable directories for service accounts (SYSTEM).
  return @(
    ("PATH={0}" -f $path),
    ("HOME={0}" -f $RepoRoot),
    ("BUN_INSTALL={0}" -f $repoBunInstall),
    ("OPENCODE_REPO_LOCAL=1"),
    ("OPENCODE_HOME={0}" -f $repoOpencodeDir),
    ("XDG_CONFIG_HOME={0}" -f $xdgConfig),
    ("XDG_DATA_HOME={0}" -f $xdgData),
    ("XDG_CACHE_HOME={0}" -f $xdgCache)
  ) -join "`n"
}

function Install-Service {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$ServiceName,
    [Parameter(Mandatory = $true)][int]$Port,
    [Parameter(Mandatory = $true)][int]$TsHttpsPort
  )

  Ensure-Admin -Action "install"

  $bashPath = Get-BashPath
  $nssmPath = Get-NssmPath

    $opencodeServerSh = Join-Path $RepoRoot "scripts\opencode-server.sh"
  if (-not (Test-Path $opencodeServerSh)) {
    throw "Missing script: $opencodeServerSh"
  }

  try {
    $portInUse = Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -eq $Port }
    if ($portInUse) {
      throw "Port $Port is already in use. Stop the process using this port before proceeding."
    }
  } catch { }

  if (Test-ServiceExists -ServiceName $ServiceName) {
    Remove-ServiceBestEffort -ServiceName $ServiceName
    Start-Sleep -Seconds 1
  }

    $bashCommand = ("./scripts/opencode-server.sh --service --tailnet --host 127.0.0.1 --auth none --port {0} --ts-https {1}" -f $Port, $TsHttpsPort)

  if ($null -ne $nssmPath) {
    & $nssmPath install $ServiceName $bashPath "-lc" ('"{0}"' -f $bashCommand)
    if ($LASTEXITCODE -ne 0) { throw "nssm install failed (exit=$LASTEXITCODE)" }

    & $nssmPath set $ServiceName AppDirectory $RepoRoot | Out-Null
    & $nssmPath set $ServiceName DisplayName $ServiceName | Out-Null
    & $nssmPath set $ServiceName Start SERVICE_AUTO_START | Out-Null

    $envBlock = Get-EnvBlock -RepoRoot $RepoRoot
    & $nssmPath set $ServiceName AppEnvironmentExtra $envBlock | Out-Null

    $logsDir = Join-Path $RepoRoot ".opencode\logs"
    New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

    & $nssmPath set $ServiceName AppStdout (Join-Path $logsDir "service-stdout.log") | Out-Null
    & $nssmPath set $ServiceName AppStderr (Join-Path $logsDir "service-stderr.log") | Out-Null
    & $nssmPath set $ServiceName AppRotateFiles 1 | Out-Null
    & $nssmPath set $ServiceName AppRotateOnline 1 | Out-Null
    & $nssmPath set $ServiceName AppRotateSeconds 86400 | Out-Null
    & $nssmPath set $ServiceName AppRotateBytes 10485760 | Out-Null

    # Ensure stopping the Windows service also stops the spawned opencode process.
    & $nssmPath set $ServiceName AppKillProcessTree 1 | Out-Null
    & $nssmPath set $ServiceName AppStopMethodConsole 1500 | Out-Null
    & $nssmPath set $ServiceName AppStopMethodWindow 1500 | Out-Null
    & $nssmPath set $ServiceName AppStopMethodThreads 1500 | Out-Null

    Write-Host "OK: installed service via NSSM: $ServiceName" -ForegroundColor Green
    return
  }

  Write-Host "WARN: nssm.exe not found; falling back to sc.exe (environment isolation may be incomplete)." -ForegroundColor Yellow

  $escaped = $bashCommand.Replace('"', '\"')
  $envPrefix = "set OPENCODE_REPO_LOCAL=1&& set OPENCODE_HOME=$RepoRoot\.opencode&& set XDG_CONFIG_HOME=$RepoRoot\.opencode\\xdg\\config&& set XDG_DATA_HOME=$RepoRoot\.opencode\\xdg\\data&& set XDG_CACHE_HOME=$RepoRoot\.opencode\\xdg\\cache&& "
  $binPath = ('"{0}" /c "cd /d ""{1}"" && {2}""{3}"" -lc ""{4}"""' -f $env:ComSpec, $RepoRoot, $envPrefix, $bashPath, $escaped)

  & sc.exe create $ServiceName binPath= $binPath start= auto DisplayName= $ServiceName | Out-Null
  Write-Host "OK: installed service via sc.exe: $ServiceName" -ForegroundColor Green
}

function Uninstall-Service {
  param([Parameter(Mandatory = $true)][string]$ServiceName)

  Ensure-Admin -Action "uninstall"

  $nssmPath = Get-NssmPath
  if ($null -ne $nssmPath) {
    try { & $nssmPath stop $ServiceName | Out-Null } catch { }
    try { & $nssmPath remove $ServiceName confirm | Out-Null } catch { }
    Write-Host "OK: removed service via NSSM: $ServiceName" -ForegroundColor Green
    return
  }

  try { & sc.exe stop $ServiceName | Out-Null } catch { }
  try { & sc.exe delete $ServiceName | Out-Null } catch { }
  Write-Host "OK: removed service via sc.exe: $ServiceName" -ForegroundColor Green
}

function Diagnose-TailscaleServe {
  if (-not (Test-Command tailscale)) {
    throw "tailscale not found in PATH."
  }

  Write-Host "[1] tailscale serve status" -ForegroundColor Cyan
  & tailscale serve status
  Write-Host ""

  Write-Host "[2] tailscale serve reset" -ForegroundColor Cyan
  & tailscale serve reset
  Write-Host "OK: tailscale serve reset completed." -ForegroundColor Green
  Write-Host ""

  Write-Host "[3] tailscale serve status" -ForegroundColor Cyan
  & tailscale serve status
}

$repoRoot = Get-RepoRoot

switch ($Action) {
  "bootstrap" {
    Ensure-Admin -Action "bootstrap"
    Install-Service -RepoRoot $repoRoot -ServiceName $Name -Port $Port -TsHttpsPort $TsHttpsPort
    & sc.exe start $Name | Out-Null

    for ($i = 0; $i -lt 20; $i++) {
      $out = & sc.exe query $Name 2>$null
      if ($out -match "RUNNING") { break }
      Start-Sleep -Seconds 1
    }

    & sc.exe query $Name
    Write-Host ""

    if (Test-Command tailscale) {
      Write-Host "tailscale serve status:" -ForegroundColor Cyan
      & tailscale serve status
    } else {
      Write-Host "INFO: tailscale.exe not found in PATH for this shell." -ForegroundColor Yellow
    }
  }

  "install" {
    Install-Service -RepoRoot $repoRoot -ServiceName $Name -Port $Port -TsHttpsPort $TsHttpsPort
  }

  "uninstall" {
    Uninstall-Service -ServiceName $Name
  }

  "start" {
    Ensure-Admin -Action "start"
    & sc.exe start $Name
  }

  "stop" {
    Ensure-Admin -Action "stop"
    & sc.exe stop $Name
  }

  "status" {
    & sc.exe query $Name
  }

  "logs" {
    $logsDir = Join-Path $repoRoot ".opencode\logs"
    $files = @(
      (Join-Path $logsDir "service-stdout.log"),
      (Join-Path $logsDir "service-stderr.log"),
      (Join-Path $logsDir "opencode-stdout.log"),
      (Join-Path $logsDir "opencode-stderr.log")
    )

    foreach ($file in $files) {
      if (Test-Path $file) {
        Write-Host "=== Tail ${Tail}: $file ===" -ForegroundColor Yellow
        Get-Content -Tail $Tail $file
        Write-Host ""
      }
    }
  }

  "diagnose" {
    Diagnose-TailscaleServe
  }
}
