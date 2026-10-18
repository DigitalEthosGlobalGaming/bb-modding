# Equipment and native game UI discovery

Research date: 18 October 2026. This document separates supported diagnostics from native functionality still being investigated.

## Evidence and reproducibility

BB Tools is checked out at `setup-tools/references/bb-tools`, commit `15fdfda3af45fbb0315ac626f36bbe8f083258ea` (MIT). Additional layout and UI leads came from [bbhost](https://github.com/droogie/bbhost/tree/566184a74f071166299bb656c4af479e5bbe2771), checked out at `setup-tools/references/bbhost` (GPL-3.0). No bbhost implementation has been copied into the SDK. Our resolver is independently implemented from layout facts, checked against the user's private prepared ELF.

Run `python modding/discoveries/check-equipment-ui-profile.py` from the workspace root. It reads `bbport-windows/out/eboot.elf`, verifies five equipment signatures, five inventory signatures, the System-menu finalizer call target, and the item-action producer/caller/field labels. It records twenty-eight instruction fingerprints plus the ELF SHA-256 in `modding/discoveries/equipment-ui-profile-20261018.json`. It neither runs the game nor changes it. Short signatures identify a layout; they are not a proof of complete native function semantics or comprehensive executable identity.

All addresses here are **RVAs from the relocated guest image**. Add `0x400000` for an Inspector PS4 address. bbhost's `option_menu.cpp` and `menu_pointer.cpp` use preferred guest addresses, so their constants require subtracting `0x400000`. Its typed `sprj` headers already use RVAs. Mixing these conventions silently targets different functions.

No live game process was running during this research. These new features have local ELF and synthetic validation, not gameplay validation.

## Equipment snapshot implemented

`host/src/equipment.c` provides a bounded, read-only diagnostic resolver. It checks the profile once per image, resolves player ownership on every read, reads the equipment block twice, and rejects unstable samples. It checks the actor and character again afterward. This reduces transitional samples but is not a transaction against concurrently running game code. It does not call native constructors, retain item handles, or modify equipment.

| Field | Layout and evidence |
|---|---|
| Character | Actor `+0x3C0`, equal to `*GameDataMan+8`; GameDataMan singleton RVA `0x553B130` |
| Equipment | Embedded at character `+0x240`; source operand verified at RVA `0x14F3C19` |
| Mode | Equipment `+8`, opaque integer; not yet exposed as a named stance |
| Six selection words | Equipment `+0x0C`, serialized as 24 bytes |
| Sixteen runtime references | Equipment `+0x24`; assignment invokes native retain/assignment for every entry |
| Sixteen saved IDs | Equipment `+0x64`; reader consumes 64 bytes, then reconstructs runtime references |
| Selected even index | `2 * selection[0]`, independently observed at RVA `0x1895C3B` |
| Selected odd index | `2 * selection[1] + 1`, independently observed at RVA `0x1895CDB` |

Out-of-range selectors yield an unavailable index rather than an array access. The selected indices describe native accessors; **right/left hand naming, transformed-weapon behavior, armor slot ordering and saved-ID freshness are not yet validated**. Consumers must not claim that all sixteen entries are live catalog IDs or the player's full inventory. Runtime references can represent instance-backed handles; they are not interchangeable with catalog IDs. Do not write or clone these arrays: native ownership matters.

Sample comparisons can report that observed equipment data changed. They cannot establish that a weapon was used, distinguish all intermediate swaps between samples, or supply native before/after mutation events. Input R1/R2 presses are not attack execution events.

Synthetic test `tests/test_equipment.c` covers field extraction, changed-owner rejection, an unstable second read, invalid selectors and profile rejection. It compiles with Clang `-Wall -Wextra -Werror` and passes independently. Framework integration and ABI exposure are documented in the shared-hook guide.

## Inventory and remaining equipment discovery

The shared inventory service now provides bounded carried-inventory pages and sampled changes, independently traced through EquipInventoryData and ItemMan. See the inventory SDK and discovery report for its exact ownership, revision and resolved-ID rules. The `RepositoryData` pointer is not used as an unverified substitute. Storage, durability and gems remain separate discovery work. BB Tools' award chain (construct `0x1A86FF0`, award `0x17D89F0`, release `0x1A8BC00`) is not an enumeration API.

The next controlled read-only experiment should capture snapshots before and after a right-hand swap, left-hand swap, armor change, consumable selection, and weapon transformation. Capture the displayed item names alongside every sample. Use inventory resolved IDs alongside those snapshots to confirm slot names. Storage, instance durability/upgrade/gem data and named active-hand semantics require further verification.

PlayLog research lists record kinds `ChrChangeWeapon=6`, `ChrSwitchWeapon=7`, `ChrAttack=11`, `ChrUseItem=15`, `SetEquipItem=21`, and `AddEquipItem=22`. Online logging can be gated off; never enable uploads or rely on the network logger as a complete event stream. Item use was traced to a producer before that gate, as described below; other kinds remain research leads.

## Native item-use observation

An opt-in host-owned observer now targets RVA `0x1FF0FA0`, with caller return address `0x18C9358`. The caller invokes the actual action at `0x18B61C0` first, then passes its boolean result. Independent disassembly and the native UTF-16 field labels identify SysV arguments: RDI actor, ESI item ID, R8D success. EDX and ECX are forwarded unchanged but not exposed as named semantics. The function's own telemetry-enabled test occurs after its entry; we do not change that test or enable uploads.

`BBM_EV_ITEM_USE_OBSERVED` / `Event::item_use()` supplies `ItemUse { generation, actor, item_id, success, ... }`. This is an action-result observation, including failed actions, not cancellation/interception. It is not a complete weapon-attack hook. The two known attack-logging calls are at `0x1A26653` and `0x1A29853`, targeting `0x1FE8FB0`; the first follows a successful action return from `0x18C7530`. Both callsites are now covered by the separate behavior observer below; completeness still requires gameplay validation.

The native detour calls only host code and the original native function. It uses a bounded 64-record queue with a single nonblocking CAS attempt; contention/overflow drops records and produces a warning at the next sync point. Host dispatch filters the current local actor and player generation and excludes network sessions. Mods receive queued immutable payloads at the host sync point. Reloading a subscriber does not alter the shared native hook. Native callbacks never acquire the host run lock or call a mod DLL.

`modhost_config.native_observation` defaults to zero. Runtime opt-in is `BB_MODS_NATIVE_OBSERVATION=1`; the launch script enables it after the native harness passed; set the environment variable to `0` to opt out. Startup logs explicitly report disabled, installed, unsupported image, or installation failure. Safe mode disables it. Exact producer and caller signatures reject modified/unsupported sites; normal hook overlap checks protect other owners.

The bridge can install only once per process. Shutdown disables capture and removes/bypasses the native hook. Each of the two bridges retains one trampoline/gate allocation (128 logical bytes each, rounded by the operating system to its allocation granularity) is intentionally retained until process exit: a thread can have cached the detour before shutdown, and must still have a valid original function to return through. Static host code/state contains no dereferenced freed-host pointer. Recreating the host in that process does not reinstall or accumulate allocations. The OS reclaims the bounded allocation at process exit.

`test_native_observation` executes a synthetic SysV caller, the actual native hook machinery and original trampoline, rather than merely dispatching a fabricated event. It covers original return preservation, delayed fanout to two subscribers, caller/actor filtering, failure results, overflow, epoch changes, shutdown restoration and rejection of reinstallation. The fixture passed in Debug and optimized `-O2` builds. Gameplay behavior must still be confirmed using a consumable in the real game.

## Native attack/behavior observation

`BBM_EV_ATTACK_OBSERVED` / `Event::attack_observed()` observes producer RVA `0x1FE8FB0`. Independent instruction inspection establishes SysV RDI actor and ESI behavior ID, corroborated by native UTF-16 `behavior_id` field text at `0x49BC2B8`. The observer preserves the original return and forwards arguments unchanged.

`AttackObserved` includes generation, actor, behavior_id and source. `ATTACK_SOURCE_BEHAVIOR` (1) accepts return site `0x1A26658`, reached after action `0x18C7530` returned true and an additional engine flag passed. `ATTACK_SOURCE_STAMINA` (2) accepts return site `0x1A29858`, following the engine stamina update. Exact producer and both caller byte signatures must match. These are behavior observations, **not weapon item IDs, hit/damage events, cancellation points, or exactly one event per swing**. The first callsite has an additional engine stack flag; its meaning is unverified, so that path may omit actions even when the native producer is installed. Both are conditional game paths, not comprehensive action coverage. Multiple source observations may correspond to one player action. No guessed weapon mapping or deduplication is applied. The observer captures before the producer's own logger gate and exclusions, while leaving those original operations unchanged.

It uses a separate 64-record bounded queue and the same local-actor, generation, network-session, safe-mode, lifecycle and drop handling as the item observer. The native fixture `test_native_attack` passed in Debug and optimized `-O2` builds and executes both recognized SysV callsites through the real detour/trampoline; it checks preserved return, source identification, two subscribers, unsupported callers/actors, overflow, stale epochs, network suppression, restoration and no reinstallation. This verifies the bridge mechanically, not the game's action coverage. Controlled real-game attacks and weapon swaps are still needed to map behavior IDs and establish coverage.

## Native UI: a concrete route to integration

The requested UI now specifically includes a **Mods entry beside Inventory,
Status and System**, containing installed mods and their settings. See the
[in-game top-menu investigation](NATIVE-INGAME-MENU.txt) for independently checked
builder call sites, the normal fourth placeholder, the conditional Debug row,
movie layout and implementation/validation route. A new row inside System does
not satisfy that placement. These remain offline findings, not a working native API.

BB Tools' menu factories open existing workshop menus. Arbitrary additions need the game's actual list/widget and movie infrastructure. bbhost's independently inspected System-menu extension demonstrates these locations:

| Operation | RVA |
|---|---|
| System builder finalizer call | `0x1BB4978` (verified CALL target below) |
| Finalize System command list | `0x1BEA630` |
| Append command row | `0x1B4E2A0` |
| Open a named option section | `0x1B20900` |
| Append slider / choice / pick-list | `0x1B2AC00` / `0x1B2A100` / `0x1B29370` |
| Accepted section-name table | `0x53398B0` |
| Section-name loop count compare | `0x1B20E1E`, currently compares against six |
| List update / cursor setter | `0x1ACFF30` / `0x1ACF6B0` |
| Menu manager / active step | `*image+0x5562870`, manager `+0xA88` |
| Attach native menu step | `0x1BB27A0` |

These are research addresses, **not a public native UI API**. Function entry bytes alone do not establish complete SysV argument, functor or ownership contracts.

The list component has a listener at `+0x30`, cursor permission predicate at `+0x60`, item count `+0x70`, cursor `+0x74`, override `+0x78`, and item provider `+0x258`. Its cursor setter does not itself dispatch the change listener; the update does. Directly changing the cursor field therefore does not reproduce a normal event. The native item-list path also tail-jumps into the list update, so detouring only virtual calls misses a path. These details need independent native ABI tests before interception.

New sections require sprites in an overlay for `/dvdroot_ps4/menu/optionsetting.gfx`, sufficient widget slots, and localized menu captions/help (FMG groups 200/201). Registering only a section name can lead to a missing sprite. The game's assets stay untouched; generate one composed framework overlay. User-language selection and UI scaling must be exercised. Stock sections and close/fade/focus ownership remain engine-managed.

## Multi-mod native UI contract to implement next

1. One host-owned System-builder hook, list event adapter and composed movie overlay. Mods never patch the same call or reserve table padding independently.
2. Namespace each contribution by `(mod_id, element_id)` and attach it to a stable semantic location such as `system.mods`. Stable sort by priority, then mod ID and element ID. Rebuild only when contributions change.
3. Host-owned copied labels, typed values and native callback thunks. Never retain a raw mod DLL callback or string after unload. A currently open native screen holds a generation token; unload disables the contribution and defers native destruction to the menu thread.
4. Dispatch `before_activate`, `value_changing`, `value_changed`, and `closed` using distinct read-only and mutable event types. Explicit cancellation is sticky; value transformations run in documented order; final validation precedes native commit. Observers receive the final outcome once.
5. Only dispatch on the verified menu update thread. Queue requests from mod workers and drain at a validated point. Reject missing assets, unsupported image layouts, stale generations, duplicate keys and invalid values.
6. Test two mods at the same location, multiple observers, cancellation, conflicting changes, controller navigation, localization, reload while open, removal during dispatch, world changes and rollback.

The current shared **overlay** contribution API is useful immediately but is distinct from native game menus. This investigation establishes a path to embedded Mod Manager UI; it does not claim that arbitrary native controls or native event interception are implemented yet.
