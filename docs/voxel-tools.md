# Voxel Tools — verified capability surface

> Verified by `tools/probe/probe_voxel.gd` (brick 003).
> Re-run after any engine rebuild: `godot --headless --script res://tools/probe/probe_voxel.gd`
> Exit code 0 = required version and classes present; 1 = mismatch (blocker).

## 1. Verified module

| Field | Value |
|---|---|
| Verified on | 2026-08-31 |
| Version | `1.7.0` |
| Edition | `Module` (compiled into the engine, **not** GDExtension) |
| Status | `release` |
| Module git hash | `4fa755eda714d4097498b13571700813c4249db6` |
| Default worker threads | `8` (host-dependent, not a contract) |
| Registered `Voxel*` / `ZN_*` classes | `74` |

**Requirement `Voxel Tools 1.7` — SATISFIED.**

Version is read at runtime from the `VoxelEngine` singleton
(`get_version_major/minor/patch`, `get_version_edition`, `get_version_git_hash`),
so it is a property of the running binary, not of a config file.

## 2. Required classes (all present)

Every class the architecture in `CLAUDE.md` §1 names is registered:

`VoxelTerrain`, `VoxelMesherBlocky`, `VoxelBlockyLibrary`, `VoxelBlockyModel`,
`VoxelBlockyModelCube`, `VoxelBlockyModelMesh`, `VoxelInstancer`, `VoxelInstanceLibrary`,
`VoxelViewer`, `VoxelBoxMover`, `VoxelStreamSQLite`, `VoxelGeneratorScript`, `VoxelTool`,
`VoxelToolTerrain`, `VoxelBuffer`, `VoxelRaycastResult`.

## 3. Full registered surface (1.7.0, this build)

Grouped for planning; the probe asserts only the required subset above.

**Terrain nodes** — `VoxelNode`, `VoxelTerrain`, `VoxelLodTerrain`,
`VoxelTerrainMultiplayerSynchronizer`, `VoxelViewer`.

**Meshers** — `VoxelMesher`, `VoxelMesherBlocky`, `VoxelMesherCubes`, `VoxelMesherTransvoxel`.

**Blocky model system** — `VoxelBlockyLibraryBase`, `VoxelBlockyLibrary`, `VoxelBlockyTypeLibrary`,
`VoxelBlockyType`, `VoxelBlockyModel`, `VoxelBlockyModelCube`, `VoxelBlockyModelMesh`,
`VoxelBlockyModelEmpty`, `VoxelBlockyModelFluid`, `VoxelBlockyFluid`,
`VoxelBlockyAttribute` (+ `Axis`, `Custom`, `Direction`, `Rotation`).

**Generation** — `VoxelGenerator`, `VoxelGeneratorScript`, `VoxelGeneratorFlat`,
`VoxelGeneratorHeightmap`, `VoxelGeneratorNoise`, `VoxelGeneratorNoise2D`,
`VoxelGeneratorWaves`, `VoxelGeneratorImage`, `VoxelGeneratorGraph`,
`VoxelGeneratorMultipassCB`, `VoxelGraphFunction`.

**Streams / persistence** — `VoxelStream`, `VoxelStreamSQLite`, `VoxelStreamRegionFiles`,
`VoxelStreamMemory`, `VoxelStreamScript`, `VoxelBlockSerializer`,
`VoxelSaveCompletionTracker`, `VoxelDataBlockEnterInfo`.

**Editing / query** — `VoxelTool`, `VoxelToolTerrain`, `VoxelToolLodTerrain`,
`VoxelToolBuffer`, `VoxelToolMultipassGenerator`, `VoxelRaycastResult`, `VoxelBoxMover`,
`VoxelAStarGrid3D`.

**Data** — `VoxelBuffer`, `VoxelFormat`, `VoxelColorPalette`, `VoxelMeshSDF`, `VoxelVoxLoader`.

**Instancing (vegetation/props)** — `VoxelInstancer`, `VoxelInstanceLibrary`,
`VoxelInstanceLibraryItem`, `VoxelInstanceLibraryMultiMeshItem`,
`VoxelInstanceLibrarySceneItem`, `VoxelInstanceGenerator`, `VoxelInstanceComponent`,
`VoxelInstancerRigidBody`.

**Modifiers (SDF only)** — `VoxelModifier`, `VoxelModifierMesh`, `VoxelModifierSphere`.

**Noise helpers** — `ZN_FastNoiseLite`, `ZN_FastNoiseLiteGradient`, `ZN_SpotNoise`,
`ZN_ThreadedTask`.

> `VoxelGI` / `VoxelGIData` in the class list are core Godot rendering classes, unrelated
> to Voxel Tools. Do not confuse them.

## 4. Consequences for this project

- **`VoxelStreamSQLite` is available**, so the persistence plan in `CLAUDE.md` §1/§11 stands
  with no fallback to `VoxelStreamRegionFiles`.
- **`VoxelTerrainMultiplayerSynchronizer` exists.** It is a *terrain-block* replication helper
  only. It does not replace the authoritative gameplay protocol (Phase K) and must not be used
  to move gameplay truth. Evaluate at brick 050 / Phase K.
- **`VoxelGeneratorMultipassCB` exists**, which is the 1.7 route for generation passes that need
  neighbour context (structures/villages spanning blocks, Phase D/E). Note it at brick 089–090.
- **Modifiers are SDF-only**, so they are irrelevant to a `VoxelMesherBlocky` world.
  Blocky edits go through `VoxelToolTerrain`.
- `VoxelBlockyType` / `VoxelBlockyTypeLibrary` offer an attribute/state-based model layer above
  raw `VoxelBlockyLibrary`. **Decided (brick 037):** plain `VoxelBlockyLibrary` +
  `VoxelBlockyModelCube`, built by `world/terrain/blocky_library_builder.gd`. `BlockDefinition`
  (031–036) has no attribute/state axis — no rotation, no connected-state, no on/off — so nothing
  needs the `Type` system's variant machinery yet, and CLAUDE.md §1 itself only names "blocky
  voxel library/models" generically. Revisit if a later block kind genuinely needs per-voxel
  state (e.g. rotation-aware stairs, connected fences) — that would need a new ADR, since it
  changes how `BlockDefinition` maps to a library model.

## 5. Not verified here

Worker-thread behavior, meshing throughput and streaming budgets are measured later
(bricks 051–055), not asserted by this probe.

## 6. `VoxelTerrain` baseline (brick 039)

`world/terrain/voxel_terrain_builder.gd` (`VoxelTerrainBuilder.build(registry)`) is the
first code that instantiates a `VoxelTerrain` node. Its scope is deliberately one node's
worth of the four still-open `VoxelNode`/`VoxelTerrain` properties this phase splits
across bricks 039–042:

| Property | Owner | This brick's setting |
|---|---|---|
| `generator` | 039 | a placeholder (below) |
| `stream` | 048 (persistence) | explicit `null` |
| `generate_collisions` | 039 | `true` |
| `mesher` | 040 (`BlockyLibraryBuilder`'s output) | left unset |
| `material_override` | 041 | left unset |
| `VoxelViewer` / `max_view_distance` | 042 | not touched |
| `bounds` | undecided — no world-size decision exists yet | left at the engine default |

**The generator is a temporary placeholder, not world generation.** Phase D
(056–067, `docs/reference/matrix-world.md`) owns the real deterministic
noise/height/climate generator; until it lands, `VoxelTerrainBuilder` fills a flat plane
of one registered block (`block.stone`) with `VoxelGeneratorFlat` (`channel =
VoxelBuffer.CHANNEL_TYPE`, `voxel_type = registry.network_index(id) + 1` — the same +1
offset `blocky_library_builder.gd` (037) uses for air at index 0). Phase D replaces
`terrain.generator` outright; it is not expected to reuse or extend this file.

**`stream` stays `null` on purpose.** `VoxelNode.stream`'s own doc: "Primary source of
persistent voxel data. If left unassigned, the whole volume will use the generator."
That is exactly what a build with no save format yet (048) needs — every block is
regenerated from the placeholder, nothing is expected to persist between runs.
