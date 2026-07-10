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
  [string]$OutDir = (Join-Path $PSScriptRoot "..\dist")
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

$GenericDir = (Resolve-Path $GenericDir).Path
$runtimeInstaller = Join-Path $GenericDir 'WindowsAppRuntimeInstaller.exe'
if (-not (Test-Path $runtimeInstaller)) { throw "WindowsAppRuntimeInstaller.exe not found in $GenericDir" }

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
