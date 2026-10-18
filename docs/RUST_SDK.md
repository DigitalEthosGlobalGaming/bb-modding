# Rust SDK (`sdk/rust/bbmod`)

Start from `templates/rust-mod` (`scripts/new-mod.sh`); MODDING.md has the workflow.

## The `Mod` trait

```rust
impl bbmod::Mod for MyMod {
    fn load(cx: &mut Cx) -> Result<Self>;                     // register everything here
    fn unload(&mut self, cx: &mut Cx) {}                     // optional; resources revert anyway
    fn save_state(&self) -> Option<Vec<u8>> { None }          // hot reload hand-off
    fn restore_state(&mut self, cx: &mut Cx, state: &[u8], from: Version) {} // after load; re-apply here
    fn event(&mut self, cx: &mut Cx, ev: &Event) {}           // see cx.subscribe
}
bbmod::export!(MyMod);
```

## `Cx` at a glance

| Area | Calls |
|---|---|
| Log, config | `log_info/warn/error/debug`, `info!(cx, ..)`, `config("sec.key")`, `config_parse::<T>`, `config_bool` |
| Addresses | `eboot_base()`, `ps4(addr)` / `ps4_to_host`, `scan(pattern, 0, 0)`, `follow(base, &[offsets])` |
| Memory | `read`, `read_val::<T>`, `read_ptr`, `write`, `write_val` (game data, not reverted) |
| Patches (reverted) | `patch(addr, bytes)`, `patch_val(addr, v)`, `patch_xml(path, Some(name))`, `release(id)` |
| Hooks (removed) | `bbmod::detour!` + `name::install(cx, addr)` / `install_slot`; raw `hook_inline`, `hook_inline_raw`, `hook_slot` |
| Every frame | `on_frame(|cx| ..)` on the game thread |
| Input | `key_down`, `key_pressed` (`bbmod::key::*`, SDL scancodes), `pad_down`, `pad_pressed` (`bbmod::pad::*`) |
| UI | `panel(title, |ui| ..)`: `text`, `text_colored`, `button`, `checkbox`, `slider_f32`, `slider_i32`, `input_text`, `combo`, `collapsing_header`, `separator`, `same_line`, `ui.cx()`; `notify(msg)` toasts |
| Files | `file_override("dvdroot_ps4/..", source)` |
| Threads | `spawn(|stop| while !stop() { .. })` |
| ModNet | `channel(name, flags, |cx, peer, bytes| ..)`, `send`, `broadcast`, `session()` |

ABI 1.1 calls (input, new widgets) read as released / do nothing on a 1.0 host.

## Safety rules

* Callbacks and panels are guarded: a crash or panic there disables only your mod.
* A detour runs on game threads, concurrently with everything: keep shared state in atomics.
  `detour!` adds the in-flight guard and turns a panic into a call to the original.
* No threads of your own (use `cx.spawn`), no thread-local destructors, no `static` holding
  `Cx` or host pointers (a `static Detour` is fine).
* Build for x86-64 Windows (MSVC or GNU). Keep `panic = "unwind"` (the template does).

## ABI 1.3: DualSense pad effects

`bbmod::dualsense` provides `off`, `resistance`, `resistance_vibration`, and experimental `raw` effect builders, plus `Trigger::{Left,Right}`. `Cx::pad_info`, `pad_trigger`, `pad_release`, and `pad_lightbar` check table size and return unsupported on an older host. Trigger/lightbar claims are host owned and released on unload or a recovered mod fault. The host suppresses effects during backend input capture. Physical trigger depths are independent of game action remapping.

User configuration at `<mods_dir>/../config/<mod-id>.toml` is checked before the packaged manifest for each config key. Missing keys fall back to manifest defaults.
