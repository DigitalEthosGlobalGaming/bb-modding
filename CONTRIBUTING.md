# Contributing

Report reproducible bugs in issues and submit focused pull requests against
`main`. Check roadmap ownership before starting overlapping work. Current
discovery and hook work is assigned to a separate agent and awaits integration.

## Setup and checks

Install stable Rust; on Windows use the MSVC target and Visual Studio C++ build
tools. Host builds use MSYS2 CLANG64, CMake, Ninja and static Zydis 4.1.1 with
Zycore. Follow `.github/workflows/build.yml` to build the dependency prefix:

```powershell
.\scripts\build-windows.ps1 -ZydisPrefix C:\deps\zydis
```

Linux contributors can use the Linux CI commands. SDK changes should at least
pass `cargo build --workspace --locked` and `cargo test --workspace --locked`.
Run host tests for ABI, lifecycle, hook, UI, input, patch or loader changes.
CI tests synthetic harnesses and examples; it does not launch Bloodborne.

## Development rules

- Read `docs/MODDING.md`, `docs/INTEGRATION.md`, `docs/RUST_SDK.md` and `docs/ABI.md`.
- Keep the C ABI, Rust FFI and safe SDK consistent. Preserve struct layouts;
  extend tables with size/version checks and unsupported fallbacks.
- Register resources through the host. Verify unload, reload, fault cleanup and
  concurrent callbacks cannot leave pointers into an unloaded DLL.
- Shared hooks need explicit dispatch, ordering, mutation/conflict and reentrancy
  rules. Test two mods on a target and unload either independently.
- Record game version/ID, fingerprint, calling convention, signature and evidence
  for discoveries. Return unsupported on unrecognised layouts.
- Distinguish sampled state transitions from intercepted game function events.
- Preserve game packages, content, saves and settings. Use synthetic tests first,
  then a separate port build for gameplay checks, with rollback binaries.
- Do not add secrets, game assets, build output or third-party data without
  documented provenance and redistribution terms.

Add meaningful regression tests for behavioural changes and update affected
docs. Avoid unrelated formatting changes to inherited code.

## Pull requests and releases

Explain the problem, resulting behaviour, compatibility impact and checks run.
Separate harness, Wine, native Windows and actual gameplay evidence. Compilation
or reaching the title screen does not verify gameplay hooks.

Contributions retain the affected component's licence and existing notices.
Do not assume upstream has granted a plugin licence exception.

From a clean commit, run the Windows build and package scripts. Inspect the ZIP,
checksum and metadata. A `v*` tag runs both platform jobs and creates a draft
release after they pass. Review compatibility, licences, contents and gameplay
evidence before publishing. Keep `Cargo.lock` committed. The initial import
does not assert a stable gameplay release or create a version tag.
