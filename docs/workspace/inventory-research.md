# Carried inventory research (CUSA03173 1.09)

The `inventory.c` resolver enumerates carried inventory without calling game functions or writing game memory. The separate `RepositoryData` pointer at player record + `0x5B0` has not been classified here and is not treated as carried inventory or exposed as storage.

## Evidence and address conventions

The initial lead is the `goods_count` implementation in the local reference checkout `setup-tools/references/bbhost/plugins/boss_rush/boss_rush.cpp`. Its Binary Ninja addresses require subtracting `0x400000` to obtain image RVAs. These are not interchangeable with the already-normalized offsets in BB Tools. Every instruction below was independently disassembled from this workspace's private `bbport-windows/out/eboot.elf`; no game binary or large disassembly is included in the documentation.

| Native evidence (image RVA) | Confirmed layout |
| --- | --- |
| `0x14D9F60` item lookup, especially `0x14D9FFF` | Split index at inventory + `0x24`; 16-byte slots; first backing array pointer + `0x58`, second + `0x48`. A zero first word is empty. |
| `0x14DA77E` and repeated indexed accessors | Valid indices are below unsigned `(inventory[0x88] + 1)`. `0xFFFFFFFF` represents no indices. |
| `0x14DA879`, `0x14D9540` and `0x14D9559` | Slot + `8` is quantity; native increase path reads, clamps and writes it. |
| `0x14D9638` | Slot + `0xC` is additional packed metadata, not the item parameter ID. |
| `0x1A89070` handle resolver | Slot first word is a runtime reference. The game resolves it into a category-encoded item parameter ID. |
| `0x1A8911C` | Dynamic references resolve through global pointer image + `0x553E990`, index `reference & 0xFFFF`, entry pointer at manager + `8 + index*8`; object + `8` must match the complete reference; item ID is object + `0xC`. |
| `0x1A89144` through jump table `0x1A891C4` | Inline references require sign bit, type 0..4 in bits 28..30, and low ID below `0x7FFFFF`. Category mapping is 0, `0x10000000`, `0x20000000`, `0x40000000`, `0x40000000`. |

Carried `EquipInventoryData` is embedded at player record + `0x328` (`EquipGameData + 0x158`, with EquipGameData at record + `0x1D0`). The player record is accepted only when both local-player actor + `0x3C0` and GameDataMan + `8` identify it.

## Implementation guarantees and limits

- At most 4,096 slots, matching the native lookup's 12-bit slot encoding; corrupt larger counts fail closed.
- Five short instruction fingerprints are checked by the service before reading. All five were verified directly against the local ELF on 18 October 2026.
- Two copies of backing arrays and the inventory header must agree. The local actor and player record ownership are rechecked afterward.
- Empty slots are skipped. Each occupied entry retains its slot number, complete runtime reference, quantity and both metadata words.
- A valid resolved parameter ID sets `MH_INVENTORY_ID_RESOLVED`. Stale/unsupported references retain their entry but have `encoded_item_id = 0xFFFFFFFF` and no resolved-ID flag.
- These are bounded observations, not an atomic game snapshot. Changes may occur immediately after validation. A quantity reduction alone does not prove item use: selling, dropping, consuming and scripted removals can all alter inventory.
- There are no inventory writes, native function calls, storage enumeration, or guessed use events in this resolver.
- The full internal snapshot is about 128 KiB; callers allocate it on the heap. SDK delivery should use a bounded page or owned copy, never expose live item pointers.

## Tests run

`tests/test_inventory.c`, compiled with Clang `-Wall -Wextra -Werror`, passes synthetic-memory tests for both backing arrays, empty slots, inline and dynamic parameter IDs, stale dynamic handles, unstable array contents, bounded counts, empty inventory and player-ownership mismatch. This verifies resolver behavior; live inventory contents still need read-only in-game validation.

## Public SDK service

`Cx::inventory_page(revision, offset, limit)` copies at most 64 occupied entries from a shared cache. Start with revision 0, then use the returned revision for all subsequent pages. `STATE` means the snapshot changed; discard the incomplete collection and retry later. `Cx::inventory_snapshot()` collects a bounded owned copy and fails on a changed revision, without an unbounded retry loop.

The host refreshes at most once every 250 ms, only when a mod subscribes to `inventory::event::INVENTORY_CHANGED` or requests a page. It allocates its two full internal buffers on the heap once. Events contain previous/current `InventorySummary` values; their revision changes on content, ownership or availability changes. The player `generation` and inventory `revision` serve different purposes: the former identifies sampled player lifetime, the latter identifies cached inventory contents. Page metadata carries both.

`Cx::equipped_inventory()` joins the equipment runtime references to this inventory by exact reference equality. It checks matching player generation, actor and character record, and re-reads equipment to reject an unstable join. The resulting 16 `Option<InventoryEntry>` slots contain only unambiguous resolved matches. Missing references remain `None`, including items not yet reflected in the 250-ms cache. `selected_even()` and `selected_odd()` return the corresponding resolved entries when available; they do not assert left/right-hand semantics.

Inspector exposes these read-only APIs through `shared-inventory` and `shared-equipped`; see `modding/INSPECTOR-CLI.txt`. Synthetic resolver and real-host cache tests pass. Live equipment/inventory contents have not yet been validated in the game for this version.
