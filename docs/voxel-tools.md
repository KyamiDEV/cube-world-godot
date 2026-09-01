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
| `stream` | 048 (persistence) | optional builder parameter, `null` default (§13) |
| `generate_collisions` | 039 | `true` |
| `mesher` | 040 | a `VoxelMesherBlocky` (below) |
| `material_override` | 041 | explicit `null` (§8) |
| `max_view_distance` | 042 | `DEFAULT_VIEW_DISTANCE` = 128 (§9) |
| `bounds` | 050 (world bounds/authority policy) | `WorldBounds.aabb()` (§15) — read directly by `block_edit_validator.gd` (045, §11) for layer-2 bounds checking |
| `mesh_block_size` | 052 (surface) / 054 (decision) | optional builder parameter, `DEFAULT_MESH_BLOCK_SIZE` = 16 (§17–§19, ADR 0002) |

**The generator is a temporary placeholder, not world generation.** Phase D
(056–067, `docs/reference/matrix-world.md`) owns the real deterministic
noise/height/climate generator; until it lands, `VoxelTerrainBuilder` fills a flat plane
of one registered block (`block.stone`) with `VoxelGeneratorFlat` (`channel =
VoxelBuffer.CHANNEL_TYPE`, `voxel_type = registry.network_index(id) + 1` — the same +1
offset `blocky_library_builder.gd` (037) uses for air at index 0). Phase D replaces
`terrain.generator` outright; it is not expected to reuse or extend this file.

**`stream` stayed `null` through 039-047, and still defaults to `null`.** `VoxelNode.
stream`'s own doc: "Primary source of persistent voxel data. If left unassigned, the
whole volume will use the generator." `build()` now takes `stream` as an optional
parameter (048, §13) so a caller with a real database can wire one in without every
existing test/call site changing.

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

## 12. Block edit application layer (brick 046)

`world/terrain/block_edit_applicator.gd` (`BlockEditApplicator.apply(command, terrain,
registry) -> bool`) is the last stage of the edit pipeline: it assumes
`command.validate()` (044) and `BlockEditValidator.validate()` (045) already both
returned `ACCEPT`, the same "layer already checked it" trust 045 places in 044. It
performs no gameplay re-check (occupied/air/destructible) — that would duplicate 045
for no benefit, since nothing about voxel content changes between validating a command
and applying it within the same call.

Writes via `VoxelTool.set_voxel(position, raw_value)`: `registry.network_index(block_id)
+ 1` for `PLACE`, `0` (air) for `REMOVE` — the exact inverse of the `- 1` offset
`block_raycast_service.gd` (043) and `block_edit_validator.gd` (045) apply when reading a
voxel back into a block id. `set_voxel()` needed no confirmed-by-doc caveat the way
043's `raycast()` did — it is a direct single-voxel write, not a shape/SDF paint
operation, so no `do_point`/commit step applies.

Keeps the same defensive `Log.check` shape 043/045 already use, rather than blindly
trusting the caller: registry locked, terrain produces a `VoxelTool`, and — for `PLACE`
only — `block_id` is actually registered. That last check exists because
`DefinitionRegistry.network_index()` returns `-1` for an unknown id, which this file's
own `+1` offset would silently turn into `0` (air) instead of failing loudly — a
caller that skips 045 would otherwise get silent data corruption (writing air instead of
the intended block) rather than a clear rejection. All three are programmer/data errors,
never a normal gameplay outcome, so they are logged — no `CommandGate`-style
rejection-counting was needed here either, same reasoning as 045.

## 13. Initial voxel save stream wiring (brick 048)

`world/persistence/voxel_stream_builder.gd` (`VoxelStreamBuilder.build(database_path:
String) -> VoxelStreamSQLite`) is the first code that constructs a `VoxelStream`.
`CLAUDE.md` §1 already named `VoxelStreamSQLite` as the target; `docs/voxel-tools.md`
§4 confirmed it is present in this build. Scope is deliberately just the stream object,
not *where* its database lives — `docs/persistence.md`'s own header note already
reserves that storage-layout question for bricks 102-103 ("World streaming &
persistence"). `voxel_terrain_builder.gd`'s `build()` (039) gained a matching optional
`stream: VoxelStream = null` parameter so a caller can wire one in; every existing call
site keeps building a save-less terrain unchanged.

Three properties were set deliberately, each confirmed against
`doc/classes/VoxelStreamSQLite.xml` / `VoxelStream.xml` fetched this brick from the
`godot_voxel` reference repo (CLAUDE.md §15 source, tag `v1.7` — note: the GitHub tag is
`v1.7`, not `v1.7.0`; `docs/environment.md`'s own version string is unaffected, this is
only the git tag name):

1. **`save_generator_output = false`** (matches the engine default, named explicitly
   anyway — same "explicit is a real decision" reasoning 041/042 used). `VoxelStream`'s
   own doc: when `true`, "if a block cannot be found in the stream and it gets
   generated, then the generated block will immediately be saved into the stream" — the
   opposite of what `docs/persistence.md` §5 requires ("World modifications: stored as
   **deltas**... only what a player changed differs from the generator's output"). `true`
   would duplicate gigabytes of terrain the generator can already reproduce from
   `(seed, coords, generation version)`.
2. **`set_key_cache_enabled(true)`**. `VoxelStreamSQLite`'s own doc: key caching "speed[s]
   up loading queries in terrains that only save sparse edited blocks" — exactly the
   shape `save_generator_output = false` produces. Its doc also requires this be called
   before the stream is used to load, so `build()` calls it immediately after
   construction, before the stream is ever handed to a terrain.
3. **`preferred_coordinate_format = COORDINATE_FORMAT_STRING_CSD`** (value `2`, the
   engine's own default, named explicitly). Of the four formats, this is the only one
   with no fixed voxel-coordinate range — the three integer-packed formats cap the
   coordinate range (16/19/25 bits per axis). World bounds are not decided yet (`bounds`
   is brick 050's job, §6 above); choosing a fixed-width format now would risk silently
   capping the world before that decision is made. Only affects a *new* database — the
   property's own doc says the choice is ignored when opening an existing one, so this
   can be revisited later without a migration if bounds turn out to fit a smaller format.

`database_path` is taken as a plain caller-supplied `String`, not defaulted or derived
from any save-directory convention — no such convention exists yet (`nextsteps.md`'s
"Known risks"/"Next actions" carry no save-directory decision either). `build()` returns
null (logged, `Log.CH_PERSIST` — the channel `autoload/log.gd` already reserves for
persistence, distinct from `Log.CH_VOXEL`) only for an empty path; every other field is
Voxel Tools' own responsibility (e.g. a non-existent parent directory) and is not
re-validated here.

Tests: `tests/unit/test_voxel_stream_builder.gd` (3 tests) — empty-path rejection, a
built stream's three properties match the decisions above, and two independent `build()`
calls produce independent stream objects (not a shared singleton). `tests/unit/
test_voxel_terrain_builder.gd` gained one test — a stream passed to `build()` is wired
onto `terrain.stream` unchanged — alongside its existing null-by-default assertion,
whose comment was updated from "no save format yet" (no longer true) to "defaults to
null when the caller passes none".

## 14. Voxel load/save integration test (brick 049)

`tests/integration/test_voxel_load_save.gd` (1 test) — the first file under
`tests/integration/`, closing the loop 048 opened: does an edit written through a real
`VoxelStreamSQLite` actually survive a terrain teardown/rebuild, and does an untouched
voxel correctly keep coming from the placeholder generator rather than a stale/duplicated
stream entry (`save_generator_output = false`, §13)? Neither question is answerable by a
unit test of `VoxelStreamBuilder`, `VoxelTerrainBuilder`, or `BlockEditApplicator` in
isolation — each only exercises its own piece.

Two engine APIs are used here for the first time and needed doc confirmation (fetched
`doc/classes/VoxelTerrain.xml`, `VoxelSaveCompletionTracker.xml`, `VoxelStreamSQLite.xml`,
`godot_voxel` reference repo, CLAUDE.md §15 source, tag `v1.7`):

1. **`VoxelTerrain.save_modified_blocks() -> VoxelSaveCompletionTracker`** — forces every
   modified block to be written to the terrain's stream. Its own doc is explicit that
   saving is asynchronous ("the save may complete only a short time after you call this
   method"), so the test polls the returned tracker's `is_complete()` per frame (same
   poll-don't-assume-frame-count shape `is_area_meshed()` already gets in
   043/045/046's tests) rather than assuming one frame is enough.
2. **No documented `close()`/flush on `VoxelStreamSQLite`** — its connection lifetime is
   tied to the resource's own lifetime (a `RefCounted`, `doc/classes/VoxelStreamSQLite.xml`
   states no separate close call). The test therefore frees the first terrain (and the
   stream it held the only reference to) explicitly — `terrain.free()`, not `track_node()`,
   which only frees after the whole test method returns, too late for a second stream to
   safely open the same database file within the same test — then waits two frames before
   opening the same path again.

Scope: one edit (`REMOVE` at the placeholder ground's top voxel), not a matrix of
PLACE/REMOVE/multiple-edits/concurrent-terrain scenarios — brick 049's own backlog wording
is "basic... integration test", and `nextsteps.md`'s own action item for this brick names
exactly this one round trip. A future brick that needs broader save-format coverage
(e.g. bricks 102-103's own storage-layout work) can extend this file rather than starting
a new one.

No scene (`.tscn`) added, no player/camera decision made — same "where do these nodes
live" deferral 039-048 all carry (`nextsteps.md`'s own next-actions list). The test builds
and tears down its own terrain/viewer pair entirely inside one method, same pattern
043/045/046's tests already use, just twice.

## 15. World bounds/authority policy (brick 050)

`world/terrain/world_bounds.gd` (`WorldBounds`, static `aabb() -> AABB` and
`contains(voxel_position: Vector3i) -> bool`) gives `VoxelTerrain.bounds` (left at the
engine's effectively-unbounded default since 039, §6) a real, deliberate value:
`+-524288` voxels (`+-262.144 km`) horizontally (X/Z), `+-2048` voxels (`+-1.024 km`)
vertically (Y). Both are round powers of two (`2^19`, `2^11`) — the same style
`DEFAULT_VIEW_DISTANCE`/`mesh_block_size` already use — chosen large enough to never be a
real near-term constraint and small enough to be a named policy rather than a copy of the
engine's own `AABB(-536870900, ..., 1073741800, ...)` (roughly `+-2^29`) default. This is a
clean-room policy decision, not a reverse-engineered one: `docs/reference/traceability.md`
§4 already confirmed no reference matrix cites 031-055, and the reference's own recovered
`Zone`/`WorldMap` classes (`matrix-world.md`) carry no recovered world-size constant to
draw on. `voxel_terrain_builder.gd` (039) now sets `terrain.bounds = WorldBounds.aabb()`
unconditionally — every existing caller gets the real extent, not an opt-in parameter,
since there is no reason a baseline terrain should ever be built without one.

**What `bounds` actually gates — confirmed against upstream `VoxelTerrain.xml`
(`godot_voxel` reference repo, CLAUDE.md §15 source, tag `v1.7`, fetched this brick):**
"If an infinite world generator is used, blocks will only generate within this region.
Everything outside will be left empty." That is a **generation clip**, not an edit-authority
gate — the doc says nothing about refusing `VoxelTool` writes outside `bounds`. The actual
edit-authority enforcement is, and remains, `block_edit_validator.gd`'s (045, §11)
`OUT_OF_BOUNDS` verdict, which reads this same live `terrain.bounds` property independently.
Setting a real `bounds` value therefore does two things at once with no code change to 045:
constrains what the placeholder (and later, Phase D's real) generator will ever fill in,
*and* gives the already-existing edit-authority check a real boundary to enforce instead of
the engine's practically-infinite one. This two-effects-from-one-property relationship is
the "authority" half of this brick's title — `docs/server-authority.md` §1's "the server
decides what happened" already covers *why* 045 enforces bounds server-side; this brick
only had to give that enforcement a real number to enforce.

**`VoxelTerrainMultiplayerSynchronizer` (`nextsteps.md`'s carried-forward technical
note) stays deferred to Phase K, evaluated not adopted here.** It replicates terrain block
*data* to clients — a presentation/streaming concern — not a decision-making authority
mechanism; nothing in 039-050 makes voxel edits any less server-authoritative without it
(the 043-046 raycast -> command -> layer-2-validate -> apply pipeline already is the
authority path, run in-process for single-player per `docs/server-authority.md` §5). Wiring
a live synchronizer needs a real multiplayer scene and peer set, neither of which exists
before Phase K (231-256); inventing one now would be exactly the "silently expanding scope"
`CLAUDE.md` §6 warns against.

Deliberately *not* revisited here: `voxel_stream_builder.gd`'s (048, §13)
`COORDINATE_FORMAT_STRING_CSD` choice. That format has no fixed coordinate-range cap; a
fixed-width format could now technically fit `WorldBounds`'s extent, but switching only
affects a *new* database (048's own doc note) and buys nothing this project needs yet —
left as a genuinely optional future revisit, not a follow-up this brick owes.

Tests: `tests/unit/test_world_bounds.gd` (new, 5 tests) — the AABB is exactly symmetric
around the origin on all three axes, the vertical extent is smaller than the horizontal
one, `contains()` accepts the origin and points exactly on each face (`AABB.has_point()` is
inclusive at both min and max — confirmed by reading the engine's own `has_point`
semantics, not assumed), `contains()` rejects one voxel past each face, and two `aabb()`
calls produce equal (not merely equivalent-shaped) values. `tests/unit/
test_voxel_terrain_builder.gd`'s existing `test_builds_a_configured_voxel_terrain` gained
one assertion (`terrain.bounds == WorldBounds.aabb()`), same shape as every prior
039-042/048 property addition to that same test. Full suite: `files=29 tests=297
assertions=10306 failed=0`.

## 16. Chunk metrics/profiling hooks (brick 051)

`world/terrain/voxel_terrain_metrics.gd` (`VoxelTerrainMetrics`) gives bricks 052-055
(mesh block size 16/32 benchmarks, choosing a size, documenting the performance budget) a
single shared place to read Voxel Tools' own debug counters, instead of each benchmark
brick inventing its own dictionary-key string literals — the same "one shared utility"
rule `CLAUDE.md` §1 gives `core/math/world_scale.gd`. No new measurement: both dictionaries
are the engine's own counters, read as-is via `terrain_snapshot(terrain: VoxelTerrain) ->
Dictionary` (wraps `VoxelTerrain.get_statistics()`), `engine_snapshot() -> Dictionary`
(wraps the `VoxelEngine` singleton's `get_stats()`), and `log_terrain_snapshot(terrain,
channel = Log.CH_VOXEL)` (one structured `Log.debug` line per sample — the actual "hook" a
benchmark or manual profiling session calls, instead of formatting the dictionary itself).
`terrain_snapshot()` returns `{}` and logs (not crashes) for a null `terrain`, the same
defensive-return shape every other `world/terrain/*.gd` static helper already uses.

**Doc/code discrepancy found and resolved this brick.** `doc/classes/VoxelTerrain.xml`
(`godot_voxel` reference repo, tag `v1.7`) documents `get_statistics()` as returning 9 keys,
including `time_process_update_responses` and `remaining_main_thread_blocks`. Reading the
actual C++ source instead — `terrain/fixed_lod/voxel_terrain.cpp`'s
`VoxelTerrain::_b_get_statistics()` — shows its body only ever sets 7 keys; those two are
documented but never written. Confirmed empirically too: this brick's own headless test
(`tests/unit/test_voxel_terrain_metrics.gd`) never observes them on a real, meshed
`VoxelTerrain`, and asserts the dictionary's size is exactly 7 to catch a future engine
change either way. `VoxelTerrainMetrics.KEY_*` constants list only the 7 real keys.
`VoxelEngine.get_stats()` has no such discrepancy — `engine/voxel_engine_gd.cpp`'s
`to_dict()` binding matches `doc/classes/VoxelEngine.xml` exactly (`thread_pools`, `tasks`,
`memory_pools`, confirmed against source too, not just the doc, given the terrain-side
mismatch just found). `VoxelEngine` itself is called directly by class name with no
`.new()`/`Engine.get_singleton()` lookup, per its own `brief_description`: "Singleton
holding common settings and handling voxel processing tasks in background threads" — the
same access pattern as `OS`/`Input`.

Not reverse-engineered: `docs/reference/traceability.md` §4 already confirmed no reference
matrix cites 031-055.

Tests: `tests/unit/test_voxel_terrain_metrics.gd` (new, 5 tests) — `terrain_snapshot(null)`
returns `{}`; a real, meshed terrain's snapshot has exactly the 7 real keys (not the 9
documented ones); `engine_snapshot()` has the 3 documented top-level keys;
`log_terrain_snapshot(null, ...)` emits no statistics line; `log_terrain_snapshot()` on a
real terrain emits exactly one `Log.debug` line carrying the statistics as its context
dict. Full suite: `files=30 tests=302 assertions=10328 failed=0`.

## 17. Mesh block size benchmark (brick 052)

`VoxelTerrainBuilder.build()` gained a third optional parameter, `mesh_block_size: int =
DEFAULT_MESH_BLOCK_SIZE` (16) — the last `VoxelTerrain` property Phase C had not yet given
an explicit value (039-051 all ran under the engine's own implicit default). Confirmed
against upstream `VoxelTerrain.xml` (`godot_voxel` reference repo, tag `v1.7`): only `16`
and `32` are supported ("Values other than 16 and 32 are not supported"); an out-of-range
value is rejected the same `Log.check` + null-return way an unlocked registry already is,
not clamped or passed through. `VALID_MESH_BLOCK_SIZES` names the two-value domain as a
constant rather than an inline literal check, same "named, not inline" style as
`DEFAULT_VIEW_DISTANCE`.

A new headless harness, `tools/benchmarks/benchmark_mesh_block_size.gd` +
`mesh_block_size_benchmark_runner.gd`, builds a terrain from the default block set
(`BlockSet.load_default()`) and the existing placeholder flat-stone generator, with one
`VoxelViewer` at `view_distance = 128` (matching `DEFAULT_VIEW_DISTANCE`, the project's own
existing baseline) — `mesh_block_size` is the only variable this harness changes between a
052 run (16) and a 053 run (32), so the two are comparable. It polls
`VoxelTerrainMetrics.engine_snapshot()` once per frame until `memory_pools.block_count`
stops changing and every `tasks` queue reads `0` for 30 consecutive frames, then prints the
final `terrain_snapshot()`/`engine_snapshot()` dictionaries and the elapsed wall-clock time.

**Two engine behaviors surfaced empirically this brick, neither documented upstream:**

1. **A `--script` entry file is compiled before project autoloads are registered as global
   identifiers.** The first version of the harness statically referenced
   `VoxelTerrainBuilder`/`BlockSet`/`VoxelTerrainMetrics` directly in the file passed to
   `--script`, and failed with `Compile Error: Identifier not found: Log` — cascading into
   every one of those classes' own files, since all three call the `Log` autoload
   internally. `tests/run_tests.gd` never hits this: it only statically references
   `TestCase` (which never touches `Log`) and reaches every `Log`-dependent test file
   through a runtime `load()` call instead, by which point autoloads are live. The fix,
   applied here, is the same indirection: `benchmark_mesh_block_size.gd` (the `--script`
   entry) has no static references to any `Log`-touching class and `load()`s
   `mesh_block_size_benchmark_runner.gd` (which does the real work) at runtime. Any future
   `tools/**/*.gd` entry script reusing `Log`-touching project code needs the same split.
2. **`VoxelTerrain.get_statistics()`'s `updated_blocks` (and `time_request_blocks_to_update`)
   read as "this specific tick", not a running total.** An early version of the harness
   polled `updated_blocks` for a stable plateau; it stayed `0` for an entire run that still
   grew `memory_pools.block_count` from `0` to hundreds and printed real final statistics —
   the actual update burst happened between two polls and was never sampled. Settle
   detection now watches `engine_snapshot()`'s `memory_pools.block_count` (monotonically
   non-decreasing while streaming is in flight) and `tasks` (every queue empty) instead —
   a direct "no more in-flight background work" signal `terrain_snapshot()` alone doesn't
   give.

**Measured (052, `mesh_block_size = 16`, `view_distance = 128`, three repeated runs on the
dev machine):** settles in 52 polled frames (30 of which are the stability window, so real
work completes by roughly frame 22) and 375.7-377.9 ms wall-clock; `memory_pools.block_count
= 324`, `voxel_used ~= 2.65 MB`; `dropped_block_loads = dropped_block_meshs = 0` (no dropped
work); every `tasks` queue and `thread_pools.general.tasks` reads `0` at settle. Brick 053
repeats this unchanged except `--block-size=32`; 054 compares the two brick's numbers to
choose a default; 055 writes the two into a formal performance-budget document.

Not reverse-engineered: `docs/reference/traceability.md` §4 already confirmed no reference
matrix cites 031-055.

Tests: `tests/unit/test_voxel_terrain_builder.gd` (+2 tests, now also covers 052) — an
invalid `mesh_block_size` (8, 64) is rejected; an explicit `32` is wired through unchanged;
the existing `test_builds_a_configured_voxel_terrain` gained one assertion (default is 16).
Full suite: `files=30 tests=304 assertions=10336 failed=0`.

## 18. Mesh block size 32 benchmark (brick 053)

A pure measurement brick: it re-runs the brick-052 harness
(`tools/benchmarks/benchmark_mesh_block_size.gd` +
`mesh_block_size_benchmark_runner.gd`) unchanged except `--block-size=32`, so 052's
size-16 numbers and 053's size-32 numbers are directly comparable. No production code
changed — `VoxelTerrainBuilder.build()`'s `mesh_block_size` parameter and its
`32`-is-wired-through / `8`/`64`-rejected tests already landed with 052. The default
harness `view_distance` is `128` (`DEFAULT_VIEW_DISTANCE`), default block set, placeholder
flat-stone generator, one `VoxelViewer` at the origin — identical to the 052 run.

**Measured (053, `mesh_block_size = 32`, `view_distance = 128`, three repeated runs on the
dev machine):** settles in 50-51 polled frames (30 of which are the fixed stability
window, so real work completes by roughly frame 20-21) and 341.4-352.6 ms wall-clock;
`memory_pools.block_count = 324`, `voxel_used = 2 654 208 B (~= 2.65 MB)`;
`dropped_block_loads = dropped_block_meshs = 0`; every `tasks` queue and
`thread_pools.general.tasks` reads `0` at settle. `RESULT=OK`, exit `0` on all three runs.

**Side-by-side with 052:**

| metric | size 16 (052) | size 32 (053) |
|---|---|---|
| settle frames | 52 | 50-51 |
| wall-clock (3 runs) | 375.7-377.9 ms | 341.4-352.6 ms |
| `memory_pools.block_count` | 324 | 324 |
| `memory_pools.voxel_used` | ~2.65 MB | ~2.65 MB |
| dropped loads / meshes | 0 / 0 | 0 / 0 |

`block_count` and `voxel_used` are byte-identical between the two sizes because those
counters track 16³ *data* blocks (voxel storage), which `mesh_block_size` does not affect
— it only changes mesh-chunk granularity. The one real difference this harness sees is
wall-clock: size 32 settles ~25-35 ms (roughly 7-9%) faster and one to two frames sooner
against this small flat-terrain workload, consistent with fewer, larger mesh chunks
meaning less per-chunk bookkeeping. This is a single synthetic benchmark, not a decision
— brick 054 weighs both bricks' numbers (plus the memory/latency trade-off of larger mesh
chunks under real generation and frequent edits) to choose the project default; 055
writes the chosen budget into a formal document.

Not reverse-engineered: `docs/reference/traceability.md` §4 already confirmed no reference
matrix cites 031-055.

Tests: none added — 052 already covers the `mesh_block_size` surface. Regression check
only: full suite `files=30 tests=304 assertions=10336 failed=0`.

## 19. Mesh block size decision (brick 054)

Given 052's (size 16) and 053's (size 32) numbers, this brick fixes the project default.
The full decision, alternatives and revisit conditions are **ADR 0002**; the summary:

- **Decision: `VoxelTerrainBuilder.DEFAULT_MESH_BLOCK_SIZE` stays `16`** — now a
  deliberate, measured choice rather than the inherited engine default. The constant
  value is unchanged; its meaning is not.
- **Why not 32**, despite it benchmarking ~7-9% (~25-35 ms) faster to cold-settle: that
  benchmark measured only initial streaming on flat, un-edited terrain. It never touched
  the per-edit re-mesh path, where size 32 is a 32³ = 32 768-cell mesh job against size
  16's 16³ = 4 096 — **8× the meshing work per block edit**, on the player-visible
  latency path, in a game built around frequent mining/building edits. The 32 saving is
  one-time and at startup; the 32 cost is per-edit and continuous.
- `build()` keeps its optional `mesh_block_size` parameter and still accepts an explicit
  `32`, so a future static-terrain or heavy-view-distance context can opt in per terrain
  without reopening the decision.
- Data-block memory is identical either way (`mesh_block_size` does not affect the fixed
  16³ data-block storage), so there is no memory dimension to this trade-off — only
  cold-start latency vs. per-edit latency.

Not reverse-engineered: `docs/reference/traceability.md` §4 already confirmed no reference
matrix cites 031-055.

Tests: `tests/unit/test_voxel_terrain_builder.gd` — `test_builds_a_configured_voxel_terrain`
gained one assertion (`DEFAULT_MESH_BLOCK_SIZE == 16` explicitly, so a silent change to
`32` fails a test citing ADR 0002). No production code behavior changed — only doc
comments and this decision record. Brick 055 writes these numbers into the formal voxel
performance budget.
