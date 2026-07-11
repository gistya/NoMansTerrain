<#
.SYNOPSIS
  Builds NoMansTerrainSetup.exe — a Burn bootstrapper that installs the exact WindowsAppRuntime
  (1.5-preview1) the app needs, then the app itself.

.DESCRIPTION
  Takes a swift-bundler `.generic` bundle, stages the app files (minus the runtime installer),
  builds the app MSI, then wraps it in a Setup.exe bootstrapper that chains the runtime
  installer + the app MSI.

  Requires WiX v5 on PATH (`dotnet tool install --global wix --version 5.0.2`) with the
  WixToolset.BootstrapperApplications extension added globally.

.EXAMPLE
  ./installer/build.ps1 -GenericDir NoMansTerrainCrossUI/.build/bundler/apps/NoMansTerrainCrossUI/NoMansTerrainCrossUI.generic
#>
param(
  # Path to the swift-bundler output: ...\NoMansTerrainCrossUI.generic
  [Parameter(Mandatory = $true)][string]$GenericDir,
  # Where to write NoMansTerrain.msi and NoMansTerrainSetup.exe
  [string]$OutDir = (Join-Path $PSScriptRoot "..\dist"),
  # The WindowsAppRuntime installer to chain in the bootstrapper. IMPORTANT: the installer that
  # swift-bundler drops in the .generic is the STABLE 1.5 build (1.5.250108004), which is the WRONG
  # package family — this app is framework-dependent on 1.5-PREVIEW1 (1.5.240205001-preview1) and
  # will NOT launch against stable 1.5. CI downloads the correct preview1 installer and passes it
  # here. If omitted, we fall back to the .generic one (only correct if you replaced it yourself).
  [string]$RuntimeInstaller
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

$GenericDir = (Resolve-Path $GenericDir).Path
if ($RuntimeInstaller) {
  $runtimeInstaller = (Resolve-Path $RuntimeInstaller).Path
} else {
  $runtimeInstaller = Join-Path $GenericDir 'WindowsAppRuntimeInstaller.exe'
  Write-Warning "No -RuntimeInstaller given; using the .generic one, which is STABLE 1.5 (wrong for this app)."
}
if (-not (Test-Path $runtimeInstaller)) { throw "Runtime installer not found: $runtimeInstaller" }
Write-Host "Runtime installer: $runtimeInstaller ($('{0:N1}' -f ((Get-Item $runtimeInstaller).Length / 1MB)) MB)"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path

# Stage app files = the bundle minus the runtime installer (the bootstrapper chains that
# separately, so it must not also be baked into the app MSI).
# Unique staging dir so repeated local runs never collide with a locked leftover.
$staging = Join-Path ([System.IO.Path]::GetTempPath()) ("nmt-app-staging-" + [guid]::NewGuid().ToString('N'))
Copy-Item $GenericDir $staging -Recurse
[System.IO.File]::Delete((Join-Path $staging 'WindowsAppRuntimeInstaller.exe'))

$appMsi = Join-Path $OutDir 'NoMansTerrain.msi'
$setup  = Join-Path $OutDir 'NoMansTerrainSetup.exe'

Write-Host "==> Building app MSI"
wix build (Join-Path $here 'App.wxs') -d "AppDir=$staging" -o $appMsi
if ($LASTEXITCODE -ne 0) { throw "wix build App.wxs failed ($LASTEXITCODE)" }

Write-Host "==> Building Setup.exe bootstrapper"
wix build (Join-Path $here 'Bundle.wxs') `
  -ext WixToolset.BootstrapperApplications.wixext `
  -d "RuntimeInstaller=$runtimeInstaller" `
  -d "AppMsi=$appMsi" `
  -o $setup
if ($LASTEXITCODE -ne 0) { throw "wix build Bundle.wxs failed ($LASTEXITCODE)" }

Write-Host "==> Done:"
Get-Item $appMsi, $setup | ForEach-Object { Write-Host ("    {0}  ({1:N1} MB)" -f $_.Name, ($_.Length / 1MB)) }
