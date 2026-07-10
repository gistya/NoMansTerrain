<#
.SYNOPSIS
  Runs `swift-bundler bundle` with the environment fix-ups it needs on Windows.

.DESCRIPTION
  Two things trip swift-bundler up in a fresh Windows environment (e.g. GitHub runners):

    1. It resolves DLL paths via a CASE-SENSITIVE `environment["Path"]` lookup, so the PATH
       variable must be named exactly "Path" (runners often expose "PATH").
    2. It resolves the DLL dependencies (swiftCore.dll, Foundation.dll, ...) by searching that
       Path. The Swift RUNTIME dir is not necessarily on PATH (the compiler finds it another
       way), so we must locate it and put it on the Path ourselves.

  This locates the toolchain + runtime + System32 dirs, prepends them, re-exposes the whole
  thing under the exact name "Path", prints diagnostics, then bundles.
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
Write-Host "swift:    $swiftExe"

# Locate swiftCore.dll. Try next-to-swift and the Swift install root (…\Swift\Runtimes\…),
# since the runtime dir is frequently NOT on PATH on CI.
$rtDir = $null
if (Test-Path (Join-Path $swiftDir 'swiftCore.dll')) {
  $rtDir = $swiftDir
} else {
  $swiftRoot = $swiftDir
  while ($swiftRoot -and (Split-Path $swiftRoot -Leaf) -ne 'Swift') { $swiftRoot = Split-Path $swiftRoot -Parent }
  if (-not $swiftRoot) { $swiftRoot = $swiftDir }   # fallback: search from the bin dir
  $hit = Get-ChildItem -Path $swiftRoot -Recurse -Filter 'swiftCore.dll' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($hit) { $rtDir = Split-Path $hit.FullName -Parent }
}
Write-Host "runtime:  $rtDir"
if (-not $rtDir) { throw "Could not locate swiftCore.dll under the Swift install." }

# Compose the Path: our required dirs first, then everything already present (deduped), then
# re-expose it under the exact name "Path".
$sys32    = Join-Path $env:SystemRoot 'System32'
$vars     = [System.Environment]::GetEnvironmentVariables('Process')
$existing = (($vars.GetEnumerator() | Where-Object { $_.Key -ieq 'path' }) | ForEach-Object { $_.Value }) -join ';'
$parts    = @($swiftDir, $rtDir, $sys32) + ($existing -split ';' | Where-Object { $_ })
$pathVal  = ($parts | Select-Object -Unique) -join ';'
foreach ($k in ($vars.Keys | Where-Object { $_ -ieq 'path' })) { [System.Environment]::SetEnvironmentVariable($k, $null, 'Process') }
[System.Environment]::SetEnvironmentVariable('Path', $pathVal, 'Process')
$env:Path = $pathVal

Write-Host "Path length:            $($pathVal.Length)"
Write-Host "swift resolvable:       $([bool](Get-Command swift -ErrorAction SilentlyContinue))"
Write-Host "swiftCore.dll on Path:  $(Test-Path (Join-Path $rtDir 'swiftCore.dll'))"

function Show-Disk($label) {
  Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue |
    Where-Object { $null -ne $_.Free } |
    ForEach-Object { Write-Host ("  disk [{0}] {1}: {2:N1} GB free" -f $label, $_.Name, ($_.Free / 1GB)) }
}

Show-Disk 'before'
Push-Location $PackageDir
try {
  # -gnone: don't embed DWARF debug info. Swift release exes are otherwise huge (~375 MB here,
  # almost all debug info), which overflows the small workspace drive on CI when the exe is
  # copied into the bundle. This shrinks it to tens of MB. --strip removes leftover symbols.
  & $SwiftBundler bundle $Product -c release --strip --Xswiftpm=-Xswiftc --Xswiftpm=-gnone
  $code = $LASTEXITCODE
}
finally { Pop-Location }
Show-Disk 'after'
if ($code -ne 0) { throw "swift-bundler bundle failed ($code)" }
