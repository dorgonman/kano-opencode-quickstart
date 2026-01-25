param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("install", "uninstall", "start", "stop", "status", "logs")]
  [string]$Action,

  [string]$Name = "opencode-tailnet",
  [int]$Port = 4096,
  [int]$TsHttpsPort = 8443,
  [int]$Tail = 200
)

$ErrorActionPreference = "Stop"

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

function Assert-Admin {
  $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) {
    throw "Administrator privileges required (Windows service install/remove). Re-run PowerShell as Admin."
  }
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

$repoRoot = Get-RepoRoot
$bashPath = Get-BashPath
$nssmPath = Get-NssmPath

$startTailnetSh = Join-Path $repoRoot "scripts\\start-server-tailnet.sh"
if (-not (Test-Path $startTailnetSh)) {
  throw "Missing script: $startTailnetSh"
}

if ($Action -in @("install", "uninstall", "start", "stop")) {
  Assert-Admin
}

if ($Action -eq "install") {
  try {
    $portInUse = Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -eq $Port }
    if ($portInUse) {
      throw "Port $Port is already in use. Stop the process using this port before proceeding."
    }
  } catch { }

  if (Test-ServiceExists -ServiceName $Name) {
    Remove-ServiceBestEffort -ServiceName $Name
    Start-Sleep -Seconds 1
  }

  $bashCommand = ("./scripts/start-server-tailnet.sh --service --port {0} --ts-https {1}" -f $Port, $TsHttpsPort)

  if ($null -ne $nssmPath) {
    & $nssmPath install $Name $bashPath "-lc" ('"{0}"' -f $bashCommand)
    if ($LASTEXITCODE -ne 0) { throw "nssm install failed (exit=$LASTEXITCODE)" }

    & $nssmPath set $Name AppDirectory $repoRoot | Out-Null
    & $nssmPath set $Name DisplayName $Name | Out-Null
    & $nssmPath set $Name Start SERVICE_AUTO_START | Out-Null

    $repoOpencodeDir = Join-Path $repoRoot ".opencode"
    $repoBunInstall = if ($env:BUN_INSTALL) { $env:BUN_INSTALL } else { Join-Path $env:USERPROFILE ".bun" }
    $repoBunBin = Join-Path $repoBunInstall "bin"

    $opencodeDir = Get-DirOfCommand -CommandName "opencode"
    $tailscaleDir = Get-DirOfCommand -CommandName "tailscale"
    $bunDir = Get-DirOfCommand -CommandName "bun"

    $extraDirs = @($repoBunBin, $opencodeDir, $tailscaleDir, $bunDir) | Where-Object { $_ -and ($_ -ne "") } | Select-Object -Unique
    $path = ($env:PATH + ";" + ($extraDirs -join ";"))

    $envBlock = @(
      ("PATH={0}" -f $path),
      ("HOME={0}" -f $repoRoot),
      ("USERPROFILE={0}" -f $env:USERPROFILE),
      ("BUN_INSTALL={0}" -f $repoBunInstall),
      ("OPENCODE_HOME={0}" -f $repoOpencodeDir)
    ) -join "`n"

    & $nssmPath set $Name AppEnvironmentExtra $envBlock | Out-Null

    $logsDir = Join-Path $repoRoot ".opencode\\logs"
    New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

    & $nssmPath set $Name AppStdout (Join-Path $logsDir "service-stdout.log") | Out-Null
    & $nssmPath set $Name AppStderr (Join-Path $logsDir "service-stderr.log") | Out-Null
    & $nssmPath set $Name AppRotateFiles 1 | Out-Null
    & $nssmPath set $Name AppRotateOnline 1 | Out-Null
    & $nssmPath set $Name AppRotateSeconds 86400 | Out-Null
    & $nssmPath set $Name AppRotateBytes 10485760 | Out-Null

    Write-Host "OK: installed service via NSSM: $Name" -ForegroundColor Green
    return
  }

  $escaped = $bashCommand.Replace('"', '\"')
  $binPath = ('"{0}" /c "cd /d ""{1}"" && ""{2}"" -lc ""{3}"""' -f $env:ComSpec, $repoRoot, $bashPath, $escaped)

  & sc.exe create $Name binPath= $binPath start= auto DisplayName= $Name | Out-Null
  Write-Host "OK: installed service via sc.exe: $Name" -ForegroundColor Green
  return
}

if ($Action -eq "uninstall") {
  if ($null -ne $nssmPath) {
    try { & $nssmPath stop $Name | Out-Null } catch { }
    try { & $nssmPath remove $Name confirm | Out-Null } catch { }
    Write-Host "OK: removed service via NSSM: $Name" -ForegroundColor Green
    return
  }

  try { & sc.exe stop $Name | Out-Null } catch { }
  try { & sc.exe delete $Name | Out-Null } catch { }
  Write-Host "OK: removed service via sc.exe: $Name" -ForegroundColor Green
  return
}

if ($Action -eq "start") { & sc.exe start $Name; return }
if ($Action -eq "stop") { & sc.exe stop $Name; return }
if ($Action -eq "status") { & sc.exe query $Name; return }

if ($Action -eq "logs") {
  $logsDir = Join-Path $repoRoot ".opencode\\logs"
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

  return
}