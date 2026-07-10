<#
.SYNOPSIS
  Runs `swift-bundler bundle` with the environment fix-ups it needs on Windows.

.DESCRIPTION
  swift-bundler resolves DLL paths via a CASE-SENSITIVE `environment["Path"]` lookup, so the
  PATH variable must be named exactly "Path" (GitHub runners / some shells expose it as "PATH",
  which makes DLL resolution silently return nothing). It also shells out to `swift` and needs
  the Swift toolchain + runtime (swiftCore.dll) dirs on that Path. This normalises the variable
  name to "Path" WITHOUT dropping anything, guarantees the swift + runtime dirs are present,
  verifies `swift` still resolves, then bundles.
#>
param(
  [string]$SwiftBundler = $env:SWIFT_BUNDLER,
  [string]$PackageDir   = 'NoMansTerrainCrossUI',
  [string]$Product      = 'NoMansTerrainCrossUI'
)
$ErrorActionPreference = 'Stop'

if (-not $SwiftBundler) { throw "SwiftBundler path not provided (set `$env:SWIFT_BUNDLER)" }

$swiftExe = (Get-Command swift -ErrorAction Stop).Source
$swiftDir = Split-Path $swiftExe -Parent
Write-Host "swift:         $swiftExe"

# The Swift runtime DLLs (swiftCore.dll) may live in a separate dir from the toolchain.
$rtLine = (& cmd /c "where swiftCore.dll 2>nul") | Select-Object -First 1
$rtDir  = if ($rtLine) { Split-Path $rtLine -Parent } else { $null }
Write-Host "swiftCore.dll: $rtLine"

# Merge every PATH-cased variable (handles 'Path' and/or 'PATH'), ensure the swift + runtime
# dirs are present, then re-expose the whole thing under the exact name 'Path'.
$vars    = [System.Environment]::GetEnvironmentVariables('Process')
$pathVal = (($vars.GetEnumerator() | Where-Object { $_.Key -ieq 'path' }) | ForEach-Object { $_.Value }) -join ';'
foreach ($d in @($swiftDir, $rtDir)) {
  if ($d -and ($pathVal -notlike "*$d*")) { $pathVal = "$d;$pathVal" }
}
foreach ($k in ($vars.Keys | Where-Object { $_ -ieq 'path' })) {
  [System.Environment]::SetEnvironmentVariable($k, $null, 'Process')
}
[System.Environment]::SetEnvironmentVariable('Path', $pathVal, 'Process')
Write-Host "normalised Path length: $($pathVal.Length)"

# Sanity check via the same cmd.exe mechanism swift-bundler uses to invoke `swift`.
$check = (& cmd /c "where swift 2>nul") | Select-Object -First 1
if (-not $check) { throw "swift not resolvable after PATH normalisation (Path length $($pathVal.Length))" }
Write-Host "swift resolvable via cmd: $check"

Push-Location $PackageDir
try {
  & $SwiftBundler bundle $Product -c release
  if ($LASTEXITCODE -ne 0) { throw "swift-bundler bundle failed ($LASTEXITCODE)" }
}
finally { Pop-Location }
