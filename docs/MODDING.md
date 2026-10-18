# Modding Bloodborne with bbmod: getting started

From "the game runs in bbport" to "my own mod hot-reloads while I play".

## 1. Add bbmod to bbport (once)

In your bbport checkout (MSYS2 CLANG64 shell):

```sh
cp -r /path/to/bbmod third_party/bbmod          # or: git clone <your bbmod repo> third_party/bbmod
git apply third_party/bbmod/integration/bbport-modhost.patch
./build.sh                                       # CMake prints "Code mods (bbmod): on"
```

Start the game as usual. The console shows `Mods: 0 in ...\bbmods; log: ...\bbmods.log; F1
opens the mods overlay`. That `bbmods` folder is in your bbport folder (or `BB_DATA_DIR`);
`run.py` creates it.

**Press F1 in game** to open the mods overlay: the **Mods** window (load/unload/reload), every
mod's own panel (the Inspector, Live Patches, ...), and the **Mod log** window. Keyboard and
mouse go to the overlay while it is open and the game's input is held neutral; F1 or Esc closes
it. Ctrl/Alt/Shift+F1 are left free for mod hotkeys. The same windows also appear inside
bbport's settings menu (Insert / L3+R3), which is the way in from a gamepad.

## Adding mods while the game is running

The host checks the mods directory for **new mod folders every five seconds** at
its game-thread sync point. New enabled mods load automatically and appear in F1's
Mods window; development mode is not required. Safe mode discovers them without
loading. Already-known folders, duplicate IDs, manually unloaded mods and faulted
mods are left alone. Use the existing Load/Retry/Reload controls for those mods.

Prepare the complete mod outside the watched folder, then move it into `bbmods`.
A manifest that declares a missing or empty DLL is skipped and retried on a later
scan. Discovery does not mean a partially copied DLL is ready to execute.

Changes to an already-known DLL still use `BB_MODS_DEV=1` hot reload or the panel's
Reload button. Removing or renaming installed folders is not automatic unloading;
unload through the panel first. The scan runs while game sync points are advancing,
so a suspended game discovers additions after it resumes.

## Logs

Every line from the host and every mod (debug detail included) goes to **`bbmods.log`**,
beside the `bbmods` folder. It is timestamped and flushed line by line, so it is complete even
after a crash and readable while the game runs; the previous session's log is kept as
`bbmods.prev.log`. The in-game Mod log window shows the last 300 lines with a level filter.
Mods write to it with `cx.log_info(..)` / `bbmod::info!(cx, ..)`. To ask for help, send the
log file.

Environment switches (set before starting the game, or in the launcher's environment):

| Variable | Effect |
|---|---|
| `BB_MODS_DEV=1` | Hot reload: rebuilt mods swap in while you play. Also prints how often the sync point runs. |
| `BB_MODS_SAFE=1` | Find mods but load none (if one crashes at start). |
| `BB_MODHOST=0` | No mod host at all. |
| `BB_CODEMODS_DIR` | Another mods folder. |
| `BB_MODS_KEY` | Key that opens the mods overlay, as an SDL key name (default `F1`; e.g. `F10`, `Home`). |
| `BB_MODS_LOG` | Another log file path. |

## 2. Try the examples

Install Rust (rustup, default MSVC toolchain is fine), then from the bbmod folder:

```powershell
cd examples\devtools; .\dev.ps1 -ModsDir C:\bbport\bbmods
```

Each example has its own `dev.ps1`/`dev.sh`; each builds to a DLL that goes
in `bbmods\<id>\` with its `mod.toml`.

* **inspector**: the reconnaissance tool. A **param browser/editor** for Bloodborne's game data
  (items, weapons, enemies, shops...; e.g. raise the Blood Vial cap live), a **live heap scan**
  to find your HP or item counts, a **call logger**, a **register watch** for any instruction,
  and a **struct view** that highlights bytes as they change. Method in
  **[REVERSING.md](REVERSING.md)**.
* **devtools**: lighter address converter (PS4 ⇄ host), hex memory peek, pattern scan, watch
  list.
* **live-patches**: toggles real gameplay patches from bbport's `Bloodborne.xml` (can't die,
  stealth, no rally decay, camera distance...) with checkboxes or Ctrl+F1..F9. Copy
  `Bloodborne.xml` from bbport's `patches/` into the mod folder, or set `[patches] xml` to its
  full path. Patches you already enabled in bbport's settings are applied at launch;
  toggling them here changes nothing.

## 3. Make your own

```powershell
bash scripts/new-mod.sh me.my-mod "My Mod" C:\mods-src     # or copy templates\rust-mod by hand
cd C:\mods-src\me.my-mod
$env:BBPORT_DIR = 'C:\bbport'
.\dev.ps1 -Watch
```

Start the game with `BB_MODS_DEV=1`. Every save rebuilds, redeploys, and the game swaps the new
DLL in at the next frame, keeping whatever `save_state` returned. A build error leaves the last
good version running.

### What a mod can do

```rust
fn load(cx: &mut Cx) -> Result<Self> {
    // Bytes (owned: reverted on unload/reload). Addresses as in XML patches/Ghidra/IDA:
    cx.patch(cx.ps4(0x0261B108), &[0xC7, 0x45, 0xB4, 0x09, 0, 0, 0])?;
    cx.patch_xml("Bloodborne.xml", Some("No Rally Decay"))?;

    // Game data (not reverted): typed reads/writes, pointer chains.
    let hp: i32 = cx.read_val(cx.follow(cx.ps4(0x0123_4560), &[0x18, 0x3E8])?)?;

    // Hooks: see below. Input, every frame on the game thread:
    cx.on_frame(|cx| if cx.key_pressed(bbmod::key::F8) { cx.notify("F8!") })?;

    // UI while bbport's menu is open:
    cx.panel("My Mod", |ui| { ui.text("hi"); })?;
    Ok(MyMod)
}
```

(The addresses in the second block are placeholders; find real ones with devtools.)

### Hooks

```rust
bbmod::detour! {
    /// Called by the game; `original` is the game's function.
    fn some_game_fn(this: *mut c_void, amount: i32) -> i32 {
        original(this, amount / 2)
    }
}
// in load():
some_game_fn::install(cx, cx.ps4(0x0123_4567))?;
```

Get the **signature right**: PS4 code uses the System V ABI (`detour!` declares `sysv64` for
you); integer/pointer arguments go in order, floats separately. A wrong signature corrupts the
call. A panic inside the body is caught and the original is called instead.

### Finding addresses

1. Load `eboot.bin` (1.09) in Ghidra or IDA at base **0x400000**: addresses you see there are
   the ones `cx.ps4()` takes, and the same as in `Bloodborne.xml`.
2. Use devtools in game: watch candidate addresses change as you play, peek memory, and turn a
   few unique bytes of a function into a pattern so your mod survives other patches:
   `cx.scan("48 89 5C 24 ?? 57 48 83 EC 20", 0, 0)?`.
3. `Bloodborne.xml` itself is a map of known locations (debug flags, camera, physics).
4. The **inspector** mod does 1–2 in game: log a function to grab an object pointer, watch its
   fields change, scan for anchors. See **[REVERSING.md](REVERSING.md)** for step-by-step
   playbooks (player HP, enemies, inventory).

## 4. When things go wrong

| Symptom | What happened |
|---|---|
| Mod shows **faulted** with "crashed in a callback" | Your callback crashed. The game kept running and your patches/hooks were reverted. Fix it, save; the next deploy reloads it (or press Retry). |
| Game exits with "Fault inside code mod 'x' (in a hook it installed)" | A detour crashed while the game was calling it; that can't be recovered safely. Check the signature. `BB_MODS_SAFE=1` starts without mods. |
| "a thread is still inside the mod's code; leaving it mapped" | A game thread was in your detour during unload; harmless, the old DLL stays in memory until exit. |
| "a mod thread did not stop within 2 s" | A thread from `cx.spawn` ignored its stop flag. Check `stop()` in your loop. |
| "built for ABI x, host is y" | Rebuild against this SDK. |
| Hotkeys do nothing | Input reads as released while the mods overlay, bbport's menu or a text box has focus. |
| Something odd happened | Read `bbmods.log` (or the Mod log window): loads, reloads, crashes and everything mods log are there, with times. |
| Edits do not reload | Start the game with `BB_MODS_DEV=1`; check the console for "sync point ran N times/s". |

## 5. Multiplayer mods

`mod.toml` `[multiplayer] scope = "session"` makes a mod part of the session's mod set: peers
must run the same `id` and `protocol`, and ModNet channels (`cx.channel`, `cx.broadcast`)
carry your messages. **The network transport is not wired to bbnet yet** (see ROADMAP), so
channels report `unsupported` in game for now; client-scope mods are unaffected.
