# Roadmap

Updated 18 October 2026. These five workstreams are assigned to another agent:
**in progress / awaiting integration and validation**. An ABI declaration alone
does not mean a feature is implemented or verified in game. Work outside this
repository must arrive as reviewed changes.

## 1. Mod developer documentation

- [ ] Add `modding-docs/` in the modding project, covering create/build/install,
  debugging, reload, API examples and limitations.
- [ ] Include an example `AGENTS.md` for agents creating/modifying mods, using
  the SDK, checking compatibility, testing ownership and deploying safely.
- [ ] Verify instructions with a fresh mod and link them from the README.

## 2. Typed SDK for discovered functionality

- [ ] Expose discovered functionality with typed APIs instead of repeated raw
  addresses, layouts and unsafe casts in individual mods.
- [ ] Record signatures, calling conventions, fingerprints and evidence.
- [ ] Keep host, C ABI and Rust bindings compatible; test older-host fallback
  and unsupported game versions.

## 3. Shared hooks and two test mods

- [ ] Add `hooks-testing-mod/` under the companion workspace's `modding/mods/`
  (locally `C:\games\bloodborne-pc\modding\mods`). This is outside the framework
  import; integrate reusable examples and tests here when ready.
- [ ] Create two mods capturing and writing/modifying the same supported events.
- [ ] Define host-owned dispatch, deterministic ordering, mutation/conflict rules,
  cancellation where supported, reentrancy and threading behaviour.
- [ ] Prove unloading, faulting or reloading either mod leaves the other working
  without duplicate hooks or stale callbacks.
- [ ] Capture event logs and verify actual producers during gameplay.

## 4. Weapons, equipment and inventory

- [ ] Read inventory and currently active/equipped weapons and equipment.
- [ ] Expose validated changes to inventory and equipment.
- [ ] Investigate and implement weapon/item use events with defined semantics.
- [ ] Test swaps, additions/removals, loading transitions, unavailable player
  state, invalid IDs, supported versions and multiple subscribers.
- [ ] Distinguish polling-derived observations from intercepted use functions.

## 5. UI hooks and composition investigation

- [ ] Map native game UI entry points, state, events and lifetimes.
- [ ] Investigate creating/modifying elements and intercepting UI events so the
  mod manager and future mods can integrate with the game UI.
- [ ] Define shared insertion points, namespaced IDs, ordering, focus/input
  ownership, propagation/cancellation and conflict handling.
- [ ] Demonstrate multiple mods contributing to the same location and cleanly
  removing their own elements during unload/reload.
- [ ] Distinguish existing ImGui panels/host slots from native game UI hooks;
  native integration remains research until demonstrated in game.

## Integration and release follow-up

- [ ] Integrate these workstreams with native Windows tests and gameplay evidence.
- [ ] Resolve Inspector generated-data redistribution terms before importing it.
- [ ] Review the integration patch against the final API and pin compatible
  bbport revisions for releases.
- [ ] Review lifecycle/dependencies, profiles and package installation against
  the separate Mod Manager specification before implementing.
- [ ] Validate DualSense effects with hardware; locate its separate specification
  before expanding requirements.
- [ ] Investigate ModNet/bbnet transport integration and limits.

`docs/ROADMAP.md` contains historical implementation notes and reported checks;
this root document is the current acceptance list.
