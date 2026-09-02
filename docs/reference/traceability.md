# Traceability index — reference notes → backlog

| Field | Value |
|---|---|
| Backlog brick | `030` |
| Built on | `2026-09-01` |
| Sources | the `Bricks` columns of `matrix-world.md`…`matrix-client-server.md` (021–028, §1 and §2 of each) and their `§4 Open questions` `Blocks` columns |
| Purpose | reverse the matrices: given a backlog brick, find what reference evidence already exists for it, and whether an open question gates it |

This is an **index of indices** — same rule as `matrix-index.md` §1: it says where evidence
lives, it does not restate it. Read the cited matrix section for the actual claim,
evidence, and confidence rationale. Nothing here is a substitute for `confidence.md`.

## 1. How to use this

Before starting a backlog brick, search this file for its ID.

- A row found: the cited matrix section is the starting point (`CLAUDE.md` §4.2 — read
  only what that section names, not the whole matrix). Check the `Open Q` column — if
  set, resolve or explicitly accept the uncertainty before designing against the claim
  (`confidence.md` §5).
- No row found: either the brick is original design with no `cube::` reference behavior
  to draw from (most of Phase A, C, L — see §4), or no matrix has cross-referenced it
  yet. Both are valid states; this file does not assert the reference tree was searched
  for every unlisted brick, only that no matrix row currently names it.

## 2. Brick → reference index

One row per (brick range, matrix row/concept) pair, in the matrix's own words
(abbreviated — see the cited section for the full claim). Sorted by phase, then by the
lowest brick number in the range.

### Phase D — World generation (056–090)

| Brick(s) | Source | Row / concept | Placed | Confidence | Open Q |
|---|---|---|---|:---:|---|
| 056–067, 089–090 | `matrix-world.md` §1 | `cube::World` (god-object: noise/height/climate, region-site/feature gen, per-frame tick — see §2 split) | `world/generation/` | LOW | — |
| 056, 096–101 | `matrix-world.md` §4 | Q2 — **RESOLVED (brick 056)**: client re-ran world generation locally as a bandwidth design, not a trust model; "the client may generate, the client never decides" | — | — | resolved |
| 056, 096–101, 235–236, 248 | `world-generation-authority.md` | who may generate world content, and why `(seed, generation version)` agreement is a network contract rather than an internal detail | `world/generation/world_seed.gd`, `docs/world-generation.md` §1 | MEDIUM | — |
| 058, 061, 089–090 | `region-coordinate-hashing.md` | how the original turned world coordinates into generated content (`srand(regX + 0x108a + regZ * 0x400 + seed * 3)`), and the shape of the region grid it ran on | `world/generation/generation_grid.gd`, `world/generation/generation_hash.gd`, `docs/world-generation.md` §3 | MEDIUM | — |
| 060–067 | `terrain-value-noise.md` | the original's coherent-noise primitive (`valueNoise2D`): value noise, cosine interpolation, a linear corner key, no seed parameter, and a lattice taken by truncation — so a field mirrored about the origin | `world/generation/value_noise.gd`, `world/generation/continentalness.gd`, `docs/world-generation.md` §5 | MEDIUM | — |
| 060–067 | `matrix-world.md` §1 | `cube::Zone` (also 102–103) | `world/zones/` | MEDIUM | — |
| 061–063, 080, 089–090 | `terrain-base-height-field.md` | how the original stacked that primitive into a ground height: three decade-spaced relief tiers, each *placed* by a squared weight field one decade coarser, added upward on a base blended from region data | `world/generation/elevation_field.gd`, `world/generation/erosion_pass.gd`, `docs/world-generation.md` §6-7 (brick 063's `terrace_pass.gd` inherits claim 6's "a pass only lowers" shape and nothing else — the quantisation itself has **no** reference basis, `docs/world-generation.md` §8.6; brick 064 **contradicted** the note's claim 7 and closed its `U2` — see the `terrain-climate-blend.md` row above) | MEDIUM | — |
| 064–067, 074, 085, 089–090 | `terrain-climate-blend.md` | how the original produced climate: a nearest-region-site blend over stored per-region values, sharing only the site-jitter noise with the height field — so climate is **not** derived from elevation (closes `terrain-base-height-field.md` `U2`, contradicts its claim 7) | `world/generation/temperature_field.gd`, `world/generation/humidity_field.gd`, `docs/world-generation.md` §9-10 | MEDIUM | — |
| 060–067 | `matrix-world.md` §1 | `cube::Field` | `world/generation/` | LOW | — |
| 060–067 | `matrix-world.md` §2 | terrain noise/height/climate fields | `world/generation/` | MEDIUM | — |
| 061, 089–090 | `matrix-world.md` §1 | `cube::Region` | `world/regions/` | MEDIUM | — |
| 067, 086–090 | `matrix-world.md` §1 | `cube::WorldInfo` (client generation-logic copy, not just a cache) | `world/generation/`, `world/structures/` | MEDIUM | — |
| 067–068 | `matrix-world.md` §2 | `WorldInfo` biome content population | `world/biomes/` | LOW | — |
| 086–088 | `matrix-world.md` §2 | `WorldInfo` decoration/object scatter | `world/generation/` | LOW | — |
| 089–090 | `matrix-world.md` §2 | region-site & feature-cell placement (structure/POI seeding) | `world/structures/` | MEDIUM | — |
| 090–091 | `matrix-world.md` §2 | `WorldInfo` structure placement | `world/structures/` | LOW | — |
| — (no brick) | `matrix-world.md` §4 | Q4 — procedural region/place naming (`NameGen`) has no owning brick | `world/regions/` | LOW | **Q4** |

### Phase E — World streaming & persistence (091–105)

| Brick(s) | Source | Row / concept | Placed | Confidence | Open Q |
|---|---|---|---|:---:|---|
| 092–093 | `matrix-world.md` §1 | `cube::House` | `world/villages/` | LOW | — |
| 094 | `matrix-world.md` §1 | `cube::Dungeon` | `world/dungeons/` | LOW | — |
| 095, 106–107 | `matrix-world.md` §1 | `cube::Spawn` (embeds default appearance/loadout) | `world/spawns/` | MEDIUM | — |
| 095, 106–107, 127 | `matrix-quests.md` §2 | NPC identity/appearance generation (`NameGen`, `generate_entity_appearance`, `World_generateNpcSpawnList`) | `gameplay/creature/`, `world/spawns/` | MEDIUM | — |
| 102–103, 244–250 | `matrix-world.md` §2 | zone/world save-state serialization + dirty-bit field encode/decode pattern (maps directly onto our delta/snapshot design) | `world/persistence/`, `network/protocol/` | MEDIUM | — |

### Phase F — Entities & player (106–130)

| Brick(s) | Source | Row / concept | Placed | Confidence | Open Q |
|---|---|---|---|:---:|---|
| 106, 205, 206 | `matrix-quests.md` §2 | quest state stored inline on the entity record, not a standalone tracker | `gameplay/quests/` | LOW | — |
| 112, 116, 125–128 | `matrix-entity.md` §1 | `cube::Creature` (state chassis; §2 for the behavior split) | `gameplay/entity/` | MEDIUM | — |
| 112, 128, 243 | `matrix-entity.md` §2 | creature locomotion (`moveToward`/`stepAlongPath`/`resolveSeparation`) | `gameplay/creature/` | MEDIUM (`moveToward`); LOW (`stepAlongPath`/`resolveSeparation`) | **Q1** (matrix-entity) |
| 116 | `matrix-entity.md` §2 | client player-controller full/partial reset (`Player::resetFull`/`resetState`) | `client/player/` | MEDIUM | — |
| 125 | `matrix-entity.md` §2 | replicated entity-state apply/serialize (`deserializeState`) | `network/replication/` | LOW | — |
| 126, 164 | `matrix-entity.md` §2 | creature appearance/equipment default init | `gameplay/equipment/`, `gameplay/creature/` | MEDIUM | — |
| 128, 185 | `matrix-ai.md` §1 | `cube::WalkPathBehavior` (patrol, nav-graph fallback) | `ai/navigation/`, `ai/behavior/` | MEDIUM | — |
| 213 | `matrix-entity.md` §2 | localized display-name resolution (`format_object_singular_name`) | `gameplay/entity/` or `client/ui/` | LOW | — |

### Phase G — Combat, stats & progression (131–155)

| Brick(s) | Source | Row / concept | Placed | Confidence | Open Q |
|---|---|---|---|:---:|---|
| 132, 141 | `matrix-combat.md` §2 | attack-speed / haste computation | `gameplay/stats/` | MEDIUM | — |
| 133 | `matrix-combat.md` §2 | max-health formula (`2^a*2^b*base`) | `gameplay/stats/` | HIGH (shape) | — |
| 134, 135 | `matrix-combat.md` §2 | resource regen (mana/spirit, stamina) | `gameplay/stats/` | MEDIUM | — |
| 138, 139, 140 | `matrix-combat.md` §2 | attack-opcode / animation-state classification | `gameplay/combat/` | MEDIUM (predicates); LOW (2 unread selection trees) | **Q3** (matrix-combat) |
| 139 | `matrix-combat.md` §2 | ability timing table (cooldown/cast/recovery/windup) | `gameplay/combat/` | HIGH (shape only — per-ability constants are decompiler data, not ours to ship) | — |
| 141 | `matrix-combat.md` §2 | base damage formula | `gameplay/combat/` | MEDIUM | — |
| 141–144 | `matrix-combat.md` §4 | Q2 — unexplained `2^a*2^b[/2^c]` formula shape across 4 functions | — | — | **Q2** (may not need resolving, clean-room policy) |
| 142 | `matrix-combat.md` §2 | armor / mitigation | `gameplay/combat/` | MEDIUM | — |
| 143 | `matrix-combat.md` §2 | resist / diminishing-returns factor | `gameplay/combat/` | HIGH | — |
| 146 | `matrix-combat.md` §2 | buff/status-effect list (VERIFIED `cube_BuffNode_offsets`) | `gameplay/combat/` | HIGH | — |

### Phase H — Inventory, items, equipment & loot (156–175)

| Brick(s) | Source | Row / concept | Placed | Confidence | Open Q |
|---|---|---|---|:---:|---|
| 156, 157 | `matrix-items.md` §2 | item/entity definition loading from a serialized descriptor | `gameplay/loot/` or `core/ids/` (`DefinitionRegistry`) | LOW | — |
| 156, 158 | `matrix-items.md` §2 | item record equality/copy (fixed ~0x118-byte struct) | `gameplay/inventory/` | LOW–MEDIUM | — |
| 157, 161, 164 | `matrix-items.md` §2 | item type classification (stackable/category/slot mapping) | `gameplay/inventory/`, `gameplay/equipment/` | MEDIUM | — |
| 159, 166, 224 | `matrix-items.md` §2 | client-side inventory management (`GameController_*`, mis-GAP-named `InventoryWidget_*`) | `client/ui/`, `gameplay/inventory/` | MEDIUM–HIGH | — |
| 160, 161 | `matrix-items.md` §2 | inventory count/currency accumulation | `gameplay/inventory/` | LOW | — |
| 164, 165 | `matrix-items.md` §2 | equipment slot array on a creature | `gameplay/equipment/` | LOW | **Q2** (matrix-items) |
| 167 | `matrix-combat.md` §2 / `matrix-items.md` §2 | equipment-derived stat-bonus plumbing | `gameplay/equipment/` | LOW–MEDIUM | — |
| 172, 173 | `matrix-items.md` §4 | Q3 — unread "rng affix" roll in `GameController_onItemPickup` | — | — | **Q3** (matrix-items) |
| 172, 174 | `matrix-items.md` §2 | item pickup / drop consumption | `gameplay/loot/` | MEDIUM | — |

### Phase I — AI, NPCs, companions & quests (176–210)

| Brick(s) | Source | Row / concept | Placed | Confidence | Open Q |
|---|---|---|---|:---:|---|
| 176, 179, 180, 181 | `matrix-ai.md` §2 | `Behavior` base tick/clone interface (no surviving base class, inferred from shape) | `ai/behavior/` (`BehaviorNode`) | MEDIUM | — |
| 177, 178 | `matrix-ai.md` §1 | `cube::SequentialBehavior` | `ai/behavior/` | MEDIUM | **Q1** (matrix-ai) |
| 179, 180 | `matrix-ai.md` §2 | no leaf reads as a pure boolean Condition | `ai/behavior/` | LOW (absence-of-evidence) | — |
| 183, 184, 188 | `matrix-ai.md` §1 | `cube::LookAtPlayerBehavior` | `ai/behavior/`, `ai/perception/` | MEDIUM | — |
| 184, 194 | `matrix-combat.md` §2 | threat / target selection | `ai/combat/` | HIGH (control flow; score weighting unread) | — |
| 185 | `matrix-ai.md` §2 | shared locomotion/pathing primitives (`NavGraph_*`, `World_getBlockFloat`) | `ai/navigation/` | MEDIUM | cross-ref matrix-entity Q1 |
| 186, 187 | `matrix-ai.md` §1 | `cube::RandomWalkBehavior` | `ai/behavior/` | MEDIUM | — |
| 189, 199 | `matrix-ai.md` §1 | `cube::RandomInteractionBehavior` | `ai/behavior/` | LOW | **Q3** (matrix-ai) |
| 190 | `matrix-ai.md` §1 | `cube::SpawnLocationBehavior` | `ai/behavior/` or NPC schedule | LOW–MEDIUM | **Q2** (matrix-ai) |
| 191, 192, 194, 195 | `matrix-ai.md` §1 / `matrix-combat.md` §1 | `cube::CombatBehavior` (tick shell only — resolution math is `matrix-combat.md` §2) | `ai/combat/` | MEDIUM | — |
| 194 | `matrix-combat.md` §2 | aggro alert propagation | `ai/perception/` or `ai/combat/` | MEDIUM | — |
| 194, 203, 204 | `matrix-combat.md` §2 | hostility / PvP-duel gate | `gameplay/factions/` | HIGH | — |
| 196, 197 | `matrix-ai.md` §1 | `cube::CompanionBehavior` | `ai/behavior/`; locomotion cross-ref `gameplay/creature/` | MEDIUM | — |
| 199, 200, 211 | `matrix-quests.md` §2 | NPC interaction entry point (`interactNpc`/`interactSpecialObject`) | `gameplay/quests/`, `client/ui/` | MEDIUM | — |
| 201, 205, 210 | `matrix-quests.md` §1/§2 | `cube::QuestText` + template/placeholder substitution | `gameplay/dialogue/`, `gameplay/quests/` | MEDIUM (container); HIGH (parse/substitute control flow) | — |
| 201 | `matrix-quests.md` §1 | `cube::QuestTextNode` (shared node type with `Speech`) | `gameplay/dialogue/` | MEDIUM | — |
| 205, 206, 251 | `matrix-quests.md` §2 | quest-id event matching (`check_quest_id_match`, event type `0x19`) | `gameplay/quests/` | LOW | **Q2** (matrix-quests) |
| 205–210 | `matrix-client-server.md` §2 | combat-trigger stream readers, resolved as quest/mission-scripted DB data | `gameplay/quests/` | HIGH (call-site read) | — |
| 206, 207, 208, 209 | `matrix-quests.md` §4 | Q1 — 11-counter quest score vs. the backlog's discrete objective-list design | — | — | **Q1** (matrix-quests; likely resolvable by design decision alone) |
| 206, 208, 209 | `matrix-quests.md` §2 | quest progress as a polled derived score (`computeQuestScore`) | `gameplay/quests/` | LOW–MEDIUM | — |
| 207, 208 | `matrix-quests.md` §2 | quest item-requirement gating | `gameplay/quests/` | LOW | — |

### Phase J — Client presentation, UI & audio (211–230)

| Brick(s) | Source | Row / concept | Placed | Confidence | Open Q |
|---|---|---|---|:---:|---|
| 224 | `matrix-items.md` §1 | `cube::InventoryWidget` (own ctor/dtor/vfuncs only) | `client/ui/` | MEDIUM | — |
| 224, 225 | `matrix-items.md` §4 | Q1 — **RESOLVED (brick 028)**: `GameController` scoping — no dedicated matrix/brick, split by behavior | — | — | resolved |
| 224, 231 | `matrix-ui.md` §2 | widget event dispatch / focus routing | `client/ui/` | MEDIUM | — |
| 224–231 | `matrix-ui.md` §4 | Q2 — **RESOLVED (brick 028)**: same `GameController` resolution as above | — | — | resolved |
| 225 | `matrix-items.md` §2 | equipped-item visuals (`Equipment::getActiveElement`, `avgEquippedColor`) | `client/rendering/` or `client/animation/` | LOW–MEDIUM | — |
| 226 | `matrix-ui.md` §1 | `cube::SkillWidget` (stub) | `client/ui/` | LOW | — |
| 227 | `matrix-ui.md` §1 | `cube::ObjectiveWidget` (stub — presentation side of the quest-score row) | `client/ui/` | LOW | — |
| 228 | `matrix-ui.md` §1 | `cube::SpeechWidget` (typewriter reveal over `Speech`/`QuestText` tree) | `client/ui/` | MEDIUM–HIGH | — |
| 229 | `matrix-world.md` §1 | `cube::WorldMap`, `cube::ZoneTile` | `client/ui/` | MEDIUM / LOW | — |
| 229 | `matrix-ui.md` §1 | `cube::MapOverlayWidget` (stub) | `client/ui/` | LOW | — |
| 230 | `matrix-ui.md` §1 | `cube::ChatWidget` | `client/ui/` | MEDIUM–HIGH | — |
| 231 | `matrix-ui.md` §1 | `cube::OptionsWidget`, `cube::SystemWidget` | `client/ui/` | MEDIUM–HIGH / LOW | — |
| (phase J/K planning) | `matrix-ui.md` §4 | Q1 — no brick covers character creation, main menu/title screen, or the merchant/trade dialog | — | — | **Q1** (matrix-ui) |

### Phase K — Networking & dedicated server (231–256)

| Brick(s) | Source | Row / concept | Placed | Confidence | Open Q |
|---|---|---|---|:---:|---|
| 233, 253 | `matrix-client-server.md` §1 | `cube::Server` (own functions only — send-loop is §2) | `network/server/` | LOW | — |
| 235, 254, 256 | `matrix-client-server.md` §1 | `cube::Connection` (own functions only — recv-dispatch is §2) | `network/server/` | LOW | — |
| 235, 236 | `matrix-client-server.md` §4 | Q3 — no connect/login/handshake function found in either binary | — | — | **Q3** (matrix-client-server; not required by clean-room policy) |
| 235, 237–243, 254 | `matrix-client-server.md` §2 | per-connection receive dispatch (`Connection::receiveDispatch`) | `network/server/` | MEDIUM | — |
| 235, 256 | `matrix-client-server.md` §2 | client network lifecycle (`GameController_disconnect`) | `network/client/`, `client/ui/` | MEDIUM | — |
| 244, 245 | `matrix-client-server.md` §2 | client-side dirty-bit field receive + entity-state deserialize/receive masters | `network/client/` | MEDIUM | — |
| 244, 246 | `matrix-client-server.md` §2 | client world/entity-state apply (`GameWorld::deserialize_state`) | `network/client/`, `world/streaming/` | LOW | — |
| 244, 250 | `matrix-client-server.md` §2 | entity full-state / delta-state serialization (`serializeToStream`/`writeDelta`) — corroborates our SNAPSHOT/DELTA kinds | `network/protocol/`, `network/replication/` | MEDIUM | — |
| 246, 248, 249 | `matrix-client-server.md` §2 | zone/chunk update packet (entity list + hit list together) | `network/replication/` | MEDIUM | — |
| 246–249, 261 | `matrix-client-server.md` §2 | per-connection send worker (`Server::worldUpdateSendLoop`) | `network/server/`, `server/simulation/` | MEDIUM | — |
| 249, 251 | `matrix-client-server.md` §2 | combat action/hit-record stream readers — resolved as quest data; 249/251 design combat-event replication **fresh**, no reference wire format | `network/replication/` | HIGH (that it is *not* network data) | — |
| 250 | `matrix-items.md` §2 | item delta-network sync (0x118 item record, dirty bitmask) | `network/replication/` | MEDIUM | — |

## 3. Open questions still gating bricks

Consolidated from every matrix's `§4 Open questions`. This mirrors `nextsteps.md`'s
"Next N actions" list (`confidence.md` §5 requires both); update both together when one
resolves. `(RESOLVED — brick NNN)` rows are listed for completeness, not because they
still gate anything.

| Q | Matrix | Blocks | Status |
|---|---|---|---|
| Q1 | `matrix-world.md` | 040–041 | RESOLVED — brick 040, `docs/voxel-tools.md` §7 |
| Q2 | `matrix-world.md` | 056, 096–101 | **RESOLVED — brick 056**, `world-generation-authority.md` |
| Q3 | `matrix-world.md` | 023, 185 | open |
| Q4 | `matrix-world.md` | — (no brick) | open |
| Q1 | `matrix-entity.md` | 112, 116, 128, 243 | open |
| Q2 | `matrix-entity.md` | — (no brick, `*/db/` matrix scoping) | open |
| Q3 | `matrix-entity.md` | 213, `client/effects/` (unscheduled) | open |
| Q1 | `matrix-ai.md` | 177, 178 | open |
| Q2 | `matrix-ai.md` | 190, 216 | open |
| Q3 | `matrix-ai.md` | 189, 199 | open |
| Q1 | `matrix-combat.md` | 136, 137, 249 | **RESOLVED — brick 028** |
| Q2 | `matrix-combat.md` | 141, 142, 143, 144 | open |
| Q3 | `matrix-combat.md` | 138, 139, 192 | open |
| Q1 | `matrix-items.md` | 224, 225 | **RESOLVED — brick 028** |
| Q2 | `matrix-items.md` | 164, 165 | open |
| Q3 | `matrix-items.md` | 172, 173 | open |
| Q1 | `matrix-quests.md` | 206, 207, 208, 209 | open |
| Q2 | `matrix-quests.md` | 205, 206, 251 | open |
| Q1 | `matrix-ui.md` | phase J/K planning (no specific brick) | open |
| Q2 | `matrix-ui.md` | 224–231, 028 | **RESOLVED — brick 028** |
| Q1 | `matrix-client-server.md` | 136, 137, 249, 251 | **RESOLVED — this brick's source (028)** |
| Q2 | `matrix-client-server.md` | 224–231 | **RESOLVED — this brick's source (028)** |
| Q3 | `matrix-client-server.md` | 235, 236 | open |

## 4. Bricks with no reference-informed row

Absence here means **no matrix currently cites the brick**, not "the reference tree was
searched and has nothing" (same caveat `matrix-index.md` ground rule 4 makes at the
matrix level). Two different reasons cover almost all of it:

- **Original design, no `cube::` behavior to draw from.** Phase A (001–010, bootstrap),
  most of Phase C (031–055, `VoxelBlockyLibrary`/`VoxelTerrain`/`VoxelMesherBlocky`
  wiring — Voxel Tools supersedes the reference's own `Chunk`/`ChunkBuffer`, per
  `matrix-world.md` §1), all of Phase B's own contract bricks (011–020, 029–030 — these
  *produced* the matrices, they don't consume one), brick 059 (Phase D's test fixtures —
  harness work, not generated behavior), brick 063 (the terrace quantisation — the note
  behind §2's `061–063` row records nothing about vertical quantisation, so 063 is
  original design within the pass shape 062 established; `docs/world-generation.md` §8.6),
  and most of Phase L (257–266,
  profiling/soak/release — process work, not behavior extracted from the binaries).
- **Not yet cross-referenced.** A brick inside Phase D–K with no row above (e.g. 148
  respawn state, 145 knockback, 147 death state, most of 231's settings-shell scope
  beyond the two widget rows) may still have reference material — nobody has searched
  for it yet, or the matrix author judged it clean-room-only design. Check the phase's
  matrix (`matrix-index.md`) directly before assuming there's nothing.

## 5. Maintenance rule

Update this file whenever:

- a matrix's `Bricks` column changes (a new brick added to `backlog.md`, or a row's
  placement revised);
- an open question resolves (update §3's `Status` cell to `(RESOLVED — brick NNN)`, add
  the resolution note, and drop the corresponding `nextsteps.md` "Next N actions" row —
  never delete the row here, same lifecycle as `confidence.md` §5);
- a per-subsystem note (`docs/reference/<subsystem>.md`, not yet started — `README.md`
  §3) is created; add its `Backlog bricks` citations here alongside the matrix rows they
  refine.
