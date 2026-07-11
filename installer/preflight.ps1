<#
.SYNOPSIS
  Fails fast (before the ~45-minute Swift build) if anything the later bundle/installer steps
  need is missing or broken. Run this right after tool setup and checkout.

.DESCRIPTION
  Checks, in seconds:
   - swift + the Swift runtime dir (swiftCore.dll) are locatable (what ci-bundle.ps1 needs)
   - mt.exe + dumpbin.exe are on PATH (swift-bundler shells out to them during bundling)
   - the private hastings dependency was checked out next to the repo
   - the WiX CLI + Bootstrapper extension are installed
   - App.wxs AND Bundle.wxs actually COMPILE (dry run against dummy inputs) so a WiX authoring
     error surfaces now instead of after the build
   - prints free disk space
#>
$ErrorActionPreference = 'Continue'
$here = $PSScriptRoot
$failures = @()

function Check($name, [scriptblock]$test) {
  try {
    $r = & $test
    Write-Host ("  OK    {0}{1}" -f $name, $(if ($r) { " -> $r" } else { "" }))
  } catch {
    Write-Host ("  FAIL  {0} -> {1}" -f $name, $_.Exception.Message)
    $script:failures += $name
  }
}

function Find-Runtime {
  $swiftDir = Split-Path (Get-Command swift -ErrorAction Stop).Source -Parent
  if (Test-Path (Join-Path $swiftDir 'swiftCore.dll')) { return (Join-Path $swiftDir 'swiftCore.dll') }
  $root = $swiftDir
  while ($root -and (Split-Path $root -Leaf) -ne 'Swift') { $root = Split-Path $root -Parent }
  if (-not $root) { $root = $swiftDir }
  $hit = Get-ChildItem -Path $root -Recurse -Filter 'swiftCore.dll' -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $hit) { throw "swiftCore.dll not found under $root" }
  return $hit.FullName
}

Write-Host "== Preflight: everything the bundle + installer steps depend on =="

Check "swift on PATH"          { (Get-Command swift -ErrorAction Stop).Source }
Check "swiftCore.dll locatable" { Find-Runtime }
Check "mt.exe (manifest tool)" { (Get-Command mt.exe -ErrorAction Stop).Source }
# Our vendored swift-bundler patch enumerates DLL deps with llvm-readobj (dumpbin LNK1106s on
# the app's large .exe), so llvm-readobj — not dumpbin — is what the bundle step now needs.
Check "llvm-readobj"          { (Get-Command llvm-readobj -ErrorAction Stop).Source }
Check "hastings checkout"      { (Resolve-Path (Join-Path $here '..\..\hastings') -ErrorAction Stop).Path }
Check "wix CLI"               { (& wix --version) 2>&1 | Select-Object -First 1 }
# The installer chains the WindowsAppRuntime 1.5-PREVIEW1 runtime (a different package family than
# stable 1.5; the app won't launch without it). Fail now if Microsoft moved the pinned download.
Check "preview1 runtime URL"  {
  $url = "https://aka.ms/windowsappsdk/1.5/1.5.240205001-preview1/windowsappruntimeinstall-x64.exe"
  $r = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
  if ($r.StatusCode -ne 200) { throw "HTTP $($r.StatusCode)" }
  "HTTP 200"
}

# The real payoff: prove the WiX authoring compiles now, with dummy inputs.
Check "App.wxs + Bundle.wxs compile" {
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("nmt-preflight-" + [guid]::NewGuid().ToString('N'))
  $app = Join-Path $tmp 'app'
  New-Item -ItemType Directory -Force $app | Out-Null
  Set-Content (Join-Path $app 'NoMansTerrainCrossUI.exe') 'x' -NoNewline
  Set-Content (Join-Path $app 'swiftCore.dll') 'x' -NoNewline
  # Burn's ExePackage reads version info from the runtime installer, so use a real PE as the
  # stand-in (cmd.exe) rather than a dummy byte.
  $runtimeStandIn = $env:ComSpec
  & wix build (Join-Path $here 'App.wxs') -d "AppDir=$app" -o (Join-Path $tmp 'App.msi')
  if ($LASTEXITCODE -ne 0) { throw "App.wxs failed to compile" }
  # Mirror the real output name — WiX (WIX0388) rejects a bundle literally named "Setup.exe".
  & wix build (Join-Path $here 'Bundle.wxs') -ext WixToolset.BootstrapperApplications.wixext `
      -d "RuntimeInstaller=$runtimeStandIn" -d "AppMsi=$(Join-Path $tmp 'App.msi')" `
      -o (Join-Path $tmp 'NoMansTerrainSetup.exe')
  if ($LASTEXITCODE -ne 0) { throw "Bundle.wxs failed to compile" }
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  "compiled clean"
}

Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue |
  Where-Object { $null -ne $_.Free } |
  ForEach-Object { Write-Host ("  disk {0}: {1:N1} GB free" -f $_.Name, ($_.Free / 1GB)) }

if ($failures.Count) { throw "Preflight FAILED: $($failures -join ', ')" }
Write-Host "== Preflight OK -- proceeding to the build =="
