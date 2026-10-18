param([switch]$Test)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../../../../../dev-env.ps1')
$bb = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
function Run-Cargo([string[]]$Arguments) {
    & cargo @Arguments
    if ($LASTEXITCODE -ne 0) { throw "cargo failed ($LASTEXITCODE)" }
}
Run-Cargo @('build','--manifest-path',"$bb/Cargo.toml",'-p','ui-examples')
Run-Cargo @('build','--release','--manifest-path',"$bb/Cargo.toml",'-p','ui-examples')
if ($Test) {
    Run-Cargo @('test','--manifest-path',"$bb/Cargo.toml",'-p','ui-examples')
    $hooks = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../../mods/hooks-testing-mod'))
    Run-Cargo @('build','--release','--manifest-path',"$hooks/Cargo.toml")
    $out = Join-Path $PSScriptRoot 'out'
    New-Item -ItemType Directory -Force $out | Out-Null
    $sources = (Get-ChildItem "$bb/host/src/*.c").FullName
    & clang '-std=c11' '-g' "-I$bb/host/include" "-I$bb/sdk/include" "-I$bb/host/src" "-I$bb/tests" "$PSScriptRoot/tests/integration.c" @sources '-lbcrypt' '-o' "$out/test-ui-example.exe"
    if ($LASTEXITCODE -ne 0) { throw 'UI example native harness compilation failed' }
    & "$out/test-ui-example.exe" "$bb/target/release/ui_examples.dll" "$hooks/target/release/hooks_observer.dll"
    if ($LASTEXITCODE -ne 0) { throw 'UI example native harness failed' }
}
$package = Join-Path $PSScriptRoot 'dist/example.ui-examples'
New-Item -ItemType Directory -Force $package | Out-Null
Copy-Item -LiteralPath "$bb/target/release/ui_examples.dll", "$PSScriptRoot/mod.toml" -Destination $package
Write-Host "Package: $package"
Write-Host 'No deployment performed. Use the workspace release deployment after validation.'
