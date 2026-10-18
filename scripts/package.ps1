param(
    [Parameter(Mandatory)][string]$ZydisPrefix,
    [string]$ZydisSource = 'build/deps/zydis'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Set-Location (Split-Path $PSScriptRoot -Parent)
$commit = & git rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'A committed Git checkout is required.' }
$dirty = & git status --porcelain
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'Commit all changes before packaging.' }
$info = Get-Content build/windows/validated.json -Raw | ConvertFrom-Json
$prefix = (Resolve-Path $ZydisPrefix).Path.Replace('\', '/')
if ($info.commit -ne $commit -or $info.zydisPrefix -ne $prefix) {
    throw 'Run build-windows.ps1 for this commit and dependency prefix first.'
}
$zydisRoot = (Resolve-Path $ZydisSource).Path
$zydisTag = & git -C $zydisRoot describe --tags --exact-match
if ($LASTEXITCODE -ne 0 -or $zydisTag -ne 'v4.1.1') { throw 'Expected Zydis v4.1.1 source.' }
$dependencyDirty = & git -C $zydisRoot status --porcelain --untracked-files=no
if ($LASTEXITCODE -ne 0 -or $dependencyDirty) { throw 'Zydis source must be clean.' }
$name = "bbmod-windows-x64-$($commit.Substring(0, 12))"
$stage = Join-Path (Get-Location) "dist/$name"
if (Test-Path $stage) { throw "Output already exists: $stage" }
New-Item -ItemType Directory -Path "$stage/source", "$stage/lib", "$stage/bbmods", "$stage/dependencies/zydis/source" -Force | Out-Null
# Git's tracked-file lists exclude caches, local settings and unrelated workspace files.
function Copy-Tracked([string]$Repo, [string]$Destination) {
    $paths = & git -C $Repo ls-files --recurse-submodules
    if ($LASTEXITCODE -ne 0) { throw "Cannot enumerate source: $Repo" }
    foreach ($relative in $paths) {
        $src = Join-Path $Repo $relative
        if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { throw "Missing source: $src" }
        $dest = Join-Path $Destination $relative
        New-Item -ItemType Directory -Force (Split-Path $dest -Parent) | Out-Null
        Copy-Item -LiteralPath $src -Destination $dest
    }
}
Copy-Tracked (Get-Location).Path "$stage/source"
Copy-Tracked $zydisRoot "$stage/dependencies/zydis/source"
Copy-Item -LiteralPath build/windows/libbbmod_host.a -Destination "$stage/lib"
foreach ($dir in @('include', 'lib')) {
    Copy-Item -LiteralPath (Join-Path $prefix $dir) -Destination "$stage/dependencies/zydis" -Recurse
}
foreach ($example in @('hello-rust', 'devtools', 'live-patches', 'input-monitor', 'input-counter')) {
    $manifest = "examples/$example/mod.toml"
    $contents = Get-Content -LiteralPath $manifest -Raw
    $idMatch = [regex]::Match($contents, '(?m)^id\s*=\s*"([^"]+)"')
    $dllMatch = [regex]::Match($contents, '(?m)^dll\s*=\s*"([^"]+)"')
    if (-not $idMatch.Success -or -not $dllMatch.Success) { throw "Invalid $manifest" }
    $dest = "$stage/bbmods/$($idMatch.Groups[1].Value)"
    New-Item -ItemType Directory -Path $dest | Out-Null
    Copy-Item -LiteralPath $manifest -Destination $dest
    Copy-Item -LiteralPath "target/release/$($dllMatch.Groups[1].Value)" -Destination $dest
}
Copy-Item README.md, LICENSING.md, COPYING, LICENSE-MIT, LICENSE-APACHE -Destination $stage
$info | Add-Member -NotePropertyName zydis -NotePropertyValue $zydisTag
$info | ConvertTo-Json | Set-Content -Encoding utf8 "$stage/BUILD-INFO.json"
$zip = "$stage.zip"
Compress-Archive -Path "$stage/*" -DestinationPath $zip -CompressionLevel Optimal
$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $name.zip" | Set-Content -Encoding ascii "$zip.sha256"
Write-Host "Created $zip and $zip.sha256"
