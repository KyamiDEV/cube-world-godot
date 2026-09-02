# Reference matrix — `world`

| Field | Value |
|---|---|
| Group | `world` |
| Backlog brick | `021` |
| Mapped on | `2026-09-01` |
| Sources read | server+client `attribution.tsv` (full, filtered to `World`, `Zone`, `Region`, `Dungeon`, `House`, `Spawn`, `Field`, `Chunk`, `ChunkBuffer`, `LandscapeTile`, `WorldInfo`, `WorldMap`, `ZoneTile` rows); server+client `GAP_ANALYSIS.md` sections `World`, `Spawn`, `Region`, `Server`, `WorldInfo`, `ChunkBuffer`, `Zone`, `WorldMap`, and the world-relevant rows of `game_misc`; the reconstructed `.h` for every class in the group (both binaries) |
| Coverage | 13 of 13 classes in the group placed |

## 1. Class map

| Reference class | Binary | Role (one line, our words) | Placed | Bricks | Confidence | Note |
|---|:---:|---|---|---|:---:|---|
| `cube::World` | both | god-object: terrain noise/height/climate fields, region-site & feature-cell generation, voxel block/column accessors, spatial entity queries, per-frame chunk/entity tick, zone save/network serialization — see §2 for the split | `world/generation/` | 056–067, 089–090 | LOW | — |
| `cube::Zone` | both | mid-size world subdivision that owns a chunk list and an entity vector and is the save/replication unit (`serializeZoneSaveData`, `deserializeZonePacket`, `extractChunkList`, `copyStateContainer`) | `world/zones/` | 060–067, 102–103 | MEDIUM | — |
| `cube::Region` | both | small (~0x5c-byte) macro-tile record used as the key for region-site/feature generation (`World_generateRegionSite` seeds by `regX,regZ`); `Region_getChunkCell` resolves a chunk pointer through a region-indexed grid | `world/regions/` | 061, 089–090 | MEDIUM | — |
| `cube::Dungeon` | both | ctor/vfunc stub only — no method bodies survived attribution; distinct RTTI type confirms dungeons are a first-class world-content kind, not a Region variant | `world/dungeons/` | 094 | LOW | — |
| `cube::House` | both | ctor/vfunc stub only, same evidence shape as `Dungeon`; distinct type from `Region`/`Zone` implies buildings are placed as discrete objects rather than baked into region data | `world/villages/` | 092–093 | LOW | — |
| `cube::Spawn` | both | spawn-point record; server-side ctor pulls in `CreatureAppearance_initDefault` and `Creature_initEquipmentSlots`, i.e. a spawn also carries the default appearance/loadout for what it spawns | `world/spawns/` | 095, 106–107 | MEDIUM | cross-ref `gameplay/creature/` for the appearance/equipment default it embeds |
| `cube::Field` | both | ctor/vfunc stub only; name and the sibling `World::getVoxelField`/`getField_plus0x10`/`getField0` accessors suggest a per-grid-cell terrain data record (height/biome/moisture cell), not a UI form field | `world/generation/` | 060–067 | LOW | — |
| `cube::Chunk` | client | client-side terrain block; only ctor/vfunc survived, but `Region_getChunkCell`/`Chunk_getColumnAt` (server) and `World_MapInsertChunk` (client) confirm chunks are keyed into a region grid and hold column data | NONE — superseded by `VoxelTerrain`'s own block/mesh streaming | — | MEDIUM | reference concept only; do not reimplement a parallel chunk cache |
| `cube::ChunkBuffer` | client | mesh-build scratch buffer for one chunk: pushes quad faces, samples voxel color+AO over a 3×3×3 neighborhood, propagates a flood-fill sky-light pass, then hands off via `loadAndNotify` | NONE — superseded by `VoxelMesherBlocky` | — | MEDIUM | the baked voxel-color-AO blend (`ChunkBuffer_sampleVoxelColorAO`) is the one piece with no direct Voxel Tools equivalent — flagged as Q1 |
| `cube::LandscapeTile` | client | vfunc stub only, zero method bodies attributed; name implies a coarser, likely LOD/minimap-scale tile distinct from `Chunk` | NONE — no reference evidence to place with confidence | — | LOW | revisit only if a distant-terrain LOD or overview-map need appears later |
| `cube::WorldInfo` | client | client-side world-content generator: `generateBiomeContent`, `placeStructure`, `scatterObjectsInArea`, `sampleTerrainHeight` — the client's own copy of generation logic, not merely a presentation cache of server output | `world/generation/`, `world/structures/` (see §2 split) | 067, 086–090 | MEDIUM | **architecturally not reused**: CLAUDE.md mandates server-authoritative generation, so this class's *existence* (client re-running generation) is a pattern we deliberately do not port — see Q2 |
| `cube::WorldMap` | client | overview/minimap state: allocates "discovered" flag arrays and looks up a per-tile display value (`WorldMap::lookupTileValue2`) | `client/ui/` | 229 | MEDIUM | fog-of-war/discovered-tile bitmask is the reusable idea; out of scope for this matrix beyond the pointer |
| `cube::ZoneTile` | client | vfunc stub only; grouped with `WorldMap`'s ctor pattern, most likely one discovered-map tile record per zone | `client/ui/` | 229 | LOW | — |

Rows for `Dungeon`, `House`, `Field`, `Chunk`, `LandscapeTile`, `ZoneTile` are `LOW` because the decompiler recovered only RTTI-linked ctor/vfunc thunks for them — the type's *existence and relationships* are solid evidence (confirmed in two independently-built binaries), but no behavioral method body survived to corroborate the one-line role above it.

## 2. Concepts with no single class

`cube::World` is a god-object; splitting its functions by actual behavior (not by class) is necessary to place them correctly.

| Concept | Evidence | Placed | Bricks | Confidence |
|---|---|---|---|:---:|
| Terrain noise/height/climate fields (value noise, temperature/humidity blend, base height field, river climate gate, water depth, biome border distance) | `World_baseHeightField`, `World_temperatureBlend`, `World_humidityBlend`, `World_riverClimateGate`, `World_waterDepthField`, `World_biomeBorderDistance`, `World::terrainOffset2D`, `valueNoise2D` (server `World`, `GAP_ANALYSIS.md` §World) | `world/generation/` | 060–067 | MEDIUM |
| Region-site & feature-cell placement (structure/POI seeding) | `World_generateRegionSite` (`srand(regX+0x108a+regZ*0x400+...)`), `World_generateRegionFeatures`, `World_featureCountRange`, `World_featureTier`, `World::findNearestFeatureCell`, `World::objectFalloffWeight`, `World::falloffSquared` (server `World`) | `world/structures/` | 089–090 | MEDIUM |
| Voxel block/column/field accessors (`getBlockAt`, `Column_getBlockChecked`, `Chunk_getColumnAt`, `Region_getChunkCell`, `World::getVoxelField`, `VoxelGrid::cellAt3D`, `VoxelGrid::remapCoords`, `World_getTileAtCoords`) | server `game_misc` + `World` sections | NONE — `VoxelTerrain`/`VoxelMesherBlocky` own storage and access | — | MEDIUM |
| Client per-frame chunk/entity tick (`World::updateActiveChunks`, `World::updateNearbyEntities`) | client `World` section, `GAP_ANALYSIS.md` | NONE — superseded by Godot's `_process`/`_physics_process` + `VoxelViewer` interest streaming | — | LOW |
| Zone/world save-state serialization and delta/dirty-bit field encoding (`serializeZoneSaveData`, `deserializeZonePacket`, `Zone::extractChunkList`, `Zone::copyStateContainer`, the `net_encode_field_*`/`net_decode_field_*` family) | server `World`/`Zone`/`game_misc` sections | `world/persistence/` (save shape) and `network/protocol/` (the encode/decode pattern maps directly to our delta/snapshot design) | 102–103, 244–250 | MEDIUM |
| `WorldInfo` biome content population (spawns, terrain features, decoration) | `WorldInfo_generateBiomeContent` (client) | `world/biomes/` | 067–068 | LOW — **067's half closed**: the function was opened by brick 067 and yields nothing about a biome *record*. It is a placement routine (water/path feature generators, a rotate-and-place helper, a ~6 KB stack frame) with no recoverable structure, and content population is 068+, 086–088 and 095. The reference has no biome catalog to draw on at all; see the `Terrain_computeBiomeColor` row below and `docs/world-generation.md` §12.5 |
| `WorldInfo` structure placement (`placeStructure`, footprint + vector append) | client `WorldInfo` section | `world/structures/` | 090–091 | LOW |
| `WorldInfo` decoration/object scatter (`scatterObjectsInArea`, sqrt-spacing placement) | client `WorldInfo` section | `world/generation/` (natural decoration masks) | 086–088 | LOW |
| Procedural region/place naming (`NameGen::generateRegionName`, syllable tables) | client `World` section | `world/regions/` — deferred to Phase J (map/UI, 229) or a brick inserted there by that scoping pass; **not** the biome catalog, see §4 Q4 | 229 | LOW |
| Biome colour from climate noise (`Terrain_computeBiomeColor`, `terrain_biomeColorFromNoise`) | client `GameController`/`game_misc` sections, `GAP_ANALYSIS.md` | NONE as a catalog — the original has no biome enum, table or record: a biome there is a *continuous* terrain/vegetation RGBA blended from temperature/humidity/height noise. Our discrete six-id catalog is a deliberate divergence (`docs/world-generation.md` §12.5); brick 075 carried the same divergence into discrete *materials*, dithered rather than tinted (§14.5); the colour blend itself may still be relevant to Phase J terrain shading | 067, 075, Phase J | LOW |

## 3. Deliberately out of scope

| Reference area | Why it is not reimplemented |
|---|---|
| `plasma::*` | the original engine layer; Godot replaces it entirely |
| `abstr::*` | reflection/binding layer with no gameplay meaning |
| `_library/*` | third-party code (SQLite, STL, CRT, FreeType) |
| Combat/creature functions physically adjacent to `World` in `game_misc` (`Combat_getResistFactor`, `Combat_computeMaxHealth`, `Combat_upsertBuffEntry`, `Combat_selectNextAttackAnim`, `Creature::moveToward`, `Creature::stepAlongPath`, `Creature::resolveSeparation`, etc.) | Misfiled by binary layout, not by subsystem — these are combat/creature behavior, not world. Reserved for `matrix-combat.md` (024) and `matrix-entity.md` (022) so they are not silently dropped or double-counted. |
| `NavGraph::*` (`heuristicCost`, `lookupNode`, `addNode`, `reconstructPath`, `openSetContains`, `expandNeighbors`, `findPath`) in server `game_misc` | Pathfinding over the world grid, but the behavior itself is AI, not world state. Reserved for `matrix-ai.md` (023); flagged as an open question here because it reads world block data directly (Q3). |
| XML/UTF encoding helpers in both `game_misc` sections (`Xml_*`, `Utf8_*`, `Utf16_*`, `Utf32_*`, `Transcode_dispatch`) | Generic data/asset-format plumbing with no world-specific behavior; not gameplay logic. |
| `cube::WorldPreviewWidget` (client, 1 attributed function) | A UI widget, not world state. Left for `matrix-ui.md` (027), which owns all `Widget` classes. |

## 4. Open questions

| # | Question | Blocks | Resolved by |
|---|---|---|---|
| Q1 (RESOLVED — brick 040) | `ChunkBuffer_sampleVoxelColorAO` blends voxel color with baked ambient occlusion over a 3×3×3 neighborhood — does our chosen terrain material/shader need an equivalent, or is `VoxelMesherBlocky` baked-AO (if any) sufficient for the target look? | 040–041 | `docs/voxel-tools.md` §7 — `VoxelMesherBlocky` always bakes AO into cube-edge vertex colors; a model material only needs `vertex_color_use_as_albedo = true` to show it (confirmed against `godot_voxel`'s `doc/source/blocky_terrain.md`). Sufficient on its own; no custom shader needed. `blocky_library_builder.gd` (037) sets that flag. |
| Q2 (RESOLVED — brick 056) | The client runs its own copy of world generation (`WorldInfo`) rather than only presenting replicated server state. Confirm this was singleplayer/local-host convenience in the original game (not a networked-client trust model) before treating "client never generates" as safe to assume without caveat. | 056, 096–101 | `world-generation-authority.md` — **neither**: it is a bandwidth design. Both binaries hold one integer world seed in the same world-struct slot and mix it with region coordinates using the same constants, so terrain is never transmitted, it is recomputed on both sides (attributed server→client traffic is entity/zone state only). "Client never generates" is therefore **not** safe to assume; the rule adopted instead is *the client may generate, the client never decides* — the server resolves every gameplay conclusion against its own generation, and `(seed, generation version)` agreement becomes a checked handshake precondition (`WorldSeed.mismatch_reason()`, brick 056; enforcement 235–236). |
| Q3 | `NavGraph` (server `game_misc`) reads block/column data directly rather than through a `World`-owned accessor. When `matrix-ai.md` (023) is written, confirm what read-only world query surface AI pathfinding actually needs, so `world/terrain/` doesn't have to expose raw voxel internals to `ai/navigation/`. | 023, 185 | `matrix-ai.md` (023) |
| Q4 (RESOLVED — brick 067) | No backlog brick currently covers procedural region/place naming (`NameGen::generateRegionName`). Decide whether this is in scope at all (Phase D biome catalog, or a Phase J map/UI brick) or explicitly deferred. | — | `docs/world-generation.md` §12.7 — **not the biome catalog**, and not Phase D. A biome record names a *kind* of place: six of them, permanent, identical in every world, and keyed by a stable id. A region name names *one* place, is generated per world from its coordinates, and is display text with no id at all — the two share nothing but the word "name". It is therefore a Phase J map/UI concern (the map shell, 229) or its own brick inserted there, and it is **explicitly deferred** to that scoping pass rather than left open. Nothing in Phase D is blocked by it. |

## 5. Reading budget

| Path | Depth | Left unread |
|---|---|---|
| `server/attribution.tsv` | full (grepped for group class names) | rows for classes outside this group |
| `server/GAP_ANALYSIS.md` | sections `World`, `Spawn`, `Region`, `Server`, `game_misc` (world-relevant rows only) | `audit`, `crtstl`, `other`, `sqlite`, `CombatBehavior`, `Speech`, `Connection`, `Creature`, `RandomInteractionBehavior`, `QuestText`, `CompanionBehavior` sections (reserved for other matrices) |
| `server/world/World.h`, `Zone.h`, `Region.h`, `Dungeon.h`, `House.h`, `Spawn.h`, `Field.h` | full (headers only) | the `.cpp` bodies (`World.cpp` is 6897 lines; `Zone.cpp` 280; `Region.cpp` 151; `Spawn.cpp` 296; `House.cpp` 131; `Dungeon.cpp` 67; `Field.cpp` 40) — behavior for named functions was taken from `GAP_ANALYSIS.md` summaries, not the raw decompiled bodies |
| `cube/attribution.tsv` | full (grepped for group class names) | rows for classes outside this group |
| `cube/GAP_ANALYSIS.md` | sections `World`, `WorldInfo`, `ChunkBuffer`, `Zone`, `WorldMap`, `Spawn` | all other sections (reserved for other matrices) |
| `cube/world/Chunk.h`, `ChunkBuffer.h`, `LandscapeTile.h`, `WorldInfo.h`, `WorldMap.h`, `ZoneTile.h` | full (headers only) | the corresponding `.cpp` bodies — not opened this brick |
