# Map IDs and script filenames

This reference records the community map-name table supplied for this workspace.
Internal Japanese names and their supplied translations are preserved below;
they describe development names rather than official localized area names.

| Map ID | In-game Name | Internal Name | Internal Name (Translated) |
| --- | --- | --- | --- |
| m21_00 | Hunter's Dream | 拠点 | Base |
| m21_01 | Abandoned Old Workshop | 拠点(現実) | Base (True Version) |
| m22_00 | Hemwick Charnel Lane | 墓地街 | Cemetary Town |
| m23_00 | Old Yharnam | 廃墟 | Ruins |
| m24_00 | Cathedral Ward | 聖堂街A | Cathedral City A |
| m24_01 | Central Yharnam, Iosefka's Clinic | 聖堂街B | Cathedral City B |
| m24_02 | Upper Cathedral Ward, Healing Church Workshop, Altar of Despair | 聖堂街C | Cathedral City C |
| m25_00 | Forsaken Castle Cainhurst | 古城 | Old Castle |
| m26_00 | Nightmare of Mensis | トラップロード | Trap Road [*"Torappurōdo"*] |
| m27_00 | Forbidden Woods | 森 | Forest |
| m28_00 | Yahar'gul, Unseen Village | 生贄の街 | Road of Sacrifices |
| m29_XX | (All Chalice Dungeons) | ダンジョン | Dungeon |
| m32_00 | Byrgenwerth, Lecture Building, Moonside Lake | 大学 | University |
| m33_00 | Nightmare Frontier | 故郷 | Hometown |
| m34_00 | Hunter's Nightmare | DLC聖堂街D | DLC Cathedral City D |
| m35_00 | Research Hall | DLC時計塔 | DLC Clocktower |
| m36_00 | Fishing Hamlet | DLC漁村 | DLC Fishing Village |

## Reading an archive path

For example:

```text
m29_00_00_00.luabnd.unpacked/000104_platoon.lua
```

- `m29_00_00_00` is the full map identifier used by this archive. The table uses
  shorter area/block prefixes; `m29_XX` covers the Chalice Dungeon family, with
  `XX` a wildcard rather than literal filename characters. This table does not
  identify a particular dungeon, layer or glyph from the remaining fields.
- `.luabnd` is a Lua script binder/archive. `.unpacked` marks the directory our
  extraction tool creates for its members; it is not part of the original script.
- `000104_platoon.lua` is the original member basename. Its numeric identifier
  also appears in `Platoon000104_Activate`, `Platoon000104_Deactivate` and
  `Platoon000104_Update` in the recovered source. This script configures group
  formation and movement; the number alone does not identify an individual NPC.

The first unpacker version named this file `00004_1004_000104_platoon.lua`:
`00004` was the zero-based archive entry index (the fifth member), and `1004`
was the binder's member ID. Both were extraction prefixes, separate from the
original script identifier `000104`. The extraction index retains the original
archive path and output mapping. New extraction uses original basenames and
adds an entry-index/member-ID prefix only when names would otherwise collide.

The observer's raw **Script** value is a separate unresolved runtime field.
Neither a map prefix nor a matching filename number proves that an NPC is
currently executing that script. See [character/script reference limits](CHARACTER-REFERENCES.md)
and [enemy and AI research](CHARACTERS-AND-AI.md) before building runtime links.
