# Build this mod and put it in bbport's code-mod folder.
#   .\dev.ps1                 release build, deploy once
#   .\dev.ps1 -Watch          rebuild + deploy on every save (start the game with BB_MODS_DEV=1)
#   .\dev.ps1 -ModsDir D:\bbport\bbmods -Debug
# The mods folder: -ModsDir, else BB_CODEMODS_DIR, else <BBPORT_DIR>\bbmods.
param([string]$ModsDir = $env:BB_CODEMODS_DIR, [switch]$Watch, [switch]$Debug)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not $ModsDir -and $env:BBPORT_DIR) { $ModsDir = Join-Path $env:BBPORT_DIR 'bbmods' }
if (-not $ModsDir) { throw 'Where is bbport? Pass -ModsDir <bbport folder>\bbmods or set BBPORT_DIR.' }

function Field($name) {
    $m = Select-String -Path mod.toml -Pattern "^\s*$name\s*=\s*`"([^`"]+)`"" | Select-Object -First 1
    if (-not $m) { throw "mod.toml has no $name" }
    $m.Matches[0].Groups[1].Value
}
$id = Field 'id'; $dll = Field 'dll'
$profile = if ($Debug) { 'debug' } else { 'release' }

function Deploy {
    if ($Debug) { cargo build } else { cargo build --release }
    if ($LASTEXITCODE -ne 0) { Write-Host 'build failed; the game keeps the last good version' -ForegroundColor Red; return }
    $dest = Join-Path $ModsDir $id
    New-Item -ItemType Directory -Force $dest | Out-Null
    # The game loads a shadow copy, so this file is never locked while it runs.
    Copy-Item (Join-Path "target\$profile" $dll) $dest -Force
    Copy-Item mod.toml $dest -Force
    Get-ChildItem -File -Filter *.xml | Copy-Item -Destination $dest -Force
    if (Test-Path dvdroot_ps4) { Copy-Item dvdroot_ps4 $dest -Recurse -Force }
    Write-Host ("{0:HH:mm:ss} deployed {1} -> {2}" -f (Get-Date), $id, $dest) -ForegroundColor Green
}

function Stamp {
    (Get-ChildItem -Recurse -File src, mod.toml, Cargo.toml, *.xml -ErrorAction SilentlyContinue |
        Measure-Object -Property LastWriteTimeUtc -Maximum).Maximum
}

Deploy
if ($Watch) {
    Write-Host 'watching src/, mod.toml, Cargo.toml (Ctrl+C to stop)'
    $last = Stamp
    while ($true) {
        Start-Sleep -Milliseconds 400
        $now = Stamp
        if ($now -ne $last) { $last = $now; Start-Sleep -Milliseconds 200; Deploy }
    }
}
