# Reference matrix — `entity`

| Field | Value |
|---|---|
| Group | `entity` |
| Backlog brick | `022` |
| Mapped on | `2026-09-01` |
| Sources read | server+client `attribution.tsv` (full, filtered to `Creature`, `Sprite`, `SpriteManager`, `Speech`, `QuestText`, `QuestTextNode` rows); server `GAP_ANALYSIS.md` sections `Speech`, `Creature`, `Spawn`, `QuestText`, and the `Creature`/movement rows of `game_misc`; client `GAP_ANALYSIS.md` sections `Speech`, `QuestText`, `Creature`, `Sprite`, `World` (for `EntityState_serializeToBuffer`, `format_object_singular_name`), `Interface` (for the stat formulas physically filed there); the reconstructed `.h` for every class in the group (both binaries) |
| Coverage | 6 of 6 classes in the group placed |

## 1. Class map

| Reference class | Binary | Role (one line, our words) | Placed | Bricks | Confidence | Note |
|---|:---:|---|---|---|:---:|---|
| `cube::Creature` | both | entity state chassis: appearance/equipment slot arrays, networked containers (threat map, buff list, alert list), and — client-only — the local player controller's full reset (`Player::resetFull`/`resetState`) and replicated-state apply (`deserializeState`); functions are a zero-init/construct/destruct/container-erase shell with almost no gameplay body surviving attribution — see §2 for the behavior split | `gameplay/entity/` | 112, 116, 125–128 | MEDIUM | cross-ref `world/spawns/` for the appearance default a spawn embeds (`matrix-world.md` row `cube::Spawn`) |
| `cube::Sprite` | both | ctor/vfunc plus a map container (erase-range/erase-node) only; no behavior body survived — likely a lightweight per-entity visual handle keyed in a map, not a full class | `client/rendering/` | — | LOW | revisit only if a decal/status-icon/attachment need appears; server-side copy suggests a tracked handle, not pure presentation |
| `cube::SpriteManager` | both | ctor/vfunc stubs only; distinct RTTI type that owns/pools `Sprite` instances | `client/rendering/` | — | LOW | — |
| `cube::Speech` | both | dialogue-tree container: loads an obfuscated blob from SQLite (`Speech_scrambleBlob` shuffle+bitwise-NOT), parses raw text into a `QuestTextNode` tree (`Speech_parseTextToNodes`, splitting on `{}`/`[]` markup) — most of the class's *other* attributed functions are actually the generic XML parser/pool used to load that data, not speech-specific logic (misfiled by binary layout, same pattern as `matrix-world.md`'s XML rows) | `gameplay/dialogue/` (tree/content); XML load pipeline → `core/serialization/` | 026 | MEDIUM | `parseTextToNodes`/`scrambleBlob` are HIGH; the XML-utility split is MEDIUM |
| `cube::QuestText` | both | map/tree container of per-node quest text entries; template-parses `{...}`/`[...]` markup into a `QuestTextNode` tree (`cube_QuestText_parseTemplate`) | NONE — reserved for `matrix-quests.md` (026) | 026 | MEDIUM | physically in `*/entity/` (binary layout), but owned by the quest-text group per `matrix-index.md`; role recorded here so it is not silently dropped |
| `cube::QuestTextNode` | both | the tree-node payload type `QuestText`/`Speech` build into (deep-copy, recursive destroy, sentinel alloc) | NONE — reserved for `matrix-quests.md` (026) | 026 | MEDIUM | same reservation as `QuestText` |

Rows for `Sprite`, `SpriteManager` are `LOW` for the same reason as several `matrix-world.md` rows: only RTTI-linked ctor/vfunc thunks survived — the type's existence is solid evidence, but no method body corroborates a behavioral claim beyond it.

## 2. Concepts with no single class

`cube::Creature`'s own attributed functions are almost entirely constructor/destructor/container
plumbing; the actual gameplay behavior around creatures is scattered across `game_misc` (server)
and the `World`/`Interface` sections (client), split here by actual behavior.

| Concept | Evidence | Placed | Bricks | Confidence |
|---|---|---|---|:---:|
| Creature locomotion (steer-toward-target, step-along-path over voxel terrain, pairwise separation/collision push) | `Creature::moveToward`, `Creature::stepAlongPath`, `Creature::resolveSeparation` (server `game_misc`) | `gameplay/creature/` | 112, 128, 243 | MEDIUM (`moveToward` MEDIUM; `stepAlongPath`/`resolveSeparation` LOW — decompiler confidence, not ours) |
| Client player-controller full/partial reset (containers, timers, transforms, physics/stat members) on load or respawn | `Player::resetFull`, `Player::resetState` (client `Creature` section) | `client/player/` | 116 | MEDIUM |
| Replicated entity-state apply/serialize | `cube::Creature::deserializeState` (= `GameWorld::deserialize_state`, client `Creature` section), `EntityState_serializeToBuffer` (client `World` section) | `network/replication/` | 125 | LOW (both are decompiler-`low`-confidence bodies) — cross-ref `matrix-world.md` §2 zone/world serialization row (bricks 102–103, 244–250) |
| Creature appearance/equipment default init | `Creature_initEquipmentSlots`, `CreatureAppearance_initDefault` (server `Spawn` section), `Spawn_initDefaults` (client) | `gameplay/equipment/`, `gameplay/creature/` | 126, 164 | MEDIUM — cross-ref `matrix-world.md` row `cube::Spawn` (bricks 095, 106–107) |
| Localized display-name resolution for a creature/object (singular vs. generic name) | `format_object_singular_name` (client `World` section) | `gameplay/entity/` or `client/ui/` | 213 | LOW |
| Combat/derived-stat formulas physically filed under client class `Interface` rather than `Creature` or `CombatBehavior` | `stat::calcArmor`, `stat::calcManaRegen`, `stat::calcSpirit`, `Creature::compute_scale_factor`, `Equipment::sum_slot_values` | NONE here — reserved for `matrix-combat.md` (024) | 024 | LOW–MEDIUM |

## 3. Deliberately out of scope

| Reference area | Why it is not reimplemented |
|---|---|
| `plasma::*` | the original engine layer; Godot replaces it entirely |
| `abstr::*` | reflection/binding layer with no gameplay meaning |
| `_library/*` | third-party code (SQLite, STL, CRT, FreeType) |
| STL container internals attributed to `Creature`, `Speech`, `QuestText`, `Sprite` (`mapEraseRange`, `mapEraseNode_*`, `map_erase_node`/`_range`, list-node allocators, RB-tree iterator plumbing) | Native Godot `Dictionary`/`Array` replace hand-rolled `std::map`/`std::list`; there is no gameplay behavior in a tree-rebalance function. |
| XML/UTF encoding helpers physically filed under class `Speech` (`Xml_*`, `Utf8_*`, `Utf16_*`, `Utf32_*`, `Transcode_dispatch`, the `xml_*` client mirror) | Generic data/asset-format plumbing, not speech-specific — same pattern already flagged out of scope for `World` in `matrix-world.md` §3. Godot's own `XMLParser` (if XML is even kept as a dialogue format) supersedes it. |
| `CombatBehavior::*`, `Combat_*`, and the stat formulas listed in §2's last row | Combat resolution and derived stats, not entity identity/state. Reserved for `matrix-combat.md` (024) so they are not silently dropped or double-counted, mirroring how `matrix-world.md` reserved them for `022`/`024`. |
| `cube::QuestText`, `cube::QuestTextNode` | Physically in `*/entity/` by binary layout, but owned by `matrix-quests.md` (026) per `matrix-index.md`'s group definition — see class-map rows above. |
| `SpeechDb_createBlobsTable`, `SpeechDb_readBlobByKey`, `SpeechDb_loadBlobToVector` (server `game_misc`, filed near `Speech`) | Generic SQLite blob-storage glue, not Speech-specific — belongs with `cube::Database` (`*/db/`). No matrix currently covers `*/db/`; flagged as Q2. |
| `SpeechWidget`, `ChatWidget` (client) | UI widgets, not entity state. Left for `matrix-ui.md` (027), which owns all `Widget` classes — same treatment `matrix-world.md` gave `WorldPreviewWidget`. |

## 4. Open questions

| # | Question | Blocks | Resolved by |
|---|---|---|---|
| Q1 | No backlog brick currently owns basic creature/player locomotion as a *reference-informed* task — `112`/`116`/`128`/`243` create the Godot-side movement systems, but none is tagged as consuming `Creature::moveToward`/`stepAlongPath`/`resolveSeparation`. Confirm those bricks should cite this matrix, or add a dedicated brick. | 112, 116, 128, 243 | next `nextsteps.md` update / backlog amendment |
| Q2 | `cube::Database` (`*/db/`, e.g. `SpeechDb_*`) has no planned matrix in `matrix-index.md` (021–028 stops at world/entity/ai/combat/items/quests/ui/client-server). Decide whether it deserves its own matrix or folds into the already-written `docs/persistence.md`. | — | next `nextsteps.md` update / backlog amendment |
| Q3 | `Sprite`/`SpriteManager` carry only ctor/vfunc/map-container stubs in *both* binaries. Is this a presentation-layer handle (client visual effect/decal), or does the server-side copy imply a lightweight server-tracked marker (e.g. "this entity has an active status-effect sprite")? No behavior body survived to decide. | 213, `client/effects/` bricks (unscheduled) | revisit if/when a status-effect or attachment-marker need appears |

## 5. Reading budget

| Path | Depth | Left unread |
|---|---|---|
| `server/attribution.tsv` | full (grepped for group class names) | rows for classes outside this group |
| `server/GAP_ANALYSIS.md` | sections `Speech`, `Creature`, `Spawn`, `QuestText`; `game_misc` rows for `Creature::*` and `World_getTileAtCoords`-adjacent entries scanned for entity relevance | `CombatBehavior`, `Connection`, `RandomInteractionBehavior`, `CompanionBehavior`, `Region`, `Server`, `sqlite`, `World` sections (reserved for other matrices); the bulk of `game_misc`'s combat rows |
| `server/entity/Creature.h`, `Sprite.h`, `SpriteManager.h`, `Speech.h`, `QuestText.h`, `QuestTextNode.h` | full (headers only) | the `.cpp` bodies — behavior for named functions was taken from `GAP_ANALYSIS.md` summaries, not the raw decompiled bodies |
| `cube/attribution.tsv` | full (grepped for group class names) | rows for classes outside this group |
| `cube/GAP_ANALYSIS.md` | sections `Speech`, `QuestText`, `Creature`, `Sprite`; `World` section scanned for `EntityState_serializeToBuffer`/`format_object_singular_name`; `Interface` section scanned for stat-formula rows | `SpeechWidget`, `ChatWidget`, `CombatBehavior`, `ChunkBuffer`, `WorldInfo`, `ChunkBuffer` and all other sections (reserved for other matrices) |
| `cube/entity/Creature.h`, `Sprite.h`, `SpriteManager.h` | full (headers only) | `Speech.h`, `QuestText.h`, `QuestTextNode.h` client headers (server copies read instead; both binaries' attribution rows already cross-checked so the client headers were judged redundant) — not opened this brick |
