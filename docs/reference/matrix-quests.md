# Reference matrix — `quests`

| Field | Value |
|---|---|
| Group | `quests / NPCs / QuestText` |
| Backlog brick | `026` |
| Mapped on | `2026-09-01` |
| Sources read | server+client `attribution.tsv` grepped for `quest`/`npc` (server: 10 rows, all `QuestText` RB-tree/map plumbing; client: `QuestText` rows only, no dedicated NPC/Quest class in either binary); server `GAP_ANALYSIS.md` full-text grepped for `quest`/`npc`/`faction`/`hostil`/`ally` plus the `game_misc` section re-scanned for `dialog`/`reward`/`objective`/`shop`/`trade`/`interact`; client `GAP_ANALYSIS.md` full-text grepped for the same terms (~40 matched rows) and its `## QuestText (10)` section read in full; the `GameController`-section address range `488030`–`4e5c10` read for interaction/quest-score/quest-text-build context; server+client `cube_types.h` grepped for `quest`/`npc`/`faction` (only the `QuestText` placeholder-class struct exists, no VERIFIED offsets) |
| Coverage | 2 of 2 classes in the group placed (`QuestText`, `QuestTextNode` — deferred from `matrix-entity.md`); no dedicated NPC/Faction/Shop class exists in either binary, 7 "concept with no single class" rows recovered instead |

## 1. Class map

| Reference class | Binary | Role (one line, our words) | Placed | Bricks | Confidence | Note |
|---|:---:|---|---|---|:---:|---|
| `cube::QuestText` | both | map/tree container of per-node quest/dialogue text entries; parses `{...}`/`[...]` template markup into a `QuestTextNode` tree (`cube_QuestText_parseTemplate`); client adds placeholder substitution (`QuestText::substitute_placeholders`, resolving `$creature`/`$name`/`$item`/`$object`/`$zone`/`$stress`/`$number` tokens) | `gameplay/dialogue/` (shared template engine, same tree type `Speech` builds) + `gameplay/quests/` (quest-text instantiation) | 201, 205, 210 | MEDIUM (parse/substitute are `high` GAP confidence; the container itself is generic RB-tree plumbing — see §3) | shares its tree node type with `Speech` (`matrix-entity.md` row `cube::Speech`); the two classes are a templating front-end over the same `QuestTextNode` payload, not independent systems |
| `cube::QuestTextNode` | both | the tree-node payload type both `QuestText` and `Speech` build into (deep-copy `QuestTextNode_copyRec`/`QuestText_cloneNode`, recursive destroy, sentinel alloc) | `gameplay/dialogue/` (shared node/content model) | 201 | MEDIUM | same class, same confidence rationale as `matrix-entity.md`'s deferred row — nothing new read here beyond the client's `## QuestText (10)` section |

No `cube::NPC`, `cube::Quest`, `cube::Faction`, or `cube::Shop` class exists in either binary. NPCs are plain `Creature` instances (`matrix-entity.md`) distinguished only by a faction byte, a name drawn from `NameGen`, and an interaction handler keyed off proximity — see §2.

## 2. Concepts with no single class

| Concept | Evidence | Placed | Bricks | Confidence |
|---|---|---|---|---|
| NPC interaction entry point (proximity-triggered, opens dialog/trade) | client `GameController_interactNpc` (`4882e0`, GAP literal `'innkeeper'`: resolves target entity by world coords, opens trade/dialog UI), `GameController_interactSpecialObject` (`488030`, GAP literal `'There is nothing special.'`: finds a special entity, sets quest/dialog state and a message) | `gameplay/quests/` (dispatch) + `client/ui/` (dialog/trade panel trigger) | 199, 200, 211 | MEDIUM (client GAP rows are `high`; the dialog-vs-trade branch is inferred from the decompiled string literals, not a read body) |
| Quest text templating & placeholder substitution | `cube_QuestText_parseTemplate`, `QuestText::substitute_placeholders`, `GameController::build_quest_text` (constructs the substitution maps and invokes the substitution pass); shares machinery with `Speech_parseTextToNodes` (`matrix-entity.md` §1) | `gameplay/dialogue/` (template engine) | 201, 205, 210 | HIGH for parse/substitute control flow; MEDIUM for how quest text specifically feeds it (only the client's build step was read) |
| Quest progress as a polled derived score, not (only) a discrete objective list | `GameController_computeQuestScore` (`4df9c0`, GAP: "sums a weighted quest-progress score over 11 counters plus a class-change bonus"), `GameController_questStateChanged` (`4df880`, dirty-check gate comparable to the sibling `GameController_terrainStateChanged`) | `gameplay/quests/` (quest state / progression service) | 206, 208, 209 | LOW–MEDIUM (GAP `med`; the 11 counters and their weights were not recovered — see §4 Q1) |
| Quest item-requirement gating | `quest::checkItemThreshold` (`43e4a0`, sums matching bag/equipment item counts against a threshold keyed by ability id), `quest::hasActiveItemReq` (`444a90`, bag scan for a required item on an active quest object) | `gameplay/quests/` (an objective-evaluator "collect item" rule) | 207, 208 | LOW (GAP `med`/`low`; no struct layout recovered for what "quest object" or "ability id" here actually key into) |
| Quest state stored inline on the entity record, not a separate quest-tracking class | server `EntityData::copyAssign`/`copyConstruct` (`41df70`/`422f90`, GAP: member-wise copy of the ~0x1180-byte `Entity` struct explicitly enumerates "quest strings" alongside scalars/equipment) | `gameplay/quests/` (`QuestState`, attached to `PlayerState`/`EntityState` rather than a standalone registry) | 106, 205, 206 | LOW (struct existence is corroborated by two independent copy functions; field meaning is not) |
| Quest-id event matching | server `check_quest_id_match` (`409660`, "true if event type 0x19 and id matches computed value") | `gameplay/quests/` (progression trigger) — cross-ref `network/protocol/` | 205, 206, 251 | LOW — see §4 Q2 |
| NPC identity/appearance generation | client `NameGen::initFirstNameTables` (lazy-init NPC first-name/syllable wstring tables), `creature::generateAppearance`/server `generate_entity_appearance` (race-based appearance+stat randomization from a seed), `Spawn::initNameArrays` (NPC name/attribute arrays embedded in the `Spawn` record), `World_generateNpcSpawnList` (rand-weighted, level-scaled spawn table) | `gameplay/creature/` (NPC identity) + `world/spawns/` | 095, 106–107, 127 | MEDIUM (GAP mostly `high`/`med`); same subsystem as `matrix-world.md`'s `cube::Spawn` row and `matrix-entity.md`'s "Creature appearance/equipment default init" row, viewed here from the NPC-naming angle |

Faction/hostility/aggro (`World::areEntitiesHostile`, `hasNearbyAllyEntity`, `CombatBehavior::areHostile`/`isHostileTo`/`alertNearbyAllies`) is **not** re-placed here — it is already fully mapped to `gameplay/factions/` and `ai/perception/`/`ai/combat/` in `matrix-combat.md` §2 (bricks 194, 203, 204). NPC social behavior consumes that placement; this matrix only cross-references it.

## 3. Deliberately out of scope

| Reference area | Why it is not reimplemented |
|---|---|
| `plasma::*` | the original engine layer; Godot replaces it entirely |
| `abstr::*` | reflection/binding layer with no gameplay meaning |
| `_library/*` | third-party code (SQLite, STL, CRT, FreeType) |
| STL container internals attributed to `QuestText`/`QuestTextNode` (`std_map_insert*_QuestText`, `rbtree_destroyRecursive_QuestText`, `QuestText::copyStrings13`, `QuestText_node_free`, `QuestText_assignTree`, `QuestText_container_copyCtor`, and their client mirrors) | Native Godot `Dictionary`/`Array` replace hand-rolled `std::map`; no gameplay behavior lives in a tree-rebalance function — same reasoning as `matrix-entity.md` §3 |
| `Speech`, `Speech_parseTextToNodes`, `Speech_scrambleBlob`, the XML/UTF transcoding glue | Already placed (`gameplay/dialogue/`) and flagged out of scope (XML/UTF plumbing) in `matrix-entity.md` §1/§3 — cross-ref only, not re-placed |
| `cube::GameController` outside its quest/NPC-interaction slice (`interactNpc`, `interactSpecialObject`, `questStateChanged`, `computeQuestScore`, `build_quest_text`) | Same 620-function client "god" class already flagged out of scope beyond a relevant slice in `matrix-items.md` §3/§4 Q1 — this matrix adds evidence to that same open scoping question rather than opening a new one |
| Faction/hostility/aggro functions (`areEntitiesHostile`, `isHostileTo`, `alertNearbyAllies`, `hasNearbyAllyEntity`) | Already placed in `matrix-combat.md` §2 — see §2 note above |
| `check_quest_id_match`'s exact event-type byte (`0x19`) and the 11-counter weighting inside `computeQuestScore` | Decompiler-recovered data, not behavior (`docs/reference/README.md` §5) — we record that a numeric quest-progress score and an opcode-tagged event-match exist, and design our own objective/progression model at bricks 206–209 |

## 4. Open questions

| # | Question | Blocks | Resolved by |
|---|---|---|---|
| Q1 | `GameController_computeQuestScore`'s 11 counters (plus a class-change bonus) were not recovered past the GAP one-line summary. Should the reimplementation keep a derived numeric quest-progress score alongside the discrete objective list brick 207 plans, or is a discrete objective-evaluator model (already the backlog's design) a sufficient behavioral equivalent? | 206, 207, 208, 209 | brick 207/209 design note — likely resolvable without further reference reading, since the exact counters are decompiler data we would not ship anyway |
| Q2 | `check_quest_id_match` tests `event type == 0x19` against a computed id. Is this the same opcode-tagged event/record stream flagged as unresolved in `matrix-combat.md` Q1 (`readCombatActionFromStream`/`readHitFromStream`, deserializing fixed-size records from a SQLite blob) — i.e. one generic event-record format shared by combat and quest triggers — or an unrelated, quest-only trigger table? | 205, 206, 251 | a joint read of `World.cpp`'s stream-read functions and `check_quest_id_match`'s caller before brick 251; also re-opens `matrix-combat.md` Q1 |

Brick 200 ("Create NPC shop service") already covers the `interactNpc` trade-UI branch — no open question recorded for it.

## 5. Reading budget

| Path | Depth | Left unread |
|---|---|---|
| `server/attribution.tsv` | grepped `quest`/`npc` (10 rows, all `QuestText`) | rows outside this group |
| `server/GAP_ANALYSIS.md` | full-text grepped `quest`/`npc`/`faction`/`hostil`/`ally`; `game_misc` (105-row) section separately grepped for `dialog`/`reward`/`objective`/`shop`/`trade`/`interact`/`speech` | `CombatBehavior`, `RandomInteractionBehavior` sections (reserved for/already covered by `matrix-ai.md`, `matrix-combat.md`); the ~40 000-line `game_misc.cpp`/`World.cpp` bodies themselves — `check_quest_id_match`'s caller was not traced |
| `server/include/cube_types.h` | grepped `quest`/`npc`/`faction` | full struct-offset catalogue (no VERIFIED quest/NPC offsets exist to find) |
| `cube/attribution.tsv` | grepped `quest`/`npc`/`shop`/`trade`/`dialog`/`faction` (`QuestText` rows only) | rows outside this group |
| `cube/GAP_ANALYSIS.md` | full-text grepped `quest`/`npc`/`shop`/`trade`/`dialog`/`faction` (~40 rows); `## QuestText (10)` section, full; `GameController`-section address range `488030`–`4e5c10` read for surrounding context | the remainder of `GameController`'s ~558-row section; `AdaptionWidget`, `ChatWidget`, `SpeechWidget` sections (reserved for `matrix-ui.md`, 027) |
| `cube/include/cube_types.h` | grepped `quest`/`npc`/`faction` | full struct-offset catalogue (only the `QuestText`/`QuestTextNode` placeholder-class structs exist) |
