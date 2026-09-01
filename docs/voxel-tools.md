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
| `mesher` | 040 | a `VoxelMesherBlocky` (below) |
| `material_override` | 041 | explicit `null` (§8) |
| `max_view_distance` | 042 | `DEFAULT_VIEW_DISTANCE` = 128 (§9) |
| `bounds` | 050 (world bounds/authority policy) | left at the engine default; read directly by `block_edit_validator.gd` (045, §11) for layer-2 bounds checking in the meantime |

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

## 7. `VoxelMesherBlocky` baseline (brick 040)

`VoxelTerrainBuilder.build()` now also assigns `terrain.mesher`: a plain
`VoxelMesherBlocky` whose `library` is `BlockyLibraryBuilder.build(registry)` (037), the
same registry the placeholder generator reads. No new file was needed — the mesher is
one property and one three-line helper (`_build_mesher`) inside the existing terrain
builder, not a dedicated `VoxelMesherBuilder` class.

**Resolves `matrix-world.md` Q1** ("does our terrain material/shader need an equivalent
of `ChunkBuffer_sampleVoxelColorAO`, or is `VoxelMesherBlocky` baked-AO sufficient?").
Fetched `doc/source/blocky_terrain.md` from the `godot_voxel` reference repo (CLAUDE.md
§15 source) to check: `VoxelMesherBlocky` always bakes ambient occlusion into cube-edge
vertex colors; a model's material only has to set `vertex_color_use_as_albedo = true` to
display it — no custom shader is needed. `blocky_library_builder.gd` (037)'s per-block
`StandardMaterial3D` now sets that flag. Answer: **sufficient** — no equivalent needed
beyond that one material property. Recorded directly here rather than in a new
`world-terrain-material.md` file (`matrix-world.md`'s own "Resolved by" placeholder) —
the answer is a compact fact about the engine, not a design that needs its own document.
`matrix-world.md` §4 and `docs/reference/traceability.md` §3 are updated to point here.

## 8. Terrain material/shader baseline (brick 041)

Backlog brick 041 is titled "create terrain material/shader baseline". By the time it
started, 037/040 had already given every block kind its own `StandardMaterial3D` (a
per-block texture atlas, `vertex_color_use_as_albedo = true` for baked AO) set on the
`VoxelBlockyModel`, not the terrain. The open question (`nextsteps.md` action 1) was
whether `VoxelTerrain.material_override` still needs a terrain-wide value on top of that.

Fetched `doc/source/blocky_terrain.md` from the `godot_voxel` reference repo (CLAUDE.md
§15 source) to check. It documents an explicit override order:

> "there are several levels at which materials get applied, each one overriding the
> other: Materials present on meshes are the default (if you use meshes explicitly) -
> Materials specified on `VoxelBlockyModel` will override mesh materials - The material
> specified on `VoxelTerrain` will override all library materials"

So `VoxelTerrain.material_override`, if set, replaces *every* per-model material in the
mesher's library with one shared `Material` — it is a way to force one uniform look
(e.g. a single triplanar/shared shader) across an entire terrain, not a way to add to
what the per-block materials already do. Setting it here would silently discard the
per-block atlas texturing 037/040 already built and tested. Since nothing in this
project currently needs one material applied uniformly across every block kind, the
correct baseline is an **explicit `null`** — recorded as a real assignment in
`voxel_terrain_builder.gd` (`terrain.material_override = null`), not left merely unset,
so the decision reads as intentional to the next person editing this file. Revisit only
if a future brick needs a genuinely terrain-wide material behavior (e.g. weather/snow
overlay, Phase J).

Answer: **no terrain-level material is needed on top of the per-block atlas materials.**
Resolves the `nextsteps.md` "Next 10 actions" item 1 open question for 041.

## 9. `VoxelViewer`/interest baseline (brick 042)

`VoxelViewer` is a `Node3D`, not a `VoxelTerrain` property — confirmed by fetching
`doc/classes/VoxelViewer.xml` from the `godot_voxel` reference repo (CLAUDE.md §15
source): it extends `Node3D` and Voxel Tools streams data around whatever `VoxelViewer`s
exist in the scene tree, matched against each `VoxelNode`'s own `max_view_distance`
(`VoxelTerrain.xml`'s own doc on that property: "If a `VoxelViewer` requests more, it
will be clamped"). So this brick splits into two builders, not one:

- `world/terrain/voxel_terrain_builder.gd` (039–042) now also sets
  `terrain.max_view_distance = DEFAULT_VIEW_DISTANCE`, a new constant (`128`, matching
  both properties' own engine default — named explicitly so the "never silently clamped"
  pairing survives either default changing later, not left as two independently-defaulted
  `128` literals).
- `world/terrain/voxel_viewer_builder.gd` (new file, `VoxelViewerBuilder.build() ->
  VoxelViewer`) builds a `VoxelViewer` with `view_distance = DEFAULT_VIEW_DISTANCE`,
  `requires_visuals = true`, `requires_collisions = true` — a sandbox baseline needs both
  meshed terrain and collision around the viewer, so both are set explicitly even though
  they match the engine default, same "explicit, not merely unset" reasoning §8 used for
  `material_override`.

Neither builder adds the `VoxelViewer` to a scene tree or parents it under a camera —
no player/camera exists yet (Phase F: bricks 106–130). Where the node actually lives is
left open, same as `voxel_terrain_builder.gd`'s own still-open "where does this node live
in a scene" question (039's `nextsteps.md` entry, carried forward again here).
`enabled_in_editor` and `requires_data_block_notifications` are left at their engine
defaults (`false`) — no live-in-editor streaming workflow or block-notification consumer
exists yet to justify overriding either.

## 10. Block raycast interaction service (brick 043)

`world/terrain/block_raycast_service.gd` (`BlockRaycastService.cast(terrain, registry,
origin, direction, max_distance)`) is the first code to call `VoxelTool.raycast()`.
Voxel Tools' own result, `VoxelRaycastResult`, only carries a raw hit/previous voxel
position, a normal and a distance — no concept of `BlockRegistry` or the `+1` air offset
`blocky_library_builder.gd` (037) established for voxel values. `cast()` bridges the two:
it calls `terrain.get_voxel_tool().raycast(...)`, reads the hit voxel's raw value back
with `tool.get_voxel(result.position)`, subtracts the `+1` offset, and resolves the
result through `registry.id_from_network_index()` — returning a `BlockRaycastHit`
(`block_raycast_hit.gd`) with the resolved `block_id` plus the hit/placement positions,
normal and distance. Returns null (logged via `Log.check`) for an unlocked registry, a
zero direction, a terrain with no voxel tool, a plain miss, or a hit voxel value the
registry cannot resolve.

**Empirically confirmed** (no upstream doc page states this): `VoxelToolTerrain.raycast()`
only finds a hit once the terrain has actually meshed the area under the ray. Even against
the placeholder `VoxelGeneratorFlat` (039) with no stream and no async persistence
involved, this still needs the `VoxelTerrain` node added to the `SceneTree` with a
`VoxelViewer` nearby, and a handful of real frames for Voxel Tools' worker threads to
catch up — confirmed by direct experiment: `try_set_block_data()` does not work
synchronously either (fails while the terrain is outside the tree, and still returned
`false` several frames after being added), and `raycast()`/`get_voxel()` return
stale/empty data until the area is loaded regardless. `tests/unit/test_block_raycast_service.gd`
polls `VoxelTerrain.is_area_meshed()` per frame (up to a generous frame cap) rather than
waiting a fixed frame count, so the test does not flake if worker timing varies between
machines.

Like 039–042, `cast()` takes an explicit ray (`origin`/`direction`) rather than reading
one from a camera — no player/camera exists yet (Phase F, 106–130). `collision_mask` is
left at `VoxelTool.raycast()`'s own default (every bit set): a non-solid block's model
already gets `collision_mask = 0` from `blocky_library_builder.gd` (037), so it can never
match any mask and is already excluded from a hit — no extra filtering was needed for a
"basic" raycast. `DEFAULT_MAX_DISTANCE` (10.0 world/voxel units) matches
`VoxelTool.raycast()`'s own default, named explicitly as a placeholder — real player
reach balance is Phase F/G and may replace it outright.

## 11. Block edit gameplay validation (brick 045)

`world/terrain/block_edit_validator.gd` (`BlockEditValidator.validate(command, terrain,
registry) -> Verdict`) is layer 2 (gameplay) validation for `EditBlockCommand` (044),
per `docs/server-authority.md` §3 — layer 1 is `CommandGate` (019). It checks: registry
locked, terrain produces a `VoxelTool`, `command.position` inside `terrain.bounds`, then
per-kind — `PLACE` needs a registered `block_id` and an air target voxel; `REMOVE` needs
a non-air target voxel whose resolved `BlockDefinition.destructible` is true. Reuses
`block_raycast_service.gd` (043)'s `+1`/`-1` air-offset convention for reading the
target voxel's current value; no new offset logic.

**`bounds` confirmed by fetching `doc/classes/VoxelTerrain.xml` (v1.7 tag) this brick**:
`type="AABB"`, in voxel coordinates, default `AABB(-536870900, -536870900, -536870900,
1073741800, 1073741800, 1073741800)` — effectively unbounded. It belongs to
`VoxelTerrain` itself, not `VoxelNode` (confirmed against the same fetch of
`VoxelNode.xml` that found no `bounds` member there). §6's table above already left this
property "undecided" pending a real world-size policy (brick 050); this brick reads it
directly rather than inventing a second bounds mechanism, so 050's whole job is setting
this one property correctly — this validator does not change when 050 lands.

Returns a `Verdict` enum (`ACCEPT` plus one member per rejection reason), the same shape
as `CommandGate.Verdict` (019) rather than the string-reason convention `StableId`/
`BlockDefinition`/`EditBlockCommand.validate()` use — this is a command-authority
decision, like layer 1, not a data-shape self-check. Only the three
programmer/data-error verdicts (`INVALID_REGISTRY`, `INVALID_TERRAIN`,
`UNRESOLVABLE_VOXEL`) are logged (`Log.check`); the five ordinary gameplay rejections
are not, per `docs/server-authority.md` §4 ("rejection is normal") and
`docs/logging-and-errors.md`'s no-per-frame-spam rule — block edits can be frequent.
Stateless: no `CommandGate`-style rejection-counting was added, since there is no
per-peer state to key it on here; a server loop can count at its own call site later
without changing this file.
