# Build RS_SlowMo.pk3
#
# The same pattern as RS_Ballistics' build: entry-by-entry ZipArchive with forward
# slashes and an ALLOWLIST (Compress-Archive writes backslashes SLADE will not open,
# and a lump name ignores its extension, so a stray .bak in the root can silently
# shadow the real lump).
#
# THE MENU IS LINTED FIRST: a control for a cvar nothing reads fails the build.
#
# -OutFile packs somewhere other than the installed RS_SlowMo.pk3: a scratch pack to
# compile-check BEFORE it replaces the one the owner loads. -NoCompileCheck skips
# the last step.
#
# The compile check loads RS_Ballistics too: this mod slows the world that package
# draws, and its clock split (recoil and barrel on level.realtime) is the other half
# of the same feature, so they are proven together or not at all.
param([switch]$NoCompileCheck, [string]$OutFile = '')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = $PSScriptRoot
$out  = if ($OutFile) { $OutFile } else { Join-Path $root 'RS_SlowMo.pk3' }
$ballisticsPk3 = 'E:\DOOMWork\RS_Ballistics\RS_Ballistics.pk3'

& python 'E:\DOOMWork\tools\menu_lint.py' $root --prefix rsm_
if ($LASTEXITCODE -ne 0) { throw "menu lint failed -- a control would be dead. See above." }

$rootLumps = @('zscript.txt', 'MAPINFO.txt', 'CVARINFO.txt', 'MENUDEF.txt', 'KEYCONF.txt')
$files = @()
foreach ($l in $rootLumps) {
    $p = Join-Path $root $l
    if (-not (Test-Path $p)) { throw "missing required lump: $l" }
    $files += Get-Item $p
}
$files += Get-ChildItem -Path (Join-Path $root 'zscript') -Recurse -File -Filter *.zs

if (Test-Path $out) { Remove-Item $out -Force }
$fs  = [System.IO.File]::Open($out, [System.IO.FileMode]::CreateNew)
$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
foreach ($f in $files) {
    $rel = ($f.FullName.Substring($root.Length + 1)) -replace ([regex]::Escape([char]92)), '/'
    $e = $zip.CreateEntry($rel, [System.IO.Compression.CompressionLevel]::Optimal)
    $st = $e.Open(); $b = [System.IO.File]::ReadAllBytes($f.FullName)
    $st.Write($b, 0, $b.Length); $st.Dispose()
}
$zip.Dispose(); $fs.Dispose()

# Verify rather than trust: a lump that fails to pack is SILENT.
$check = [System.IO.Compression.ZipFile]::OpenRead($out)
$names = $check.Entries | ForEach-Object { $_.FullName }
$check.Dispose()
$must = @('zscript.txt', 'MAPINFO.txt', 'CVARINFO.txt', 'MENUDEF.txt', 'KEYCONF.txt', 'zscript/rsm/handler.zs')
foreach ($m in $must) {
    if ($names -notcontains $m) { throw "verification failed: $m missing" }
}
Write-Output "RS_SlowMo.pk3  --  $($names.Count) entries, verified"

if ($NoCompileCheck) { Write-Output "compile check SKIPPED (-NoCompileCheck) -- NOT proven to compile"; return }

& 'E:\DOOMWork\tools\compile_check.ps1' -Files @($ballisticsPk3, $out)
if ($LASTEXITCODE -ne 0) { throw "compile check FAILED -- see above" }
