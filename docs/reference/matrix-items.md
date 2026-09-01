# Reference matrix — `items`

| Field | Value |
|---|---|
| Group | `inventory / items / equipment` |
| Backlog brick | `025` |
| Mapped on | `2026-09-01` |
| Sources read | client `attribution.tsv` grepped for `item`/`inv`/`equip`/`loot`/`db`/`store`/`shop`/`craft` class names, plus the full `InventoryWidget` address range (`4c1a10`–`4c6cc0`); server `attribution.tsv` same grep (no matching class besides `SpriteManager`, already mapped); client `GAP_ANALYSIS.md` grepped for `equip`/`inventory`/`InventoryWidget` (~25 rows) plus its `## InventoryWidget (2)` section (full, 2 rows); server `GAP_ANALYSIS.md` grepped for `item`/`inventory`/`equip`/`loot`/`currency`/`gold`/`coin`/`stack`/`slot` (~40 matched rows, game-logic subset read); `cube/ui/InventoryWidget.h` (full, short); `server/db/Database.h` (full, short — matches the generic ctor/dtor/vfunc shape already noted in `matrix-entity.md` Q2); `server/include/cube_types.h` grepped for `item`/`inventory`/`equip`/`slot`/`stack` (no VERIFIED item struct exists, unlike `cube_Creature_offsets`); `server/game_misc/game_misc.cpp` grepped for the ~10 item-function names for call-site context only |
| Coverage | 1 dedicated class placed (`InventoryWidget`); 1 cross-referenced as out of scope (`Database`); 1 large class (`GameController`) partially pulled in for its item-relevant slice only; 9 concepts placed |

## 1. Class map

| Reference class | Binary | Role (one line, our words) | Placed | Bricks | Confidence | Note |
|---|:---:|---|---|---|:---:|---|
| `cube::InventoryWidget` | client | inventory-panel UI shell: event dispatch to child widgets, ctor/dtor, two vfuncs (draw/input) | `client/ui/` | 224 | MEDIUM | own ctor/dtor/vfuncs only — the item-grid rebuild/scroll/hover logic that `GAP_ANALYSIS.md` names `InventoryWidget_*` is attributed by `attribution.tsv` to `GameController`, not this class (see row below and §4 Q1) |
| `cube::GameController` | client | NOT placed as a whole in this brick — a 620-function client class (`cube/control/`) with no owning matrix yet; only its ~10 item/inventory-relevant functions are pulled into §2 below | `NONE` (item slice only, see §2) | — | — | see §4 Q1 |
| `cube::Database` | both | generic SQLite key/value blob store (`blobs(key TEXT, value BLOB)`); no item-specific persistence class exists in either binary | `NONE` | — | HIGH | already flagged `Placed = NONE` in `matrix-entity.md` §4 Q2; not re-placed here, cross-ref only |

## 2. Concepts with no single class

| Concept | Evidence | Placed | Bricks | Confidence |
|---|---|---|---|---|
| Item record equality/copy (a fixed ~0x118-byte struct with a count field) | server `item_struct_equals`, `item_struct_equals_full`, `item_not_equals`, `uninitialized_copy_items`, `entityState_copy` (0x118-byte record, header + 0x20-entry array) | `gameplay/inventory/` (`ItemStack`/`ItemDefinition` identity) | 156, 158 | LOW–MEDIUM (equality-by-fields is corroborated by 3 independent functions; the exact byte layout is decompiler data, not ours to ship) |
| Item type classification (stackable? / category / damage-slot mapping) | server `game_isItemTypeStackable`, `game_itemTypeCategory` (maps a type-code to category 0–3), `mapItemTypeToSlotIndex` (equip-type opcode → bonus-slot index 6/7/8, or −1) | `gameplay/inventory/` (stack rule), `gameplay/equipment/` (slot mapping) | 157, 161, 164 | MEDIUM (GAP `med` confidence; category/slot *count* is a decompiler enum, not to be copied) |
| Item/entity definition loading from a serialized descriptor | server `game_buildItemDefinition`, `game_appendItemEntry` (parses and appends definition entries to a container) | `gameplay/loot/` or a data-loading step feeding `DefinitionRegistry` (`core/ids/`) | 156, 157 | LOW (GAP `low` confidence, no struct layout recovered) |
| Inventory count/currency accumulation | server `game_inventoryAccumulateCount` (adds a signed count to an inventory/currency total keyed by item type-code; called at ~12 sites across `game_misc.cpp`, both add and remove via negative counts) | `gameplay/inventory/` (add/remove, stack-merge ops) | 160, 161 | LOW (GAP `low` confidence; call-site grep corroborates it is the single add/remove primitive, not the exact arithmetic) |
| Equipment slot array on a creature | server `Creature_initEquipmentSlots` (zero-inits **16** repeated equipment/inventory slot blocks, memset 0x100 each, count=1) vs. `creature_items_equal` (compares **12** equipment item slots) — same subsystem, two different slot counts recovered from two different functions | `gameplay/equipment/` (equipment slot schema) | 164, 165 | LOW (shape only — a fixed-size slot array exists; the count is contradictory across sources, see §4 Q2) |
| Equipment-derived stat-bonus plumbing | `Equipment::sum_slot_values`, `Combat_equipHealthBonus`, `Combat_sumEquipAttackBonus`/`Combat_equipSpeedBonus` | `gameplay/equipment/` | 167 | already placed in `matrix-combat.md` §2 — cross-ref only, not re-placed here |
| Client-side inventory management (attributed to `GameController`, GAP-named `InventoryWidget_*`/`GameController_*`) | `GameController_loadInventoryItems` (loads DB item list, classifies into 6 vectors, sorts), `GameController_equipStarterGear` (per-class starter-equipment assignment), `GameController_addItemToInventory`, `GameController_onItemPickup` (carry-limit check, consumes world drop, adds to inventory, rolls an "rng affix", plays SFX — affix mechanism itself unread, see §4 Q3), `collectFilledInventorySlots`, `getSelectedSlotCoords`/`getSelectedItemPtr`, `getEquipmentSlotPtr`, `getTargetedItemName`, `GameController_avgEquippedColor`, and the GAP-named `InventoryWidget_rebuildItemList`/`updateScroll`/`drawScrollbar`/`handleSlotHover` (all attributed to `GameController`, not `InventoryWidget` — see §1 note) | `client/ui/` (inventory panel) + `gameplay/inventory/` (replicated-state apply for the client's own inventory) | 159, 166, 224 | MEDIUM–HIGH (GAP confidence is mostly `high` per-function; not corroborated by a second binary since this is a client-only concern) |
| Item pickup / drop consumption | `GameController_onItemPickup` (carry-limit gate, consumes a world item-drop entity, adds to inventory) | `gameplay/loot/` (pickup resolution) | 172, 174 | MEDIUM (one client-side function only; the *drop* side — what spawns a pickup entity — was not located in this read, likely server-side and unread) |
| Item delta-network sync (a fixed 0x118-byte item record with a dirty bitmask) | server `net_encode_field_item0x118` / `net_decode_field_item0x118` ("delta-encode/decode 0x118-byte item struct if changed/dirty bit set") | `network/replication/` (inventory delta replication) | 250 | MEDIUM for the shape (dirty-bit delta encoding matches the same pattern already chosen in `network/protocol/`); LOW for the field layout — struct size matches the item-equality functions above, corroborating it is the same record, not a coincidence |
| Equipped-item visuals | client `EntityAppearance_compareEqual` (~0xA4-byte appearance/equip struct equality), `equipment::getActiveElement` (active element/rune list from equipment slots by weapon type), `GameController_avgEquippedColor` (averages equipped-item material colors) | `client/rendering/` or `client/animation/` (visual application of equipped items) | 225 | LOW–MEDIUM (GAP confidence `med`/`high` per function, but this is presentation-only and client-only) |

## 3. Deliberately out of scope

| Reference area | Why it is not reimplemented |
|---|---|
| `plasma::*` | the original engine layer; Godot replaces it entirely |
| `abstr::*` | reflection/binding layer with no gameplay meaning |
| `_library/*` | third-party code (SQLite, STL, CRT, FreeType) |
| `cube::GameController` outside its item-relevant slice | a 620-function client "god" class (camera, input, HUD, world interaction) with no planned matrix in 021–028; reading it in full is out of proportion to this brick — see §4 Q1 |
| `cube::Database`, `SpeechDb_*`/`db_upsert_blob`/`db_store_blob_wrapper` | generic SQLite key/value blob persistence, not item-specific; already out of scope per `matrix-entity.md` Q2 and `matrix-combat.md` Q1 |
| Exact item struct byte layout (0x118 size, field offsets), exact equip-slot count, item type-code enum values | decompiler-recovered data, not behavior, per `docs/reference/README.md` §5 — we record that a fixed-size record and a fixed-size slot array exist, and choose our own `ItemDefinition`/slot-schema shape at brick 156/158/164 |
| RNG-affix roll invoked from `GameController_onItemPickup` | not read past the one-line GAP summary; belongs to loot generation (172/173), not this brick — see §4 Q3 |

## 4. Open questions

| # | Question | Blocks | Resolved by |
|---|---|---|---|
| Q1 (RESOLVED — brick 028) | `cube::GameController` (620 functions, `cube/control/`) has no planned matrix among 021–028, yet several item/inventory functions — and, per `attribution.tsv`, the *actual* inventory-grid rebuild/scroll/hover logic that `GAP_ANALYSIS.md` mis-names `InventoryWidget_*` — live on it. Does a client-control matrix belong before brick 224/225, or does `matrix-client-server.md` (028) absorb it? | 224, 225 | `matrix-client-server.md` §4 Q2 (028): no dedicated matrix or brick. `GameController` is treated the same as `World`/`Creature`/the `Behavior` tree — a god-object whose functions are split by behaviour across the matrices/directories that already own them (items, quests, ui, and now network — see `matrix-client-server.md` §2's `GameController_disconnect` row). Its remaining unread functions are read on demand by whichever future brick needs them. |
| Q2 | Equipment slot count is contradictory across two server functions: `Creature_initEquipmentSlots` zero-inits 16 slot blocks, `creature_items_equal` compares 12 equipment slots. Neither is a VERIFIED `cube_types.h` offset (unlike combat's `cube_Creature_offsets`). Which count, if either, should brick 164's equipment slot schema take as a reference point — or is this LOW enough confidence to just choose our own slot count? | 164, 165 | brick 164 design note |
| Q3 | `GameController_onItemPickup` rolls an "rng affix" on pickup (GAP one-line summary only, body unread). Is server-side affix generation already covered by a planned loot brick (172/173), and does its RNG need to be the server-owned deterministic stream from `core/random/` (per `CLAUDE.md` §1 determinism rule)? | 172, 173 | a dedicated read of the affix-roll body before brick 173, or resolve independently since affix mechanics are gameplay design, not reverse-engineering-critical |

## 5. Reading budget

| Path | Depth | Left unread |
|---|---|---|
| `cube/attribution.tsv` | grepped for item/inv/equip/loot/db/store/shop/craft class names; full address range `4c1a10`–`4c6cc0` (InventoryWidget + the GameController rows in that range) | rows for classes outside this group; the rest of `GameController`'s 620 rows |
| `server/attribution.tsv` | same grep (no item-specific class found beyond `SpriteManager`, already in `matrix-entity.md`) | rows outside this group |
| `cube/GAP_ANALYSIS.md` | grepped `equip`/`inventory`/`InventoryWidget` (~25 rows); `## InventoryWidget (2)` section, full | the rest of the ~620-function `GameController` GAP entries; `game_misc`/`Interface` rows already covered by `matrix-combat.md` |
| `server/GAP_ANALYSIS.md` | grepped `item`/`inventory`/`equip`/`loot`/`currency`/`gold`/`coin`/`stack`/`slot` (~40 matched rows, item-relevant subset read) | the ~1400 non-matching rows (SQLite/nav/string plumbing reserved for other matrices) |
| `cube/ui/InventoryWidget.h` | full (6 declarations) | — |
| `server/db/Database.h` | full (3 declarations, matches generic pattern) | `cube/db/Database.h` (not read — assumed structurally identical per README §2.3, client mirrors server shape) |
| `server/include/cube_types.h` | grepped `item`/`inventory`/`equip`/`slot`/`stack` | full struct-offset catalogue (only combat's enums were VERIFIED-tagged; no item struct offsets exist to find) |
| `server/game_misc/game_misc.cpp` | grepped ~10 item-function names for call-site context only (~15 call sites) | the ~40 000-line file body itself |
