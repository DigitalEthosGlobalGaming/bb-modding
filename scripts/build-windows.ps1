param([Parameter(Mandatory)][string]$ZydisPrefix)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Set-Location (Split-Path $PSScriptRoot -Parent)
function Run([string]$Tool, [string[]]$Arguments) {
    & $Tool @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Tool failed ($LASTEXITCODE)" }
}
$prefix = (Resolve-Path $ZydisPrefix).Path.Replace('\', '/')
$root = (Get-Location).Path.Replace('\', '/')
$build = 'build/windows'
New-Item -ItemType Directory -Force $build | Out-Null
$stamp = "$build/validated.json"
if (Test-Path $stamp) { Remove-Item -LiteralPath $stamp }
Run cargo @('build', '--workspace', '--release', '--locked')
Run cargo @('test', '--workspace', '--locked')
Run cmake @('-S', '.', '-B', $build, '-G', 'Ninja', '-DCMAKE_BUILD_TYPE=Release',
    '-DCMAKE_C_COMPILER=clang', '-DCMAKE_CXX_COMPILER=clang++',
    '-DBBMOD_WITH_ZYDIS=ON', "-DCMAKE_PREFIX_PATH=$prefix",
    "-DZydis_DIR=$prefix/lib/cmake/zydis", "-DZycore_DIR=$prefix/lib/cmake/zycore",
    "-DBBMOD_EXAMPLES_DIR=$root/target/release",
    "-DBBMOD_RUST_HOOK_MOD=$root/target/release/rust_hook_mod.dll")
Run cmake @('--build', $build, '--parallel', '4')
Run ctest @('--test-dir', $build, '--output-on-failure', '--timeout', '300', '--no-tests=error')
$commit = & git rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Commit the source before recording a validated build.' }
@{ commit = $commit; zydisPrefix = $prefix; target = 'windows-x64';
   cargo = (& cargo --version); rustc = (& rustc --version);
   clang = (& clang --version | Select-Object -First 1);
   inlineHooks = $true; configuration = 'Release';
   checkedUtc = [DateTime]::UtcNow.ToString('o') } |
    ConvertTo-Json | Set-Content -Encoding utf8 $stamp
