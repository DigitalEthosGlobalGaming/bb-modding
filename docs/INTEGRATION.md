# bbport integration

`integration/bbport-modhost.patch` (about 600 lines, against bbport 1.9 / 652f9a4) wires the host in.
Apply it with bbmod checked out at `third_party/bbmod`; see MODDING.md step 1.

| File | Change |
|---|---|
| `src/runtime_modhost.c/.h` (new) | Creates the host after the eboot is mapped; sync point; input (SDL keyboard, game pad state); crash guard through `runtime_fault_recover`/`bb_longjmp`; file resolve; the log (`bbmods.log`, console, in-game window; one lock, any thread). No-ops without `BB_MODHOST`. |
| `src/probe.c` | `runtime_modhost_start(image, size)` just before guest code starts (after relocation, patches and final protections). Fault handler names the mod when a hook it installed crashes. |
| `src/runtime_pad.c` | `scePadReadState`: hands the buttons the game read to mods, then runs the sync point, outside the pad lock. |
| `src/runtime_file.c` | `translate()`: a mod's file override wins over the game file, at open time. |
| `gpu/shim/bbport_modui.cpp/.h` (new) | Dear ImGui backend for mod panels, the Mods window (state, errors, Load/Unload/Reload/Retry), the Mod log window, toasts. |
| `gpu/shim/bbport_overlay.cpp` | The mods overlay: F1 (`BB_MODS_KEY`) toggles it, Esc closes it; it captures input like the settings menu (`CapturesInput`, so the mouse leaves camera mode and the pad goes neutral). Insert/L3+R3 still toggle only the settings menu. Draws the mod windows in either. |
| `gpu/CMakeLists.txt` | `BB_MODHOST` (Windows; default on when `third_party/bbmod` exists): builds the host with bbport's Zydis, links it. |
| `run.py` | `BB_CODEMODS_DIR` defaults to `<data>/bbmods` and is created. |

## Threads

* **Game thread** (the first thread that polls the pad) owns the host: frame callbacks, loads,
  reloads, queued network events.
* **Present thread** acquires `modhost_try_lock` before starting the ImGui frame. If the host
  is busy, it reuses the last complete draw data instead of dropping the mod windows.
  It never waits for the game thread while holding the ImGui mutex. Cached frames containing
  custom rendering callbacks are not replayed because those callbacks could belong to a DLL
  being unloaded. Resizing also invalidates reuse until a fresh frame can be drawn.
* **File threads** call `modhost_vfs_resolve` (own lock, lock-free when nothing is overridden).
* **Fault handler**: a crash inside a host→mod call longjmps back (mod disabled, game runs on);
  a crash in a detour is reported with the mod's name and ends the game as before.

## Verified so far

* All bbport-side files compile with bbport's flags (`-Wall -Wextra -Werror`, C11) against real
  SDL3 and Dear ImGui headers (mingw-w64).
* `integration/smoke/` builds bbport's own `runtime_modhost.c`, `bbport_modui.cpp` and
  `bb_setjmp`/`bb_longjmp` with a copy of `probe.c`'s recovery path, real ImGui and real mod DLLs,
  and runs it on Windows (Wine): a mod crashing in its frame callback is recovered through
  `bb_longjmp`, its patch reverted, the healthy mod untouched, Mods window and panels drawn,
  overrides resolved.
* The patch applies cleanly to a fresh bbport 1.9 checkout.
* The smoke test also reads back `bbmods.log` (header, load and crash lines) and checks the Mod
  log window draws.
* Native Windows verification in this workspace (18 October 2026): the full port, including
  `bbport_overlay.cpp`, builds with the GPU stack. Inspector and Dev Tools load in the actual
  game; F1 opens the overlay. Inspector discovered 65 parameter tables. The user confirmed
  manual Inspector reload returns successfully; the log records unload/load/reload sequences.
* The sync-point diagnostic measured about 56.7 calls/second in the 60 FPS session. This is
  a measured polling rate, not proof that every render frame has exactly one sync point.

## Remaining validation

* The user confirmed the contention fix removes the observed flicker. The automatic DLL
  watcher reloaded Inspector after a timestamp change; both shared-input subscribers logged
  matching real controller transitions. A rebuilt Inspector behavior change has not been
  tested live (the watcher check used the same binary).
* ABI 1.4 adds validated sampled HP/stamina and experimental equipment producers,
  a guarded explicit adjustment pipeline, and shared overlay slots. Native item-use
  observation has a distinct queued producer; it is not a controller-input inference.
  Limited native behavior/attack-path observations report behavior IDs and sources,
  not unique swings/hits or weapon attribution. Native incoming-damage interception
  remains unverified. Existing area/save declarations do not mean those producers are wired.
* See [current developer docs](../../../../modding-docs/README.md) for the supported
  contracts, native producer status and live-versus-synthetic validation boundaries.
* ABI 1.5 appends bounded queued item awards, serviced at a fingerprinted native
  player update point after validating the player generation and loaded PARAM row.
  Offline signatures and synthetic detour tests pass; real-game grants and new
  content remain pending validation. Content compilation and extraction run
  offline, not at game startup. This does not add a verified hit/damage callback.
