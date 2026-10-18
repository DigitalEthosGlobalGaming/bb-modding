# bb-modding / bbmod

Native code mod framework for [bbport](https://github.com/Supermedo/bloodborne_pc).
Write Rust or C mods through a versioned C ABI, load DLLs, and iterate with hot
reload and state transfer. The host owns hooks, patches, callbacks, panels and
file overrides and releases them on unload.

This repository contains the framework. You need your own game installation and
a compatible bbport build with bbmod integrated. The integration patch targets
bbport 1.9; stock bbport 1.8.2 does not gain mod support by copying these files.

## Downloads

The **Build and package** Actions workflow tests Linux and native Windows. Each
successful Windows build uploads a developer ZIP and SHA-256 checksum in the
run's Artifacts. A `v*` tag creates a **draft GitHub Release** after both platform
jobs pass. Maintainers can also use Run workflow.

The Windows x64 distribution contains:

- `source/`: published source, Rust SDK, templates, tests, integration and docs.
- `bbmods/`: release DLLs and manifests for Hello Rust, Dev Tools, Live Patches,
  Shared Input Monitor and Shared Input Counter.
- `lib/`: the CLANG64 static host archive for embedding in a compatible port.
- `dependencies/zydis/`: pinned Zydis/Zycore headers, libraries, sources and licences.
- `BUILD-INFO.json`: commit, toolchains, target and build features.

This is a developer redistribution; an integrated game executable is not included.
Copy complete example folders from `bbmods/` into your integrated port's `bbmods/`
folder. Install only examples you want. Live Patches needs your own
`Bloodborne.xml`; the harness fixture is not installed as a gameplay patch.
The Rust DLLs target Windows MSVC and may require Microsoft's Visual C++ x64
runtime. The host archive targets CLANG64; rebuild the supplied source for other
toolchains. Corresponding GPL host source is included.

## Develop a mod

Install stable Rust for x86-64 Windows MSVC and Visual Studio C++ build tools.
From PowerShell:

```powershell
git clone https://github.com/DigitalEthosGlobalGaming/bb-modding.git
cd bb-modding
cargo build --workspace --locked
cargo test --workspace --locked
cargo build -p hello-rust --release --locked
$dest = 'C:\bbport\bbmods\example.hello-rust'
New-Item -ItemType Directory -Force $dest
Copy-Item target\release\hello_rust.dll, examples\hello-rust\mod.toml $dest
$env:BB_MODS_DEV = '1' # set in the environment that launches the integrated port
```

Use `scripts/new-mod.sh me.my-mod "My Mod" /path/to/mod-sources` from Bash,
or copy `templates/rust-mod`, replace its placeholders, and point the `bbmod`
path dependency at this checkout's `sdk/rust/bbmod`. Keep `panic = "unwind"`.
F1 opens the integrated overlay; `bbmods.log` records host and mod errors.
Raw detours do not automatically support two mods patching the same address.

Start with [mod development](docs/MODDING.md), [Rust SDK](docs/RUST_SDK.md),
[ABI rules](docs/ABI.md) and [host integration](docs/INTEGRATION.md). Some inherited
docs describe older snapshots or local experiments: check implementation and
validation evidence before relying on an API.

## Build the host and distribution

Use PowerShell with MSYS2 CLANG64's Clang, CMake and Ninja on PATH, plus Rust MSVC.
Build static Zydis 4.1.1 and Zycore into a dedicated prefix using the commands in
`.github/workflows/build.yml`, then:

```powershell
.\scripts\build-windows.ps1 -ZydisPrefix C:\deps\zydis
.\scripts\package.ps1 -ZydisPrefix C:\deps\zydis
```

Packaging requires a clean committed checkout and successful build-script test
results. Output goes into a new directory under `dist/`. Release builds require
Zydis; reduced local builds can explicitly use `-DBBMOD_WITH_ZYDIS=OFF`.

## Layout

| Path | Purpose |
| --- | --- |
| `host/` | C host and resource ownership |
| `sdk/include/bbmod.h` | Versioned C ABI |
| `sdk/rust/` | FFI bindings and safe SDK |
| `examples/`, `templates/` | Sample mods and starter template |
| `integration/` | bbport integration patch and smoke harness |
| `tests/` | Synthetic tests; passing does not establish gameplay correctness |
| `docs/`, `scripts/` | Reference docs and development tools |

Inspector is omitted from this initial publication: its generated `bbdata.rs`
cites Openborne/data with unresolved redistribution terms. It remains in the
original local workspace. Inherited Inspector documentation describes that
separate tool, not a bundled example. The incomplete Rust `gameplay` module
declaration from the live workspace is also omitted until its implementation lands.

## Community mods

**Download and use mods at your own risk. We do not vet, audit or verify the
safety of listed mods. A listing is not an endorsement.** Native mods execute
code in the game process; review each mod's source, requirements and installation
instructions before downloading or installing it.

| Mod | Description | Requirements |
| --- | --- | --- |
| [Adaptive Triggers](https://github.com/DigitalEthosGlobalGaming/bb-modding-adaptive-triggers) | Input-driven DualSense L2/R2 resistance effects and configurable lightbar. | Integrated bbmod host with ABI 1.3 pad effects and a DualSense controller. Hardware/gameplay validation remains pending. |

Mod authors can submit a pull request adding a repository link, a short
description and compatibility requirements. Inclusion does not mean we vet it.

## Contribute and plan

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, checks and pull requests, and
[ROADMAP.md](ROADMAP.md) for the work assigned to the other agent: modding docs
and an example AGENTS.md, typed discovered hooks, two cooperating test mods,
weapon/equipment hooks, and composable game UI investigation.

Host/tests: GPL-2.0-or-later. SDK/examples/templates: MIT OR Apache-2.0.
Preserve notices; see [LICENSING.md](LICENSING.md). No game packages, extracted
assets, saves or user settings are included.
