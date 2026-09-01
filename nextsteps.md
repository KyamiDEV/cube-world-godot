# nextsteps.md — Master session handoff

> Compact durable state for Claude Code. Update after every brick.
> After update: commit when appropriate, then `/clear`.

## Current project state

- Project: CubeWorld-style Alpha 2013 reimplementation
- Engine: `4.7.2.stable.double.custom_build.ed1daf0bf` — VERIFIED (`docs/environment.md`)
- Voxel Tools: `1.7.0`, edition `Module` — VERIFIED (`docs/voxel-tools.md`)
- Voxel scale: `1 voxel = 0.5 m` — implemented in `core/math/world_scale.gd`
- Reference repo: `reference/CubeWorld-Reversal` (local, gitignored, `.gdignore`d) — **not read yet**
- Git: `main`, one commit per brick
- Godot AI MCP: failed to connect this session (`CONNECTION_CLOSED`); not needed so far

## Current phase / milestone / task

- Phase `B — Architecture & reference extraction` — **COMPLETE** (011–030)
- Phase `C — Voxel infrastructure` — in progress (031–052)
- Milestone `M002 — Voxel sandbox` (M001 bootstrap COMPLETE)
- Next task `053 — Benchmark mesh block size 32`

## Completed bricks

`001`–`052`. Phase A complete; Phase B complete (011–020 contracts; 021–028 reference
tree mapping, all 8 matrices; 029 confidence/uncertainty convention; 030 traceability
index); Phase C in progress (031 block definition schema, 032 block registry, 033
material property schema, 034 collision property schema, 035 interaction/destruction
property schema, 036 footstep/surface tag, 037 `VoxelBlockyLibrary` bootstrap, 038 first
grass/dirt/stone block set, 039 `VoxelTerrain` baseline, 040 `VoxelMesherBlocky`
baseline, 041 terrain material/shader baseline, 042 `VoxelViewer`/interest baseline, 043
block raycast interaction service, 044 block edit command model, 045 block edit
validation layer, 046 block edit application layer, 047 edit undo/delta representation,
048 initial voxel save stream wiring, 049 voxel load/save integration test, 050 voxel
world bounds/authority policy, 051 voxel chunk metrics/profiling hooks, 052 mesh block
size 16 benchmark).

`052` gave `VoxelTerrainBuilder.build()` a third optional parameter,
`mesh_block_size: int = DEFAULT_MESH_BLOCK_SIZE` (16, `VoxelTerrain`'s own engine
default) — the last `VoxelTerrain` property Phase C had left implicit since 039.
Confirmed against upstream `VoxelTerrain.xml` (`godot_voxel` reference repo, tag `v1.7`):
only `16`/`32` are valid; an out-of-range value is rejected via `Log.check` + null return,
same pattern as an unlocked registry.

Added a new headless benchmark harness, split into two files on purpose:
`tools/benchmarks/benchmark_mesh_block_size.gd` (the `--script` entry, no static
references to any `Log`-touching project class) and
`mesh_block_size_benchmark_runner.gd` (the actual measurement logic, `load()`ed at
runtime). The split exists because of a genuine, empirically-confirmed engine behavior
this brick surfaced: **a file passed to `--script` is compiled before project autoloads
are registered as global identifiers**, so a script that statically references a
`Log`-touching class (`VoxelTerrainBuilder`, `BlockSet`, `VoxelTerrainMetrics` all call
`Log` internally) at the top level fails to compile with `Identifier not found: Log`,
cascading into every one of those classes. `tests/run_tests.gd` never hits this because it
only statically references `TestCase` (no `Log` dependency) and reaches every real,
`Log`-dependent test file through a runtime `load()` call instead. Any future
`tools/**/*.gd` script that wants to call `Log`-touching project code needs the same
entry/runner split — recorded in both files' own header comments and
`docs/voxel-tools.md` §17, not just here.

A second finding changed how the harness detects "done": `VoxelTerrain.get_statistics()`'s
`updated_blocks` reads as "blocks updated on this specific tick", not a running total — an
early version polled it for a stable plateau and reported "settled" while it sat at a
constant `0` for an entire run that still grew `memory_pools.block_count` from `0` to
hundreds and printed real final statistics; the actual update burst happened between two
polls and was never sampled. Settle detection now watches
`VoxelTerrainMetrics.engine_snapshot()`'s `memory_pools.block_count` (monotonically
non-decreasing while streaming is in flight) plus every `tasks` queue reading `0`, for 30
consecutive frames — a direct "no more in-flight background work" signal.

**Measured** (`mesh_block_size = 16`, `view_distance = 128` matching
`VoxelTerrainBuilder.DEFAULT_VIEW_DISTANCE`, default block set, placeholder flat-stone
generator, three repeated runs on the dev machine): settles in 52 polled frames (30 of
which are the fixed stability window, so real work completes by roughly frame 22) and
375.7-377.9 ms wall-clock; `memory_pools.block_count = 324`, `voxel_used ~= 2.65 MB`;
`dropped_block_loads = dropped_block_meshs = 0`. Brick 053 repeats this unchanged except
`--block-size=32`; 054 compares both bricks' numbers to choose a default; 055 writes both
into a formal performance-budget document — none of that comparison/choice/documentation
work is done by 052 itself.

`docs/reference/traceability.md` §4 already confirmed no reference matrix cites 031-055,
so no reference read was needed. Full reasoning in `docs/voxel-tools.md` §17 (new
section).

Tests: `tests/unit/test_voxel_terrain_builder.gd` (+2 tests, now also covers 052) — an
invalid `mesh_block_size` (8, 64) is rejected; an explicit `32` is wired through
unchanged; the existing `test_builds_a_configured_voxel_terrain` gained one assertion
(default is 16). Full suite: `files=30 tests=304 assertions=10336 failed=0`.

`051` added `world/terrain/voxel_terrain_metrics.gd` (`VoxelTerrainMetrics`) — named,
typed access to Voxel Tools' own debug-statistics dictionaries, so bricks 052-055 (mesh
block size 16/32 benchmarks, choosing a size, documenting the performance budget) read
them through shared constants, not scattered string literals (`CLAUDE.md` §1's "one
shared utility" rule). Three static entry points: `terrain_snapshot(terrain) ->
Dictionary` (wraps `VoxelTerrain.get_statistics()`, `{}` + logged reason for a null
terrain), `engine_snapshot() -> Dictionary` (wraps the `VoxelEngine` singleton's
`get_stats()`), `log_terrain_snapshot(terrain, channel = Log.CH_VOXEL)` (one structured
`Log.debug` line per sample — the actual profiling hook a benchmark calls).

Found and resolved a doc/code discrepancy along the way: `doc/classes/VoxelTerrain.xml`
(`godot_voxel` reference repo, tag `v1.7`) documents 9 keys for `get_statistics()`, but
the actual C++ source (`terrain/fixed_lod/voxel_terrain.cpp`'s `_b_get_statistics()`)
only ever sets 7 — `time_process_update_responses` and `remaining_main_thread_blocks` are
documented but never written. Confirmed both by reading the source and empirically (a
real, meshed terrain's snapshot in this build never has either key). `KEY_*` constants
list only the 7 real keys; the test asserts the dictionary size is exactly 7 to catch a
future engine change. `VoxelEngine.get_stats()` has no such mismatch (checked against its
own binding source too). Full reasoning in `docs/voxel-tools.md` §16 (new section).

Not reverse-engineered: `docs/reference/traceability.md` §4 already confirmed no
reference matrix cites 031-055.

Tests: `tests/unit/test_voxel_terrain_metrics.gd` (new, 5 tests). Full suite:
`files=30 tests=302 assertions=10328 failed=0`.

`050` added `world/terrain/world_bounds.gd` (`WorldBounds`, static `aabb() -> AABB` and
`contains(voxel_position: Vector3i) -> bool`) — the first real value for `VoxelTerrain.
bounds`, left at the engine's effectively-unbounded default since 039. A clean-room policy
decision, not reverse-engineered (`traceability.md` §4 confirms no reference matrix cites
031–055, and the reference's own `Zone`/`WorldMap` classes carry no recovered world-size
constant): `+-524288` voxels (`+-262.144 km`) horizontally (X/Z), `+-2048` voxels
(`+-1.024 km`) vertically (Y) — round powers of two (`2^19`, `2^11`), same style
`DEFAULT_VIEW_DISTANCE`/`mesh_block_size` already use. `voxel_terrain_builder.gd` (039)
now sets `terrain.bounds = WorldBounds.aabb()` unconditionally in `build()`.

Confirmed against upstream `VoxelTerrain.xml` (`godot_voxel` reference repo, tag `v1.7`,
fetched this brick): `bounds` only clips what an infinite generator fills in ("blocks will
only generate within this region... everything outside will be left empty") — it is not
documented as an edit-authority gate. The real edit-authority enforcement remains
`block_edit_validator.gd`'s (045) `OUT_OF_BOUNDS` verdict, which already reads this same
live `terrain.bounds` property independently — giving `bounds` a real value fixes both the
generator's clip and the edit-authority boundary at once, with zero code change to 045.
Full reasoning (including why `VoxelTerrainMultiplayerSynchronizer` stays deferred to
Phase K rather than adopted here) in `docs/voxel-tools.md` §15 (new section).

Tests: `tests/unit/test_world_bounds.gd` (new, 5 tests) — symmetric AABB, vertical extent
smaller than horizontal, `contains()` accepts the origin and exact face points
(`AABB.has_point()` is inclusive at both min and max), rejects one voxel past each face,
two `aabb()` calls agree. `tests/unit/test_voxel_terrain_builder.gd` (+1 assertion):
`terrain.bounds == WorldBounds.aabb()`. Full suite: `files=29 tests=297 assertions=10306
failed=0`.

`049` added `tests/integration/test_voxel_load_save.gd` (1 test) — the first file under
`tests/integration/`, closing the loop 048 opened by actually proving an edit survives a
real save/reload round trip rather than only that `VoxelStreamBuilder`/
`VoxelTerrainBuilder`'s `stream` parameter are wired correctly in isolation. Flow: build a
terrain against a real on-disk `VoxelStreamSQLite`, apply one `REMOVE` edit via
`BlockEditApplicator.apply()` (046), force-save via the newly-used
`VoxelTerrain.save_modified_blocks() -> VoxelSaveCompletionTracker` and poll
`is_complete()` (saving is asynchronous per the engine's own doc), fully free the terrain
and its stream (not via `track_node()`, which only frees after the test method returns —
too late for a second stream to safely reopen the same database path within the same
test), then rebuild a fresh terrain against the same database path. Two assertions:
the edited voxel is still air (the delta survived), and an untouched ground voxel
elsewhere still comes from the placeholder generator, not a stale/duplicated stream entry
— the concrete proof that `save_generator_output = false` (048) actually behaves as
documented, not just that the property reads back correctly.

No new engine API beyond what 043/046 already established, except `save_modified_blocks()`
and `VoxelSaveCompletionTracker` (`is_complete()`) — both confirmed against
`doc/classes/VoxelTerrain.xml`/`VoxelSaveCompletionTracker.xml` fetched from the
`godot_voxel` reference repo (CLAUDE.md §15 source, tag `v1.7`) this brick, alongside a
re-check of `VoxelStreamSQLite.xml` confirming no documented `close()`/flush call exists —
its connection lifetime is tied to the `RefCounted` resource's own lifetime, which is why
the test frees the first terrain explicitly rather than relying on test-runner teardown.
Full reasoning in `docs/voxel-tools.md` §14 (new section); `docs/persistence.md`'s header
gained one pointer sentence, same "pointer, not a new contract" pattern prior bricks used.

Scope is deliberately one edit (`REMOVE`), not a PLACE/REMOVE/multi-edit/concurrent-terrain
matrix — the backlog's own wording is "basic... integration test", and this closes exactly
the one open question `nextsteps.md`'s prior "Next 10 actions" item 1 named. No `.tscn`,
no player/camera decision — same deferral 039–048 all carry forward (still open below).

Tests: `tests/integration/test_voxel_load_save.gd` (1 test, +1 total). Full suite:
`files=28 tests=292 assertions=10289 failed=0`.

`048` added `world/persistence/voxel_stream_builder.gd` (`VoxelStreamBuilder`, static
`build(database_path: String) -> VoxelStreamSQLite`) — the first code that constructs a
`VoxelStream`, closing the "`stream` left null" note 039–047 all carried. Scope is
deliberately just the stream object itself, not where its database lives on disk —
`docs/persistence.md`'s own header already reserved that storage-layout question for
bricks 102–103, so this brick doesn't invent a save-directory convention.
`voxel_terrain_builder.gd`'s `build()` (039) gained a matching optional `stream:
VoxelStream = null` parameter; every existing call site (all in tests — no scene wires a
terrain yet) keeps building a save-less terrain unchanged.

Three deliberate property decisions, each confirmed against `doc/classes/
VoxelStreamSQLite.xml`/`VoxelStream.xml` fetched from the `godot_voxel` reference repo
(CLAUDE.md §15 source — note the GitHub tag is `v1.7`, not `v1.7.0`; unrelated to
`docs/environment.md`'s own verified version string): `save_generator_output = false`
(matches the engine default, named explicitly per 041/042's "explicit is a decision"
precedent) — `docs/persistence.md` §5 requires deltas only, and `true` would instead
save every generated block, duplicating terrain the generator can already reproduce;
`set_key_cache_enabled(true)`, called immediately at construction per the property's own
"must be called before load" doc note — key caching speeds up exactly the sparse
edited-block save shape `save_generator_output = false` produces;
`preferred_coordinate_format = COORDINATE_FORMAT_STRING_CSD` (value 2, the engine
default, named explicitly) — the one format with no fixed coordinate-range cap, correct
until world bounds are decided (brick 050), and only affects a new database so it can be
revisited later without a migration.

`build()` rejects only an empty `database_path` (`Log.check`, `Log.CH_PERSIST` — the
channel `autoload/log.gd` already reserves for persistence, distinct from
`Log.CH_VOXEL`); every other failure mode (bad parent directory, etc.) is Voxel Tools'
own responsibility and isn't re-validated here. Full reasoning in `docs/voxel-tools.md`
§13 (new section); `docs/persistence.md`'s header gained one pointer sentence, same
"pointer, not a new contract" pattern 047 used for `block_edit_delta.gd`.

Tests: `tests/unit/test_voxel_stream_builder.gd` (new, 3 tests) — empty-path rejection,
a built stream's three properties match the decisions above, two independent `build()`
calls produce independent stream objects. `tests/unit/test_voxel_terrain_builder.gd`
(+1 test, now also covers 048): a passed-in stream is wired onto `terrain.stream`
unchanged; its existing null-by-default assertion's comment was updated ("no save format
yet" was no longer accurate — the format now exists, the default is just still `null`).
Full suite: `files=27 tests=291 assertions=10284 failed=0`.

`047` added `world/terrain/block_edit_delta.gd` (`BlockEditDelta`) — the per-voxel delta
unit `docs/persistence.md` §5 names ("world modifications... stored as deltas") but had
not yet given a concrete shape, and the unit an undo replays. Carries `position`,
`previous_block_id`/`new_block_id` (`""` = air, the same convention 044/046 already use),
and `tick`. Two behaviors beyond plain data: `is_noop()` (both sides name the same
content), and `inverse_command(p_tick) -> EditBlockCommand` — restoring air means
`REMOVE`, restoring a named block means `PLACE`, so an undo replays through the exact
same `BlockEditApplicator.apply()` (046) that performed the original edit, no second
voxel-writing code path. `face_normal` on an inverse command is `Vector3.ZERO` — nothing
was struck, and no 043–045 check reads it today. `inverse_command()`'s own `p_tick` is
always the undo's tick, never the delta's own — an undo is issued now, not backdated.

`world/terrain/block_edit_applicator.gd` (046) gained one new static method,
`apply_capturing_delta(command, terrain, registry) -> BlockEditDelta`: reads the target
voxel's pre-edit content (the one thing `apply()` itself cannot report back, since
`set_voxel()` overwrites it) via the same `id_from_network_index(raw - 1)` pattern
045/043 already use, then delegates the actual write to `apply()` — so the two entry
points can never disagree about what a `PLACE`/`REMOVE` does. Returns null on the same
rejections `apply()` already logs (unlocked registry, no voxel tool, unregistered
`block_id`); adds no `Log.check` calls of its own, since every failure path was already
logged one layer down. `apply()` itself is unchanged — every 046 test still passes
unmodified, and 047 only adds a second entry point beside it.

Scope note: this brick builds the *representation* and its one-step inverse, not a
multi-step undo stack/history service — no backlog brick asks for one, and CLAUDE.md §6
("avoid silently expanding scope") argues against inventing one speculatively. A future
undo-stack brick, if ever added, would hold a list of `BlockEditDelta` and pop+apply
inverses; nothing here needs to change to support that.

`docs/reference/traceability.md` §4 already confirmed no reference matrix cites
031–055, so no reference read was needed, same as 031–046. `docs/persistence.md`'s
header gained one pointer sentence to `block_edit_delta.gd` as §5's concrete delta unit
— not a new contract, so no new section.

Tests: `tests/unit/test_block_edit_delta.gd` (new, 5 tests) — `is_noop()` true/false,
`inverse_command()` shape for both directions (kind, position, block_id, tick), and both
inverse commands passing their own `validate()`. `tests/unit/test_block_edit_applicator.gd`
(+7 tests, now also covers 047): `apply_capturing_delta()` reports air-before-a-place and
the removed block on a remove, returns null on the same unlocked-registry and
unregistered-block rejections `apply()` itself returns false for (voxel left untouched),
and two full round-trip tests — capture a delta, apply its `inverse_command()`, confirm
the voxel is back to exactly its pre-edit raw value. Full suite: `files=26 tests=287
assertions=10265 failed=0`.

`046` added `world/terrain/block_edit_applicator.gd` (`BlockEditApplicator`, static
`apply(command: EditBlockCommand, terrain: VoxelTerrain, registry: BlockRegistry) ->
bool`) — the last stage of the edit pipeline, applying an already-validated command
(044 structural + 045 gameplay, both assumed `ACCEPT`) to real voxel data via
`VoxelTool.set_voxel()`. Writes `registry.network_index(block_id) + 1` for `PLACE`, `0`
for `REMOVE` — the exact inverse of the `- 1` offset 043/045 apply when reading a voxel
back into a block id. Performs no gameplay re-check (occupied/air/destructible) — that
would duplicate 045 for no benefit — but keeps the same defensive `Log.check` shape
043/045 use: registry locked, terrain produces a `VoxelTool`, and (`PLACE` only)
`block_id` is actually registered. That last check matters because
`DefinitionRegistry.network_index()` returns `-1` for an unknown id, which the `+1`
offset would otherwise silently turn into `0` (air) — a caller that skipped 045 would
get silent data corruption instead of a clear rejection. All three are programmer/data
errors, not normal gameplay outcomes, so all three are logged; no rejection-counting
was added, same reasoning as 045 (stateless, no per-peer state to key on here).

`set_voxel()` needed no doc-verification caveat the way 043's `raycast()` did (§10) — it
is a direct single-voxel write, not a shape/SDF paint operation, so there is no
`do_point`/commit step to account for. `docs/voxel-tools.md` §12 (new section) records
the full reasoning; `docs/reference/traceability.md` §4 already confirmed no reference
matrix cites 031–055, so no reference read was needed, same as 031–045.

Tests: `tests/unit/test_block_edit_applicator.gd` (4 tests, +4 total) — same
built-vs-meshed terrain split 043/045 use: `INVALID_REGISTRY` against a built-but-unmeshed
terrain, and three voxel-content checks against a fully meshed terrain (`PLACE` writes
`network_index + 1`, `REMOVE` writes `0`, an unregistered `block_id` is rejected and
leaves the target voxel untouched). No `INVALID_TERRAIN` test — 043/045's own test files
never construct that case either, same precedent.

`045` added `world/terrain/block_edit_validator.gd` (`BlockEditValidator`, static
`validate(command: EditBlockCommand, terrain: VoxelTerrain, registry: BlockRegistry) ->
Verdict`) — layer 2 (gameplay) validation for `EditBlockCommand` (044) per
`docs/server-authority.md` §3, the counterpart to layer 1 (`CommandGate`, 019). Assumes
`command.validate()` (044, structural only) already passed, the same way `CommandGate`
assumes a well-formed envelope; this layer only checks what that pass cannot: registry
membership and actual voxel content. Returns a `Verdict` enum (`ACCEPT`,
`INVALID_REGISTRY`, `INVALID_TERRAIN`, `OUT_OF_BOUNDS`, `UNKNOWN_BLOCK`,
`UNRESOLVABLE_VOXEL`, `TARGET_OCCUPIED`, `TARGET_IS_AIR`, `NOT_DESTRUCTIBLE`), mirroring
`CommandGate.Verdict`'s shape rather than the string-reason convention `StableId`/
`BlockDefinition`/`EditBlockCommand.validate()` use — this is a command-authority
decision (layer 2), not a data-shape self-check, so it follows the sibling layer's
pattern instead.

Checks, in order: registry locked (`INVALID_REGISTRY`) -> terrain produces a
`VoxelTool` (`INVALID_TERRAIN`) -> `command.position` inside `terrain.bounds`
(`OUT_OF_BOUNDS`) -> per-kind. `PLACE`: `block_id` is actually registered
(`UNKNOWN_BLOCK`, distinct from 044's grammar/domain-only check), target voxel is air
(`TARGET_OCCUPIED` otherwise). `REMOVE`: target voxel is not air (`TARGET_IS_AIR`
otherwise), its resolved id exists in the registry (`UNRESOLVABLE_VOXEL` otherwise —
data corruption or a terrain built from a different registry, same defensive case
`block_raycast_service.gd`, 043, already guards), its `BlockDefinition.destructible` is
true (`NOT_DESTRUCTIBLE` otherwise). Reuses the exact `+1`/`-1` air-offset convention
043 established (`tool.get_voxel(pos) - 1` -> `registry.id_from_network_index()`) —
no new offset logic.

Bounds decision: rather than invent a bounds concept ahead of brick 050 ("voxel world
bounds/authority policy"), this reads `VoxelTerrain.bounds` directly — a real property
that already exists on every terrain (confirmed via `doc/classes/VoxelTerrain.xml`,
`godot_voxel` v1.7 tag, fetched this brick: `type="AABB"`, in voxel coordinates,
currently left at the engine's own effectively-unbounded default per
`docs/voxel-tools.md` §6). 050 only ever needs to set `terrain.bounds` correctly; no
second bounds mechanism was added here. Also confirmed this brick: `VoxelNode` itself
(the `VoxelTerrain` base class) carries no `bounds` member — it is `VoxelTerrain`'s own
addition, not inherited, so a future non-`VoxelTerrain` `VoxelNode` subtype would need
its own equivalent decision.

Logging is deliberately asymmetric: `INVALID_REGISTRY`/`INVALID_TERRAIN`/
`UNRESOLVABLE_VOXEL` go through `Log.check()` (programmer/data errors), but the five
ordinary gameplay verdicts are *not* logged — `docs/server-authority.md` §4 ("rejection
is normal") plus `docs/logging-and-errors.md`'s no-per-frame-spam rule, since block
edits (mining swings, misclicks) can be frequent enough that per-rejection logging
would be exactly that spam. No stateful metrics/counters (`CommandGate`'s
`_rejections` dictionary) were added — this validator is a stateless per-command check
with no peer state to key metrics on, same "plain static utility" shape as
`block_raycast_service.gd` (043); a future server loop can add counting at its own call
site if needed, without changing this file.

Tests: `tests/unit/test_block_edit_validator.gd` (9 tests, +9 total) — split the same
way `test_block_raycast_service.gd` (043) splits its own: `INVALID_REGISTRY`/
`OUT_OF_BOUNDS`/`UNKNOWN_BLOCK` against a built-but-unmeshed terrain (added to the tree
so `get_voxel_tool()` is real, but no wait for meshing since these never read voxel
content), and the five voxel-content-dependent verdicts (`ACCEPT`/`TARGET_OCCUPIED`/
`ACCEPT`/`NOT_DESTRUCTIBLE`/`TARGET_IS_AIR`) against a fully meshed terrain via the same
poll-`is_area_meshed()` `_ready_terrain()` helper 043's test file uses, plus
`verdict_name()`. `docs/reference/traceability.md` §4 already confirmed no reference
matrix cites 031–055, so no reference read was needed for gameplay design, same as
031–044 (only the one `VoxelTerrain.xml` engine-doc fetch above, for `bounds`'s real
type).

`044` added `network/packets/edit_block_command.gd` (`EditBlockCommand`) — the
`docs/protocol.md` §2 worked example given a concrete shape. Carries only intent: `kind`
(`PLACE`/`REMOVE`), `position` (the voxel to write), `face_normal` (the struck face, for
gameplay validation in 045 that needs approach direction), `block_id` (required and
`StableId`-checked for `PLACE`, must be empty for `REMOVE`), and `tick`
(`MessageTaxonomy.requires_tick()`). Deliberately excludes peer/owner/sequence — per
`docs/server-authority.md` A4, ownership is resolved by `CommandGate` from the connection,
never carried in the payload. `from_hit(hit: BlockRaycastHit, kind, block_id, tick)`
picks `hit.placement_position` for `PLACE` and `hit.hit_position` for `REMOVE`
automatically, so no caller re-derives that distinction (043's hand-off note). `validate()`
is structural only (well-formed id, correct domain, empty/non-empty `block_id` matching
`kind`, non-negative tick) — whether the position is in-bounds or the block is placeable
is 045's job, against world state, not this type's. Tests:
`tests/unit/test_edit_block_command.gd` (10 tests, +263 total).

One non-obvious parser interaction surfaced and is worth keeping: `check_scripts.gd`'s
self-check (renames a copy's `class_name` to `X__selfcheck` to parse it without
conflicting with the already-registered real class) makes a **bare** nested-type
reference (e.g. `Kind` used unqualified as a parameter type) resolve to the *local*
(renamed) copy, while a **fully-qualified** reference (`EditBlockCommand.Kind`, or the
class's own name written out as a return type) resolves through the global class-cache
lookup to the *real* class — two nominally different types for the same enum. A static
factory that both takes its own nested enum as a parameter and constructs itself via the
explicit class name (`EditBlockCommand.new(...)`) must qualify the parameter type the
same way (`p_kind: EditBlockCommand.Kind`, not bare `Kind`) or the self-check fails with
a spurious argument/return-type mismatch that only exists under the renamed copy, never
in a real run. No prior file collided with this (existing self-constructing factories
like `DeterministicRng.from_seed()` pass only primitives).

`043` added `world/terrain/block_raycast_service.gd` (`BlockRaycastService`, static
`cast(terrain, registry, origin, direction, max_distance) -> BlockRaycastHit`) — the
first code calling `VoxelTool.raycast()`. `VoxelRaycastResult` (the engine's own return
type) only carries a raw voxel position/normal/distance, with no concept of
`BlockRegistry` or the `+1` air offset `blocky_library_builder.gd` (037) established;
`cast()` reads the hit voxel's raw value via `tool.get_voxel()`, subtracts the offset,
and resolves it through `registry.id_from_network_index()`, returning a small typed
result, `world/terrain/block_raycast_hit.gd` (`BlockRaycastHit`: `block_id`,
`hit_position`, `placement_position`, `normal`, `distance`). Returns null (logged) for an
unlocked registry, a zero direction, a terrain with no voxel tool, a plain miss, or an
unresolvable voxel value. Same "no player/camera yet" scope as 039–042: `cast()` takes
an explicit ray rather than reading one from a camera. `collision_mask` is left at
`VoxelTool.raycast()`'s own default (every bit set) — a non-solid block's model already
has `collision_mask = 0` (037), so it's excluded from a hit regardless; no extra
filtering decision was needed. `DEFAULT_MAX_DISTANCE` (10.0) is named explicitly even
though it matches the engine default, same "explicit, not merely matching the default"
reasoning 041/042 used — real player reach balance is Phase F/G and may replace it
outright.

This brick surfaced one thing worth recording that no upstream doc page states:
`VoxelToolTerrain.raycast()` only finds a hit once the terrain has actually meshed the
area under the ray — confirmed by direct experiment (a throwaway headless probe script,
not committed), not by reading a doc page. Even against the placeholder
`VoxelGeneratorFlat` (039) with no stream/persistence involved, this needs the
`VoxelTerrain` added to the `SceneTree` with a `VoxelViewer` nearby and several real
frames for Voxel Tools' worker threads to catch up; `try_set_block_data()` does not work
synchronously outside the tree either (returned `false` even several frames after being
added). Recorded in `docs/voxel-tools.md` §10 (new section). Tests in
`tests/unit/test_block_raycast_service.gd` (4 tests, +252 total) poll
`VoxelTerrain.is_area_meshed()` per frame up to a generous cap rather than waiting a
fixed frame count, so the test doesn't flake on worker-timing variance: unlocked-registry
rejection and zero-direction rejection (both fail before touching the terrain, no tree
needed), a real hit on the placeholder ground (block id, hit/placement positions,
distance all asserted against `VoxelTerrainBuilder.PLACEHOLDER_GROUND_HEIGHT`), and a
miss (ray pointing into open air) returning null. No reference read — traceability.md §2
confirmed 043 isn't cited by any matrix, same as 031–042.

`042` added `world/terrain/voxel_viewer_builder.gd` (`VoxelViewerBuilder`, static
`build() -> VoxelViewer`) — the last of the four `VoxelNode`/`VoxelTerrain` properties
`docs/voxel-tools.md` §6 had split across bricks 039–042. `VoxelViewer` turned out to be
a separate `Node3D`, not a `VoxelTerrain` property — confirmed by fetching
`doc/classes/VoxelViewer.xml` and re-checking `VoxelTerrain.xml`'s `max_view_distance`
doc from the `godot_voxel` reference repo (CLAUDE.md §15 source) — so the brick splits
into two small pieces: `voxel_terrain_builder.gd` now also sets
`terrain.max_view_distance = DEFAULT_VIEW_DISTANCE` (a new constant, `128`, matching both
properties' own engine default but named explicitly so it can't drift into two
independently-defaulted literals), and the new `voxel_viewer_builder.gd` builds a
`VoxelViewer` with `view_distance` set to that same constant plus `requires_visuals =
true`/`requires_collisions = true` — explicit, not merely left at the matching engine
default, same "explicit is a real decision" reasoning 041 used for `material_override`.
`enabled_in_editor`/`requires_data_block_notifications` are left at their engine defaults
(`false`) — no live-in-editor streaming workflow or block-notification consumer exists to
justify overriding either.

Neither builder adds the viewer to a scene tree or parents it under a camera — no
player/camera exists yet (Phase F, bricks 106–130) to attach it to. This carries forward,
not resolves, the "where does this node live in a scene" question 039's own nextsteps
entry first raised; full reasoning in `docs/voxel-tools.md` §9 (new section, same pattern
as §§6–8). Tests: `tests/unit/test_voxel_viewer_builder.gd` (new, 2 tests) — baseline
`requires_visuals`/`requires_collisions` are true, and `view_distance` matches
`VoxelTerrainBuilder.DEFAULT_VIEW_DISTANCE` exactly (the coupling this brick's whole
design rests on). `tests/unit/test_voxel_terrain_builder.gd`'s existing
`test_builds_a_configured_voxel_terrain` gained one assertion (`max_view_distance ==
DEFAULT_VIEW_DISTANCE`), same shape as 041's addition to that same test. No new docs
contract beyond `docs/voxel-tools.md` §9 — this is a direct continuation of §§6–8's
per-property pattern, not a new one.

`041` resolved the open question `nextsteps.md` itself had flagged (former "Next 10
actions" item 1): does `VoxelTerrain.material_override` still need a value now that
037/040 already give every block kind its own per-model `StandardMaterial3D` (texture
atlas + baked-AO flag)? Fetched `doc/source/blocky_terrain.md` from the `godot_voxel`
reference repo (CLAUDE.md §15 source) — it documents an explicit override order where a
non-null `VoxelTerrain.material_override` replaces *every* per-model material in the
mesher's library, not adds to them. Setting one here would have silently discarded the
per-block atlas texturing already built and tested. Since nothing in this project needs
one material applied uniformly across every block kind yet, the correct baseline is an
**explicit `null`** — `world/terrain/voxel_terrain_builder.gd` now sets
`terrain.material_override = null` as a real assignment (same style as the existing
explicit `terrain.stream = null`), not left merely implicit, so the decision reads as
intentional rather than an oversight. Full reasoning in `docs/voxel-tools.md` §8 (new
section, following the §6/§7 per-brick pattern 039/040 established); §6's property table
row updated to point at it. No new `.tres`/asset/registry work — this brick is a single
property decision plus its documentation and test, not new content.

Tests: `tests/unit/test_voxel_terrain_builder.gd`'s existing
`test_builds_a_configured_voxel_terrain` gained one assertion
(`terrain.material_override` is null) rather than a new test method — same coverage
shape as the adjacent `stream`/`generate_collisions` assertions it sits beside. No other
file needed a test change. `docs/reference/matrix-world.md` Q1 and
`docs/reference/traceability.md` §3 already carried `(RESOLVED — brick 040)` covering
bricks "040–041" jointly — both already read correctly and needed no edit, since 041's
finding (no additional shader/material equivalent needed) is consistent with, not a
change to, that resolution.

`040` extended `world/terrain/voxel_terrain_builder.gd` (039) to also build and assign
`terrain.mesher`: a plain `VoxelMesherBlocky` whose `library` comes from
`BlockyLibraryBuilder.build(registry)` (037), the same `registry` argument the
placeholder generator already reads — the generator and mesher can never disagree about
which block ids exist. No new file — one property assignment plus a three-line
`_build_mesher()` helper inside the existing builder, since wrapping one library in one
mesher didn't justify a dedicated `VoxelMesherBuilder` class. `build()` now returns null
if `_build_mesher()` does (only reachable via `BlockyLibraryBuilder.build()` returning
null, which itself only happens for an unlocked registry — already rejected earlier in
`build()`, so this is a defensive propagation, not a new failure mode).

This brick also resolved `matrix-world.md` Q1 (open since brick 021, blocking 040–041
per `docs/reference/traceability.md` §3): does the terrain material/shader need a custom
equivalent of the reference's `ChunkBuffer_sampleVoxelColorAO` baked-color-AO blend, or
is `VoxelMesherBlocky`'s own baked AO sufficient? Fetched
`doc/source/blocky_terrain.md` from the `godot_voxel` reference repo (CLAUDE.md §15
source) to check: `VoxelMesherBlocky` always bakes ambient occlusion into cube-edge
vertex colors; a model's material only needs `vertex_color_use_as_albedo = true` to
display it — no custom shader needed. Answer: **sufficient**. Applied by setting that
one flag on `blocky_library_builder.gd` (037)'s existing per-block `StandardMaterial3D`
(`_build_model()`), not by starting 041's terrain-level `material_override` scope early.
Recorded in `docs/voxel-tools.md` §7 (a new section, not a new `world-terrain-material.md`
file — the answer is a compact engine fact, not a design needing its own document);
`matrix-world.md` Q1 and `traceability.md` §3's Q1 row both carry the
`(RESOLVED — brick 040)` prefix per the brick-029 open-question lifecycle, row not
deleted.

Tests: `tests/unit/test_voxel_terrain_builder.gd` (6 tests, +2 net after removing the
now-false "mesher is 040's responsibility" assertion) — mesher is a real
`VoxelMesherBlocky`, and its library's model at `network_index(id) + 1` has
`resource_name == id`, confirming the generator and mesher share one offset convention.
Its `_block()` helper now writes real 2x2 `user://` PNGs (same pattern
`test_blocky_library_builder.gd` already used) instead of referencing nonexistent
`res://dummy_*.png` paths — those paths were harmless before 040 because nothing ever
loaded them; building a real mesher now does, and surfaced this immediately as a test
failure (`Error opening file`), not a silent gap.
`tests/unit/test_blocky_library_builder.gd` (+1 test): a solid block's material has
`vertex_color_use_as_albedo == true`. No docs page changed beyond `voxel-tools.md` §7
and the two open-question rows above.

`039` added `world/terrain/voxel_terrain_builder.gd` (`VoxelTerrainBuilder`, static
`build(registry: BlockRegistry) -> VoxelTerrain`) — the first code that instantiates a
real `VoxelTerrain` node. Scope is deliberately one node's worth of the properties Phase
C splits across 039–042: this brick owns `generate_collisions` (`true`) and `generator`;
`mesher` is left unset for 040 (`BlockyLibraryBuilder`'s output), `material_override` for
041, `VoxelViewer`/`max_view_distance` for 042. `stream` is explicitly set to `null` —
persistence is 048, and `VoxelNode.stream`'s own doc says an unassigned stream makes the
whole volume regenerate from the generator, which is exactly what a save-less baseline
needs. `bounds` is left at the Voxel Tools engine default — no world-size decision exists
yet to justify overriding it, and inventing one wasn't this brick's job.

The `generator` is an explicit, temporary placeholder, not real world generation: a flat
plane of one registered block (`block.stone`) via `VoxelGeneratorFlat` (`channel =
VoxelBuffer.CHANNEL_TYPE`, `voxel_type = registry.network_index(id) + 1`, reusing the
exact +1 air-offset convention `blocky_library_builder.gd` (037) established). Real
generation is Phase D (056–067, deterministic noise/height/climate fields per
`docs/reference/matrix-world.md`), which replaces `terrain.generator` outright rather
than extending this file — recorded explicitly in both the file's own header comment and
`docs/voxel-tools.md` §6 so a future reader doesn't mistake the placeholder for a design
decision. Verified against the upstream `godot_voxel` doc classes (`VoxelNode.xml`,
`VoxelTerrain.xml`, `VoxelGeneratorFlat.xml`, `VoxelBuffer.xml`) fetched this brick,
since no local doc page previously recorded `VoxelTerrain`'s own property surface
(037 only needed `VoxelBlockyLibrary`/`VoxelBlockyModel`).

Same "one entry missing, not a crash" degrade pattern as 037: `build()` returns null (and
logs via `Log.CH_VOXEL`) for an unlocked registry or a registry missing
`PLACEHOLDER_BLOCK_ID`, rather than building a half-configured node. `docs/voxel-tools.md`
§6 records the full property table and both explicit-null decisions (`stream`, deferred
`bounds`). Tests in `tests/unit/test_voxel_terrain_builder.gd` (4 tests): unlocked-registry
rejection, missing-placeholder-block rejection, `mesher`/`stream` left null while
`generate_collisions` is true, and the generator's `channel`/`voxel_type`/`height` values
including the network-index-plus-one offset. No scene (`.tscn`) added — the builder
returns a plain `VoxelTerrain` node for a caller to add to a tree; wiring it into
`client/main/main.tscn` or a dedicated world scene is left to whichever of 040–042 first
needs something visible to test against.

`038` added the first real, committed content: four placeholder textures under
`assets/textures/blocks/` (`grass_top.png`, `grass_side.png`, `dirt.png`, `stone.png` —
16x16, flat base color plus small deterministic per-pixel noise so faces read as a
material rather than a solid swatch; `grass_side` is dirt with a green fringe on the top
quarter, the reference grass-block silhouette) and three `BlockDefinition` resources
under `data/blocks/` (`grass.tres`, `dirt.tres`, `stone.tres`), both written by a new
one-off headless generator, `tools/generators/generate_block_set.gd` (a new `generators/`
subdirectory of `tools/`, alongside `probe/` — deterministic content generation run via
`--script`, output committed and re-generatable, distinct from `probe/`'s "assert
something about the environment" role). The generator calls `BlockDefinition.validate()`
and `ResourceSaver.save()` itself, so a bad field value fails the generation step, not a
later load. Texture/data paths match exactly what `test_block_definition.gd` and
`test_block_registry.gd` already hardcoded as example fixtures (`grass_top.png`,
`grass_side.png`, reusing `dirt.png` as grass's bottom face) — those tests never asserted
the files existed, but the coincidence confirmed the naming scheme before any file was
written. `hardness` differs per kind (grass 0.5, dirt 0.75, stone 3.0) as a first
placeholder mining-effort ordering; `drop_item_id` is left empty on all three — no
`ItemRegistry` exists yet (Phase H), and 035 already made that field optional for exactly
this reason.

Added `world/terrain/block_set.gd` (`BlockSet`, static `load_default(dir) -> BlockRegistry`)
— the loader `block_definition.gd`'s own header comment predicted back in 031 ("a loader
parses `data/blocks/*.tres` ... and hands each one to a `BlockRegistry`"), and the first
concrete implementation of `docs/ids-and-registries.md`'s generic "a loader parses data
and calls register()" line. Scans the directory and sorts filenames rather than
hardcoding the three ids, so a later block kind is purely a new `.tres` data file — no
loader change. A missing directory, a file that fails to load, a file that isn't a
`BlockDefinition`, or a definition that fails its own `validate()` is logged and skipped
rather than failing the whole load, same "one entry missing, not a crash" contract
`BlockRegistry.register_block()` already uses; the returned registry is always locked,
even when nothing loaded. No new docs page — this is a direct implementation of an
existing contract, not a new one, same reasoning 033–036 used.

Running the generator against the real project surfaced one thing worth recording: once
these PNGs are real, imported `res://` project assets (rather than the runtime-only
`user://` PNGs `test_blocky_library_builder.gd` synthesizes), loading them with
`Image.load()` — what `blocky_library_builder.gd` (037) does for every face texture —
now prints an engine warning, `"Loaded resource as image file, this will not work on
export"`. Tests still pass (the warning doesn't fail anything headless), but it is a real
signal that this texture-loading path will not survive an exported build, not just a
theoretical one — recorded in Known risks below rather than fixed here, since fixing it
means changing `blocky_library_builder.gd` (037)'s already-tested loading strategy, out
of this brick's "create a block set" scope.

Tests added in `tests/unit/test_block_set.gd` (5 tests): default load is a locked
registry with exactly grass/dirt/stone; footstep tags match each kind; every loaded
definition is individually valid; the default set builds a real `VoxelBlockyLibrary`
through `BlockyLibraryBuilder` with **no** block degrading to a placeholder (the
end-to-end check that the real texture assets actually load, not just the synthetic ones
037's own tests generate); and a missing directory returns an empty, still-locked
registry rather than null or a crash.

`037` added `world/terrain/blocky_library_builder.gd` (`BlockyLibraryBuilder`, static
`build(registry: BlockRegistry) -> VoxelBlockyLibrary`) — the first brick that actually
constructs Voxel Tools engine resources from `BlockDefinition` data, closing the
"deferred to 037" note left on `texture_top`/`texture_side`/`texture_bottom` (033) and
`is_solid`'s collision-layer mapping (034). Two decisions this brick had to make, both
now recorded:

1. **`VoxelBlockyLibrary` + `VoxelBlockyModelCube`, not `VoxelBlockyType`/
   `VoxelBlockyTypeLibrary`** — recorded in `docs/voxel-tools.md` §5, which had flagged
   this as a required deliberate choice since brick 003. `BlockDefinition` has no
   attribute/state axis (no rotation, no connected-state), so the plain library is the
   correct minimal fit; revisit only if a future block kind needs per-voxel state.
2. **Voxel value 0 = air, offset by one from `BlockRegistry.network_index()`.**
   `network_index()` is a general registry concept (032, used for packets/saves too) and
   was not redefined to reserve 0 for air. Instead `build()` inserts an explicit
   `VoxelBlockyModelEmpty` at library index 0, then appends one model per
   `registry.ids()` entry (sorted == locked network-index order) — `add_model()` assigns
   indices by call order, so the result is always `library index == network_index(id) +
   1`. Any future code writing raw voxel values (block edit application, 044–046) must
   apply that `+1`. Documented in the file's own header comment, not just here.

Texture resolution (deferred by 033) turned out to need a real sub-decision:
`VoxelBlockyModelCube.set_tile(side, position)` addresses one shared atlas per model —
confirmed by fetching `doc/source/blocky_terrain.md` from the `godot_voxel` reference
repo (CLAUDE.md §15 source) — so three independent per-face image paths cannot be
wired in directly. `_build_atlas()` packs each block's own top/side/bottom images into
one small 3-tile-wide runtime atlas (`Image.blit_rect`, no dedup for a block whose
faces repeat one path — not worth the complexity yet, `CLAUDE.md` §8) and assigns it as
a `StandardMaterial3D` on the model (nearest-filter, for the blocky look). A missing or
unreadable face texture, or three face textures that don't share one size, degrades
that one block to a placeholder `VoxelBlockyModelEmpty` and logs why — `build()` keeps
going rather than failing the whole library, same "one entry missing, not a crash"
pattern `BlockRegistry.register_block()` already uses. `collision_aabbs` also needed an
explicit decision: Voxel Tools does not default a cube model to a full collision box —
an empty list means no collision — so `is_solid` now maps to one explicit unit-cube
`AABB`, confirmed against the same reference doc page.

No real texture assets exist yet (038 creates the first grass/dirt/stone set), so
`tests/unit/test_blocky_library_builder.gd` (8 tests) generates its own tiny PNGs under
`user://` at test time (`Image.create` + `fill` + `save_png`, cleaned up in
`after_each`) rather than depending on `res://assets/textures/blocks/*`. Covers:
unlocked-registry rejection, air-only library for an empty registry, index-plus-one
alignment against two registered blocks, solid/opaque vs non-solid/transparent
collision+culling, atlas packing (pixel-exact via 8-bit `Color8` values, since a PNG
round trip quantizes float color), missing-texture degrade, and mismatched-face-size
degrade. `docs/voxel-tools.md` §5 updated with the decision (see above); no ADR — the
README's own "routine implementation choice inside a single file" exclusion applies
once the library-vs-type choice itself is recorded, and this file's own header comment
carries the +1 offset and atlas reasoning for the next reader.

`036` extended `world/terrain/block_definition.gd` with the last block-property field
this phase deferred: `footstep_tag: String = ""` — a plain lowercase surface-material
category ("grass", "dirt", "stone", ...) for footstep/movement audio. Deliberately not
a stable ID: unlike `drop_item_id` (035), which names one piece of identified content
(an item) that will eventually live in a registry, `footstep_tag` names a *category*
shared by many block kinds and is never looked up through a registry — no `sound`-domain
ID or registry entry is created for it. It is the input key, not a reference, to the
tag -> sound-event table that backlog brick 220 ("footstep/audio surface mapping",
Phase J) builds; that mapping is out of scope here, same as texture-path resolution
staying out of scope for 033 pending 037. Required (like the texture fields) rather than
optional (like `drop_item_id`): every block a player can stand on needs a footstep
category, and unlike `hardness` (harmless-but-meaningless when `destructible` is false)
there's no default value that would be correct for an unset tag, so `validate()` rejects
an empty string. `docs/reference/traceability.md` §4 already confirmed no reference
matrix cites 031–055, so no reference read was needed, same as 031–035. Tests extended in
`tests/unit/test_block_definition.gd` (24 tests, +1): missing-footstep_tag rejection;
`_valid()` now sets `footstep_tag = "grass"`. `tests/unit/test_block_registry.gd`'s
`_grass()`/`_dirt()` helpers updated to set `footstep_tag` so they stay valid under the
new mandatory field (no new registry tests needed, same reasoning as 033–035). No docs
page added — same "direct application of an existing convention" (required-string-field
pattern already used by the texture fields) reasoning as 033–035, not a new contract.
Phase C's per-block-property bricks (031–036) are now complete; 037 (`VoxelBlockyLibrary`
bootstrap) is next.

`035` extended `world/terrain/block_definition.gd` with three fields: `destructible: bool
= true` (bare adjective, same style as `transparent`, not `is_destructible` — independent
of `is_solid`, since a block can collide but never be destroyed or vice versa), `hardness:
float = 1.0` (an abstract positive mining-effort multiplier, deliberately not seconds and
not tied to any tool-tier scheme — that belongs to Phase G/H equipment/combat data, not
block-kind data; validated `> 0` regardless of `destructible`, so a data file can't carry
a stale nonsensical value), and `drop_item_id: String = ""` (stable ID, domain `item`,
empty = no drop; quantity/roll variance is deferred to the Phase H loot system — this
field only names *what*, not how many). No `ItemRegistry` exists yet, so `validate()`
only checks `drop_item_id`'s grammar and domain via `StableId`, the same way `id` itself
is checked without a live registry to cross-reference — whether the named item actually
exists is a data-loading-time concern, not this resource's, same reasoning brick 033 used
for texture paths. `docs/reference/traceability.md` §4 already confirmed no reference
matrix cites 031–055, so no reference read was needed, same as 031–034. Tests extended in
`tests/unit/test_block_definition.gd` (23 tests, +9): destructible default/false-stays-
valid, hardness default/zero-rejected/negative-rejected, drop_item_id default-empty-
valid/well-formed-accepted/malformed-rejected-with-field-prefix/wrong-domain-rejected.
`tests/unit/test_block_registry.gd` needed no change — all three new fields default to
values that keep its existing `_grass()`/`_dirt()` helpers valid unmodified, same as 034.
No docs page added — same "direct application of an existing convention" reasoning as
031–034, not a new contract.

`034` extended `world/terrain/block_definition.gd` with a single `is_solid: bool = true`
field — whether the block kind produces collision at all. Deliberately a plain predicate,
not a raw `VoxelBlockyModel.collision_mask` bitmask: `docs/conventions.md` §5 already uses
`is_solid`/`has_collision` as its own worked example of the boolean-naming rule, which
reads as an intentional pointer to this exact field name, so no reference read or extra
design was needed to pick it. Unlike 033's texture fields, `is_solid` is not a direct
1:1 mirror of one `VoxelBlockyModel` property the way `transparent` is — which physics
layer(s) a solid block occupies is left as an engine-integration decision for the
`VoxelBlockyLibrary` bootstrap (037: e.g. `is_solid ? 1 : 0` or similar), not block-kind
data. No `validate()` change: like `transparent`, a bool has no invalid state, so
`is_valid()` stays true regardless of `is_solid`'s value. `docs/reference/traceability.md`
§4 already confirmed no reference matrix cites 031–055, so no reference read was needed,
same as 031–033. Tests extended in `tests/unit/test_block_definition.gd` (13 tests, +2):
default-true check, and an explicit-false-stays-valid check documenting that collision is
engine-integration, not a validity rule. `tests/unit/test_block_registry.gd` needed no
change — `is_solid` defaults to true, so its existing `_grass()`/`_dirt()` helpers stay
valid unmodified. No docs page added — same "direct application of an existing
convention" reasoning as 031–033, not a new contract.

`033` extended `world/terrain/block_definition.gd` with the material fields 031 deferred:
`texture_top` / `texture_side` / `texture_bottom` (plain `res://...` `String` paths, same
"no editor hint" style as `id`/`display_name`) and `transparent: bool = false`. Three
faces, not six or one — matches the top/side/bottom scheme every reference block needs
(grass: green top vs dirt-textured sides) without guessing at a full six-sided model this
early; a uniform block (stone) just repeats one path in all three fields. `transparent`
carries `VoxelBlockyModel`'s own face-culling flag so the `VoxelBlockyLibrary` bootstrap
(037) can set it directly instead of re-deriving it from texture content — recorded on
the definition now because CLAUDE.md §10 calls out preserving exact culling behavior.
`validate()` now rejects any of the three texture fields being empty, same
empty-string-reason convention as `display_name`. No stable-ID domain was added for
textures/materials (`StableId.DOMAINS` unchanged) — texture assignment is a resource
path, not gameplay-content identity, so it doesn't need one. Actual `Texture2D`/
`Material`/`VoxelBlockyLibrary` construction stays out of scope, deferred to 037 per
031's original plan. `docs/reference/traceability.md` §4 already confirmed no reference
matrix cites 031–055, so no reference read was needed, same as 031/032. Tests extended in
`tests/unit/test_block_definition.gd` (11 tests, +5): three new missing-texture-field
rejections, one `transparent` default check, and `_valid()` now sets all three texture
fields; `tests/unit/test_block_registry.gd`'s `_grass()`/`_dirt()` helpers updated to stay
valid under the new mandatory fields (no new registry tests needed — the registry only
forwards to `BlockDefinition.validate()`, already covered). No docs page added — same
"direct application of an existing contract" reasoning as 031/032, not a new one.

`032` added `world/terrain/block_registry.gd` (`BlockRegistry extends RefCounted`,
`class_name` — the first live use of `DefinitionRegistry` outside its own tests, per
`docs/ids-and-registries.md` §5: "it does not validate the definition, only the id;
each domain's definition type checks its own fields"). Thin typed wrapper, not a
reimplementation: pins the domain to `"block"`, calls `BlockDefinition.validate()`
before handing anything to the wrapped `DefinitionRegistry.register()`, and returns
`BlockDefinition` instead of `Variant` at every read (`get_block`, `require_block`).
Every other method (`add_alias`, `lock`, `is_locked`, `clear`, `has_block`, `resolve`,
`ids`, `ids_under`, `size`, `network_index`, `id_from_network_index`, `content_hash`)
delegates straight through — the wrapper adds no state of its own beyond the one
`DefinitionRegistry` instance. `docs/reference/traceability.md` §4 already confirms no
reference matrix cites 031–055, so no reference read was needed, same as 031. Tests in
`tests/unit/test_block_registry.gd` (10 tests): valid registration, rejection of a
definition that fails its own `validate()` despite a well-formed id (missing
`display_name`), wrong-domain rejection, duplicate-id rejection, lock/network-index
ordering, post-lock registration refusal, alias resolution, sorted `ids()`/`ids_under()`,
order-independent `content_hash()`, and `clear()` round-trip. No docs page added or
changed — this brick is a direct application of the existing `docs/ids-and-registries.md`
contract, not a new one; `block_definition.gd`'s own doc comment already named this
brick as the intended consumer.

`031` added `world/terrain/block_definition.gd` (`BlockDefinition extends Resource`,
`class_name` — referenced by the registry/schema bricks that follow): `id`,
`display_name`, and a `validate()`/`is_valid()` pair mirroring `StableId.validate()`'s
"empty string = ok, else reason" convention, per `docs/ids-and-registries.md` §5 ("each
domain's definition type checks its own fields"). Deliberately minimal — material,
collision, interaction/destruction and footstep/surface-tag fields are scoped to bricks
033–036, not guessed here; no block-shape/mesh field either, left to 037's
`VoxelBlockyLibrary` bootstrap. `docs/reference/traceability.md` §4 already confirmed no
reference matrix cites 031–055, so no reference read was needed. Tests in
`tests/unit/test_block_definition.gd` (6 tests): valid/invalid shape, malformed id
(reason matches `StableId`'s own, not a reworded copy), wrong domain, missing
`display_name`, and one end-to-end registration into a `DefinitionRegistry.new("block")`.
No docs page added — this brick uses existing contracts (016, 011) rather than
establishing a new one.

`030` built `docs/reference/traceability.md`: a reverse index from backlog brick → matrix
row/concept, read off the `Bricks` column of every §1/§2 row across all 8 matrices
(021–028), organized by backlog phase (D through K — no reference-informed rows exist
before Phase D). §3 consolidates all 23 open questions from the 8 matrices' §4 sections
into one table with their `Blocks`/status, mirroring (not replacing) the "Next N actions"
list below per `confidence.md` §5. §4 records why most of Phase A/C/L have no rows (
original design, Voxel Tools supersedes the reference's own chunk cache) versus "not yet
cross-referenced" (an honest gap, not asserted absence). `matrix-index.md` §6 and
`README.md` §6 now point to it instead of describing the not-yet-built index. No code
changed — docs-only brick, same as 029; `check.ps1`/`test.ps1` not re-run for this reason,
last run stays the one recorded below.

`021` mapped `*/world/` (13 classes: `World`, `Zone`, `Region`, `Dungeon`, `House`,
`Spawn`, `Field`, `Chunk`, `ChunkBuffer`, `LandscapeTile`, `WorldInfo`, `WorldMap`,
`ZoneTile`) into `docs/reference/matrix-world.md`. Notable: `World` is a god-object
whose functions were split by behavior, not kept as one row (see matrix §2); several
classes (`Chunk`, `ChunkBuffer`, block/column accessors, the client per-frame world
tick) are `Placed = NONE` because `VoxelTerrain`/`VoxelMesherBlocky`/Godot's own
process loop supersede them — do not reimplement a parallel chunk cache. Four open
questions recorded (matrix §4), most importantly Q2: the original client re-ran world
generation locally rather than only presenting replicated state — confirm this was a
singleplayer-only pattern before brick 056.

`022` mapped `*/entity/` (6 classes: `Creature`, `Sprite`, `SpriteManager`, `Speech`,
`QuestText`, `QuestTextNode`) into `docs/reference/matrix-entity.md`. Notable:
`Creature`'s own attributed functions are almost entirely ctor/dtor/container plumbing
— actual creature behavior (locomotion, player-controller reset, replicated-state
apply, appearance/equipment defaults) is scattered across `game_misc` and the client
`World`/`Interface` sections and was split out in matrix §2, same pattern as `World` in
brick 021. `QuestText`/`QuestTextNode` are physically in `*/entity/` but reserved for
`matrix-quests.md` (026) per `matrix-index.md` — rows added with `Placed = NONE` so
they aren't silently dropped. Three open questions recorded (matrix §4): Q1 no backlog
brick currently cites this matrix for creature/player locomotion (112/116/128/243); Q2
`*/db/` (`cube::Database`) has no planned matrix at all; Q3 `Sprite`/`SpriteManager`
are stub-only in both binaries, role undetermined.

`023` mapped `*/ai/` (8 classes: `CombatBehavior`, `CompanionBehavior`,
`LookAtPlayerBehavior`, `RandomInteractionBehavior`, `RandomWalkBehavior`,
`SequentialBehavior`, `SpawnLocationBehavior`, `WalkPathBehavior`) into
`docs/reference/matrix-ai.md`. Every leaf shares one tick+clone interface (no separate
`Behavior` base class survived attribution — inferred and recorded in matrix §2, same
"concept with no single class" treatment as 021/022). `CombatBehavior`'s tick is an AI
decision shell but almost all of its named functions are ability timing/resolution math
— that math is `Placed = NONE` here, reserved for `matrix-combat.md` (024), continuing
the split pattern from `matrix-entity.md`. Nav/locomotion primitives
(`NavGraph_*`, `World_getBlockFloat`, `Creature_resolveSeparation`) are called by three
different leaves and owned by none — cross-referenced to `matrix-entity.md`'s Q1
instead of duplicating it. Three open questions recorded (matrix §4): Q1
`SequentialBehavior` executes like a first-success Selector despite its decompiled
name — need to decide if bricks 177/178 need both a true Sequence and a Selector; Q2
`SpawnLocationBehavior`'s location-switch condition reads an unconfirmed `world` field,
possibly the day/night clock (brick 216); Q3 `RandomInteractionBehavior`'s tick body
(773 lines) was not read in full, only GAP-summarized — revisit before brick 189/199 if
the one-line role proves insufficient.

`024` mapped combat resolution/damage/hit-detection into `docs/reference/matrix-combat.md`.
No reference class is named `Combat`/`Damage`/`Hit` — everything is 14 "concepts with no
single class" rows (ability timing table, attack-speed/haste, base-damage formula,
max-health formula, armor mitigation, resist diminishing-returns, ability power/mana
cost, resource regen, equipment stat-bonus plumbing, threat/target selection, hostility
gate, aggro-alert propagation, attack-opcode/animation classification, buff/status-effect
list), gathered from server `game_misc`/`CombatBehavior` GAP rows, `cube_types.h`'s
VERIFIED `cube_Creature_offsets`/`cube_BuffNode_offsets` enums, and client `Interface`
(`stat::calc*`) rows read only for corroboration. Three open questions recorded (matrix
§4): Q1 server `World.cpp`'s `readCombatActionFromStream`/`readHitFromStream` deserialize
fixed-size records from a SQLite-loaded blob (adjacent to `SpeechDb_loadBlobToVector`),
not obviously a live network read despite the name — unresolved whether this is
quest-script trigger data or prefigures the combat-event wire format (blocks 136, 137,
249); Q2 the damage/armor/mana formulas share an unexplained `2^a*2^b[/2^c]` shape across
independent functions in both binaries — shape is corroborated, meaning of the exponents
is not, and per the clean-room policy we may not need to recover it (blocks 141–144); Q3
the two attack-*selection* decision trees (`Combat_selectNextAttackAnim`,
`Combat_selectSpiritAttackId`) were read only via their one-line GAP summary, not their
bodies (blocks 138, 139, 192).

`025` mapped inventory/item/equipment concepts into `docs/reference/matrix-items.md`.
One dedicated class (`InventoryWidget`, client) placed in `client/ui/`; `Database`
cross-referenced as out of scope (same generic SQLite blob store already flagged in
`matrix-entity.md`); 9 "concept with no single class" rows gathered from server
`game_misc` item/equip/loot/currency functions and client `GameController`. Notable:
`attribution.tsv` attributes the actual inventory-grid rebuild/scroll/hover functions
(GAP-named `InventoryWidget_rebuildItemList` etc.) to `GameController`, not
`InventoryWidget` — `GameController` is a 620-function client class with no owning
matrix in 021–028, only its ~10 item-relevant functions were pulled in here, same
"concept with no single class" pattern as 021–024. Three open questions recorded
(matrix §4): Q1 `GameController` itself needs a home (a new matrix before 224/225, or
absorbed by 028); Q2 equipment slot count is contradictory across two server functions
(16 vs 12) with no VERIFIED offset to arbitrate, unlike combat's `cube_Creature_offsets`
— brick 164 must choose independently; Q3 the "rng affix" rolled by
`GameController_onItemPickup` was not read past its GAP one-liner, relevant before
brick 173 if affix mechanics matter for the loot roll service.

`026` mapped quest/NPC concepts into `docs/reference/matrix-quests.md`. Placed the two
classes deferred from `matrix-entity.md` (`QuestText`, `QuestTextNode` — a shared
templating/tree engine with `Speech`) and found no dedicated `NPC`/`Quest`/`Faction`/
`Shop` class in either binary: NPCs are plain `Creature` instances, and all quest/NPC
behavior is 7 "concept with no single class" rows pulled from client `GameController`
(`interactNpc`, `interactSpecialObject`, `computeQuestScore`, `questStateChanged`,
`build_quest_text`) and server `game_misc`/`EntityData` (quest strings stored inline on
the entity record, an opcode-tagged `check_quest_id_match`). Notable: quest progress in
the original is a **polled derived score** (`computeQuestScore` sums 11 unrecovered
counters), not a discrete objective list — the backlog's brick 207 "objective types"
design is judged an acceptable behavioral equivalent, not a reference deviation, since
the exact counters are decompiler data we would not ship anyway (matrix §4 Q1). Faction/
hostility/aggro was **not** re-placed — already fully mapped in `matrix-combat.md` §2,
cross-ref only. Two open questions recorded (matrix §4): Q1 the unrecovered 11-counter
quest score (likely resolvable by design decision alone, see above); Q2 whether
`check_quest_id_match`'s `event type 0x19` is the same opcode-tagged stream as
`matrix-combat.md` Q1's `readCombatActionFromStream`/`readHitFromStream` — re-opens that
question with new evidence, relevant before brick 251. Brick 200 ("NPC shop service")
already covers the `interactNpc` trade-UI branch found here, so no new question was
needed for it. `matrix-items.md` Q1 (`GameController` scoping) gained corroborating
evidence rather than a duplicate question.

`027` mapped `cube/ui/` (24 files, 22 `cube::` classes) into `docs/reference/matrix-ui.md`.
Every widget but one is stub-only (1–2 attributed functions — ctor plus a render/input
vfunc); the exception, `AdaptionWidget` (28 attributed functions), is the shared layout/
scroll/bounds/animation engine every other widget inherits from, same "one real class,
rest are thin leaves" shape as `matrix-ai.md`'s behavior tree. Two files in the directory
(`Button`, `ScrollSlider`) declare only `plasma::` methods — misfiled engine-layer
widgets, moved to §3 out-of-scope, same pattern as the combat functions cross-referenced
out of `matrix-world.md`. `cube::WorldPreviewWidget` (deferred from `matrix-world.md`,
021) was placed here; `cube::InventoryWidget` (already placed in `matrix-items.md`, 025)
was cross-referenced, not re-placed. Notable: `GameController` GAP rows for mouse
routing, hover/focus, widget-tree file deserialization (`.CUB` format), and the
character-select/world-select screen builders (`buildCharacterList`/`buildWorldList`)
confirm — a third and fourth time, after `matrix-items.md` and `matrix-quests.md` — that
the actual client UI framework lives on `GameController`, not on any `Widget` subclass;
folded into `matrix-items.md` Q1 as corroborating evidence rather than a new question.
Two open questions recorded (matrix §4): Q1 several reference UI screens (character
creation, main menu/title screen, merchant/trade dialog) have no corresponding backlog
brick yet; Q2 `GameController`'s widget-framework slice keeps growing across three
matrices with no owning matrix or brick — same underlying question as
`matrix-items.md` Q1, now with UI-framework evidence added.

`028` mapped the client/server split into `docs/reference/matrix-client-server.md` — the
last of the mapping bricks (021–028). Only 2 dedicated networking classes exist
(`cube::Server`, `cube::Connection`, both server-only, both stub-only on their own
attributed functions); the actual protocol logic is 9 "concept with no single class"
rows. Notable finding: the send-loop/recv-dispatch/serialize functions GAP-names after
`Server`/`Connection`/`World`/`EntityData` are physically filed under `Global` (no
owning class) inside `server/_library/crt_stl.cpp` — the automated attribution tool
treats them as library code because they're vtable-less free functions, but GAP naming
and a `std::function`-lambda call-graph read (each wrapped in its own thunk) confirm
send and receive run as two independent per-connection workers. The client binary has
**no networking class or `net/` directory at all** — its socket-facing functions
(`net::Connection::recv_delta_*`, `EntityState_deserializeFromBuffer`/
`recvFromSocket`) are entirely unattributed (`kind=lib,target=other`), invisible to a
class-based read; the one class-attributed touchpoint, `GameController_disconnect`,
continues the same "GameController is the real framework" pattern already seen in
`matrix-items.md`/`matrix-quests.md`/`matrix-ui.md`. Two prior open questions were
**closed** this brick, not just cross-referenced: `matrix-combat.md` Q1 — a wider read
of the `World.cpp` call site (blob key built from `"mission"`/`"monster"` + int IDs)
confirms `readCombatActionFromStream`/`readHitFromStream` are quest-script trigger data,
not a network wire format, so bricks 249/251 must design combat-event replication fresh;
and `matrix-items.md` Q1 / `matrix-ui.md` Q2 (`GameController` scoping) — resolved by
decision, same god-object treatment as `World`/`Creature`/the `Behavior` tree, no new
matrix or brick. One new question recorded (matrix §4 Q3): no connect/login/handshake
function was found in either binary's attributed or GAP-named set — a genuine gap in the
source material (`docs/protocol.md`'s independently-designed `HANDSHAKE` kind has no
reference behaviour to corroborate, and does not need one per the clean-room policy).

`029` formalized the confidence/uncertainty convention sketched in `docs/reference/README.md`
§4 into `docs/reference/confidence.md`: a second axis (read depth — `FULL`/`PARTIAL`/
`GAP-ONLY`/`UNREAD`) alongside claim confidence, a ceiling rule that a `GAP_ANALYSIS.md`
-only claim cannot be recorded `HIGH` unless independently corroborated (with the
existing `matrix-client-server.md` dirty-bit row and `matrix-ai.md` ability-timing row
cited as the two correct patterns already in use), "overall confidence" defined as the
minimum over load-bearing claims rather than an average, and the open-question
resolution lifecycle (`(RESOLVED — brick NNN)` prefix, rewrite "Resolved by" in place,
never delete the row) formalizing the pattern brick 028 already used three times.
`README.md` §4 now points to it instead of restating a growing baseline; `_template.md`
and `_matrix_template.md` gained pointers and a read-depth column (template files only —
the 8 already-committed matrices from 021–028 are not retrofitted, per the brick's own
"decisions apply going forward" scope). No code changed; `check.ps1`/`test.ps1` untouched
and not re-run for this docs-only brick beyond the session-start check already recorded
above.

## Commands

```powershell
tools\scripts\check.ps1      # engine + import + voxel + full GDScript compile + headless boot
tools\scripts\test.ps1       # test suite  (-File / -Filter / -Verbose_ / -NoImport)
tools\scripts\run.ps1        # run the game (-Headless; game args forwarded past --)
tools\scripts\godot.ps1 -e   # open the editor
```

Last run: `check.ps1` **OK** · `test.ps1` **OK** — 30 files, 304 tests, 10 336 assertions, 0 failed.

## What exists now

| Area | File | Gives you |
|---|---|---|
| Logging | `autoload/log.gd` | levels, channels, `check()` vs `invariant()`, test capture |
| Scale | `core/math/world_scale.gd` | metres ↔ units ↔ voxels; the only place `0.5`/`2.0` may appear |
| Time | `core/time/simulation_clock.gd` | 60 Hz fixed step, catch-up clamp, snapshot cadence |
| RNG | `core/random/deterministic_rng.gd`, `world_hash.gd` | splitmix64 stream + positional hashing for generation |
| IDs | `core/ids/stable_id.gd`, `definition_registry.gd` | ID grammar, catalogues, aliases, network indices |
| Blocks | `world/terrain/block_definition.gd` | Block-kind schema: `id`, `display_name`, `texture_top`/`texture_side`/`texture_bottom`, `transparent`, `is_solid`, `destructible`, `hardness`, `drop_item_id`, `footstep_tag`, `validate()` |
| Blocks | `world/terrain/block_registry.gd` | Typed `BlockDefinition` catalogue: validates fields, then delegates storage/locking/indices to `DefinitionRegistry` |
| Blocks | `world/terrain/blocky_library_builder.gd` | Builds a real `VoxelBlockyLibrary` from a locked `BlockRegistry`: air at index 0, per-block runtime texture atlas, collision/culling from `is_solid`/`transparent` |
| Blocks | `world/terrain/block_set.gd` | `BlockSet.load_default()`: scans `data/blocks/*.tres`, registers each into a locked `BlockRegistry` |
| Blocks | `data/blocks/*.tres`, `assets/textures/blocks/*.png` | First content: `block.grass`/`block.dirt`/`block.stone` definitions and their placeholder textures, written by `tools/generators/generate_block_set.gd` |
| Terrain | `world/terrain/voxel_terrain_builder.gd` | `VoxelTerrainBuilder.build(registry, stream = null, mesh_block_size = 16)`: a `VoxelTerrain` node with collision on, a placeholder flat-stone `VoxelGeneratorFlat`, and a `VoxelMesherBlocky` sourced from `BlockyLibraryBuilder`; `material_override` explicitly `null` (041 — per-block atlas materials are sufficient, see `docs/voxel-tools.md` §8); `max_view_distance = DEFAULT_VIEW_DISTANCE` (042); `stream` is an optional parameter, `null` unless the caller passes one (048); `bounds = WorldBounds.aabb()` (050); `mesh_block_size` optional, 16 or 32 only (052) |
| Benchmarks | `tools/benchmarks/benchmark_mesh_block_size.gd` + `mesh_block_size_benchmark_runner.gd` | Headless harness measuring `VoxelTerrainBuilder`'s `mesh_block_size` (16 vs 32) against the default block set/view distance; entry/runner split works around a `--script`-vs-autoload compile-order quirk (052, `docs/voxel-tools.md` §17) |
| Persistence | `world/persistence/voxel_stream_builder.gd` | `VoxelStreamBuilder.build(database_path)`: a configured `VoxelStreamSQLite` — deltas-only (`save_generator_output = false`), key cache enabled, unbounded `COORDINATE_FORMAT_STRING_CSD` — a fixed-width format would now fit `WorldBounds`, but switching is a genuinely optional future revisit, not owed by brick 050 (048/050, `docs/voxel-tools.md` §13/§15) |
| World | `world/terrain/world_bounds.gd` | `WorldBounds.aabb()`/`contains(voxel_position)`: the authoritative world extent — `+-524288` voxels horizontal (X/Z), `+-2048` vertical (Y); assigned to `VoxelTerrainBuilder.build()`'s `terrain.bounds` unconditionally (050, `docs/voxel-tools.md` §15) |
| Terrain | `world/terrain/voxel_viewer_builder.gd` | `VoxelViewerBuilder.build()`: a `VoxelViewer` node with `view_distance = VoxelTerrainBuilder.DEFAULT_VIEW_DISTANCE`, `requires_visuals`/`requires_collisions` true; not yet parented under a camera (042, `docs/voxel-tools.md` §9 — no player/camera exists yet, Phase F) |
| Terrain | `world/terrain/block_raycast_service.gd`, `block_raycast_hit.gd` | `BlockRaycastService.cast(terrain, registry, origin, direction, max_distance)`: wraps `VoxelTool.raycast()`, resolves the hit voxel value back to a `BlockDefinition` id through the registry (043, `docs/voxel-tools.md` §10) |
| Network | `network/packets/edit_block_command.gd` | `EditBlockCommand`: PLACE/REMOVE intent (`kind`, `position`, `face_normal`, `block_id`, `tick`); `from_hit()` builds one from a `BlockRaycastHit`; `validate()` is structural only (044) |
| Terrain | `world/terrain/block_edit_validator.gd` | `BlockEditValidator.validate(command, terrain, registry)`: layer-2 gameplay validation against `terrain.bounds`/actual voxel content — registered block, empty/occupied target, `destructible` (045, `docs/server-authority.md` §3) |
| Terrain | `world/terrain/block_edit_applicator.gd` | `BlockEditApplicator.apply(command, terrain, registry)`: writes an already-validated command's effect via `VoxelTool.set_voxel()` — `network_index(block_id) + 1` for `PLACE`, `0` for `REMOVE` (046, `docs/voxel-tools.md` §12) |
| Tests | `tests/integration/test_voxel_load_save.gd` | End-to-end proof: an edit survives a real save/reload round trip through `VoxelStreamSQLite`; an untouched voxel still comes from the placeholder generator (049, `docs/voxel-tools.md` §14) |
| Saves | `core/serialization/save_version.gd` | four version numbers, load verdicts, migration steps |
| Protocol | `network/protocol/*.gd` | message kinds, direction rules, handshake compatibility |
| Authority | `network/authority/command_gate.gd` | envelope validation: owner, tick window, replay, rate limit |
| Docs | `docs/architecture.md`, `conventions.md`, `rng.md`, `persistence.md`, `protocol.md`, `server-authority.md`, `simulation-time.md`, `logging-and-errors.md`, `adr/0001` | the contracts those files implement |

## Next 10 actions

1. `053` benchmark mesh block size 32 (next task) — rerun
   `tools/benchmarks/benchmark_mesh_block_size.gd -- --block-size=32` (same harness, one
   flag) and record the numbers next to 052's in `docs/voxel-tools.md`/`nextsteps.md`, same
   shape as 052's own entry above. `054` then compares both bricks' numbers to choose a
   default; `055` documents the baseline performance budget. None of 039–052 added a
   `.tscn`, and no player/camera exists yet to raycast from or to parent the 042
   `VoxelViewer` under — deciding where these nodes actually live in a scene is still open
   (039's nextsteps entry, carried forward again by 042/043/044/045/046/048/049/050).
2. Before shipping any exported (non-editor) build: revisit `blocky_library_builder.gd`
   (037)'s `Image.load()`-based texture loading — brick 038 surfaced an engine warning
   ("will not work on export") once real imported `res://` PNGs existed to trigger it.
   Not blocking for editor/headless dev and testing; see Known risks below.
3. Before `056`: resolve Q2 from `matrix-world.md` (client-side world generation — singleplayer-only pattern?) — `matrix-ai.md`'s observation that both binaries carry near-identical AI-tick bodies is corroborating evidence, still unresolved. Phase D generation must also fit inside `WorldBounds` (050, `world/terrain/world_bounds.gd`).
4. Before `112`/`116`/`128`/`243`: resolve Q1 from `matrix-entity.md` (cite the matrix for creature/player locomotion, or add a dedicated brick) — `matrix-ai.md`'s nav/locomotion-primitives row cross-refs the same question.
5. Before `164`/`165`: resolve Q2 from `matrix-items.md` (contradictory equipment slot count, 16 vs 12, neither VERIFIED). Before `172`/`173`: Q3 (unread "rng affix" roll in `GameController_onItemPickup`). (`matrix-items.md` Q1 / `matrix-ui.md` Q2 — `GameController` scoping — is now **resolved**, see brick 028 above: no new matrix or brick.)
6. Before `177`/`178`: resolve Q1 from `matrix-ai.md` (does the `BehaviorNode` tree need both a true Sequence and a first-success Selector, given `SequentialBehavior` observably behaves as the latter?). Before `190`/`216`: resolve Q2 from `matrix-ai.md` (unconfirmed world-clock field gating `SpawnLocationBehavior`'s location switch).
7. Before `141`–`144`: resolve `matrix-combat.md` Q2 (unexplained `2^a*2^b` formula shape — may not need resolving under clean-room policy). Before `138`/`139`/`192`: Q3 (attack-selection decision-tree bodies unread). (`matrix-combat.md` Q1 is now **resolved** by brick 028 — quest-script trigger data, not a network format; bricks 249/251 design combat-event replication fresh, with no reference wire format to draw on.)
8. Before `206`–`209`: resolve Q1 from `matrix-quests.md` (the unrecovered 11-counter quest-progress score behind `computeQuestScore` — likely resolvable by design decision alone). Q2 (`check_quest_id_match`'s `event type 0x19`) is unaffected by brick 028's Q1 resolution — still open, still relevant before `251`.
9. Before phase J/K UI bricks (224–231) start: resolve Q1 from `matrix-ui.md` (character creation, main menu/title screen, and merchant/trade dialog have no owning backlog brick yet — a scoping pass may need to insert new bricks).
10. Before `235`/`236`: optionally resolve Q3 from `matrix-client-server.md` (no connect/login/handshake function was found in either binary — a targeted raw read of `server/net/Server.cpp`, only if reference corroboration is wanted; not required by clean-room policy).
11. Update this file after every brick.

## Working set

At session start read `CLAUDE.md`, then this file, then only the active backlog row, its
dependency rows, and the files the task names. For a brick appearing in
`docs/reference/traceability.md` §2, also read the cited matrix section before designing
against it. For 021+ also read `docs/reference/README.md` and `matrix-index.md` before
opening the reference tree.

## Human test state

- Last human playtest: `NOT STARTED`. Nothing visual exists yet — the main scene prints a
  boot report to a label. First `HUMAN_REQUIRED` brick is `091`.
- Last reported visual/gameplay issues: `NONE`

## Technical notes worth keeping

- **Class cache.** Headless `--script` runs read `.godot/global_script_class_cache.cfg`
  and never refresh it, so a new `class_name` is invisible until `godot --headless
  --import` runs. `check.ps1`/`test.ps1` do it; a raw `godot --script` does not.
- **Parse checking.** `load()` returns a resource even for a broken script. Validity is
  decided by `can_instantiate()` (runner) or a detached `GDScript` parse
  (`check_scripts.gd`, which renames the `class_name` in its copy because the real file
  is already registered globally).
- **A test with zero assertions fails.** A GDScript runtime error unwinds the method
  without stopping the runner, so that is the only signal the body aborted.
- **Warnings are errors** for integer division, narrowing conversion and shadowed
  variables (`project.godot [debug]`). Intentional cases need `@warning_ignore*`.
  Watch for: `_init(domain)` shadowing a `domain()` method; `var x := something_untyped`.
- **PowerShell 5.1** wraps native stderr in ErrorRecords; `Invoke-Godot` relaxes
  `ErrorActionPreference` around the call only.
- **GDScript int64** wraps two's-complement as needed, but `>>` sign-extends — use the
  masked logical shift in `DeterministicRng`. Literal negative operands in shifts are a
  parse error; only runtime values work.
- `VoxelGeneratorMultipassCB` exists in 1.7 — the route for generation needing neighbour
  context (structures/villages, bricks 089–093).
- `VoxelTerrainMultiplayerSynchronizer` exists but replicates terrain blocks only; it is
  not a gameplay authority mechanism. Evaluated at brick 050 (`docs/voxel-tools.md` §15):
  the 043–046 raycast/command/validate/apply pipeline is already the real edit-authority
  path, so wiring the synchronizer stays deferred to Phase K, where a real multiplayer
  scene/peer set will exist to wire it into.
- **Voxel value = `BlockRegistry.network_index(id) + 1`; voxel `0` is air.**
  `blocky_library_builder.gd` (037) inserts air at library index 0 and appends blocks in
  `registry.ids()` order — `network_index()` itself is unchanged (still 0-based, used by
  packets/saves too). Terrain/edit code (039+, 044–046) must apply the `+1`.
- **`Image.load(path)` reads a raw PNG/etc straight off disk**, bypassing Godot's
  `res://` import pipeline entirely (no `.import` file needed) — this is how
  `blocky_library_builder.gd` and its test both load/generate images at runtime. Different
  from `load(path)` / `ResourceLoader`, which require an imported `Texture2D`.
- **`VoxelMesherBlocky` always bakes ambient occlusion into cube-edge vertex colors**;
  a model's material only needs `vertex_color_use_as_albedo = true` (Godot's own
  `BaseMaterial3D` property) to display it — confirmed against `godot_voxel`'s
  `doc/source/blocky_terrain.md`, brick 040. No mesher-level AO property exists to set;
  it is unconditional. Resolves `matrix-world.md` Q1 — no custom AO shader is needed.
- **`VoxelViewer` is a `Node3D`, not a `VoxelTerrain` property.** Voxel Tools streams
  data around whatever `VoxelViewer`s exist in the scene tree; `VoxelTerrain.
  max_view_distance` only clamps what a `VoxelViewer` may request — confirmed against
  upstream `VoxelViewer.xml`/`VoxelTerrain.xml`, brick 042. `voxel_terrain_builder.gd`'s
  `DEFAULT_VIEW_DISTANCE` constant keeps both properties in sync.
- **`VoxelNode` (base of `VoxelTerrain`) owns `generator`/`stream`/`mesher`**; `VoxelTerrain`
  itself adds `bounds`, `generate_collisions`, `collision_layer`/`collision_mask`,
  `max_view_distance`, `mesh_block_size` (16 or 32 only). An unassigned `stream` makes the
  whole volume regenerate from `generator` — confirmed against upstream
  `VoxelNode.xml`/`VoxelTerrain.xml`, brick 039. `VoxelGeneratorFlat.channel` defaults to
  `CHANNEL_SDF` (1), **not** `CHANNEL_TYPE` (0) — a blocky placeholder generator must set
  `channel` explicitly or it silently produces SDF data a blocky mesher can't read.
- **The `godot_voxel` reference repo's git tag is `v1.7`, not `v1.7.0`** (confirmed via
  its `tags` API, brick 048) — `raw.githubusercontent.com/.../v1.7.0/...` 404s.
  `docs/environment.md`'s verified `1.7.0` *version string* is unaffected; only the tag
  name used to fetch `doc/classes/*.xml` differs.
- **`VoxelTerrain.bounds` is `AABB`, in voxel coordinates**, default effectively
  unbounded (`AABB(-536870900, ..., 1073741800, ...)`) — confirmed against upstream
  `VoxelTerrain.xml` (v1.7 tag), brick 045. `block_edit_validator.gd` (045) reads it
  directly for the layer-2 "in bounds" check rather than inventing a second bounds
  concept. As of brick 050, `voxel_terrain_builder.gd` sets a real value:
  `WorldBounds.aabb()` (`world/terrain/world_bounds.gd`, `+-524288` voxels horizontal,
  `+-2048` vertical). `bounds` itself only clips generator output, not edits — confirmed
  against the same doc page; 045's own check remains the actual edit-authority
  enforcement (`docs/voxel-tools.md` §15).
- **`doc/classes/VoxelTerrain.xml`'s `get_statistics()` entry over-documents its return
  value** — it lists 9 keys, but the actual C++ source
  (`terrain/fixed_lod/voxel_terrain.cpp`'s `_b_get_statistics()`, `godot_voxel` reference
  repo, tag `v1.7`) only ever sets 7; `time_process_update_responses` and
  `remaining_main_thread_blocks` are documented but never written, confirmed both by
  reading the source and empirically (brick 051, `docs/voxel-tools.md` §16). When a doc
  page and the actual behavior disagree, prefer reading the source directly over trusting
  the XML doc — this project's `VoxelTerrainMetrics.KEY_*` constants
  (`world/terrain/voxel_terrain_metrics.gd`) already reflect only the real 7.
- **A file passed to `--script` is compiled before project autoloads are registered as
  global identifiers.** A script that statically references a `Log`-touching project class
  at its top level (`VoxelTerrainBuilder`, `BlockSet`, `VoxelTerrainMetrics` all call `Log`
  internally) fails to compile with `Identifier not found: Log` when it *is* the `--script`
  entry file — confirmed empirically, brick 052. `tests/run_tests.gd` avoids this by only
  statically referencing `TestCase` (no `Log` dependency) and reaching every real test file
  through a runtime `load()` call instead. Any future `tools/**/*.gd` entry script needs
  the same split: a thin entry file with no such static references, plus a `load()`ed
  runner that does the real work (`tools/benchmarks/benchmark_mesh_block_size.gd` +
  `mesh_block_size_benchmark_runner.gd`, `docs/voxel-tools.md` §17).
- **`VoxelTerrain.get_statistics()`'s `updated_blocks` (and `time_request_blocks_to_update`)
  read as "this specific tick", not a running total.** Polling `updated_blocks` for a
  stable plateau can report "settled" while the value sits at a constant `0` for an entire
  run that still completed real work — the update burst can land between two polls and
  never be sampled (brick 052). Use `VoxelEngine.get_stats()`'s `memory_pools.block_count`
  (monotonic while streaming) plus every `tasks` queue reading `0` instead, for a direct
  "no more in-flight background work" signal.

## Known risks

- `blocky_library_builder.gd` (037) loads block face textures with `Image.load()` on a
  `res://` path. That bypasses the import pipeline on purpose for runtime-generated
  textures, but now that brick 038 committed real, imported `res://` PNGs
  (`assets/textures/blocks/*.png`), Godot warns `"Loaded resource as image file, this
  will not work on export"`. Harmless for editor/headless dev and the test suite (which
  is all that exists today), but must be resolved (e.g. load as `Texture2D` via
  `ResourceLoader`/`load()` and read `get_image()`, falling back to `Image.load()` only
  for non-project paths) before any exported/packaged build — flagged, not fixed, to keep
  038 scoped to "create a block set".
- Decompiled behavior can be ambiguous.
- Generation determinism can regress accidentally.
- Networking must be designed before late-stage multiplayer integration.
- Heavy voxel generation should not become a large thread-unsafe GDScript loop.
- Visual similarity is not proof of behavioral parity.
- The engine binary is machine-local; only its fingerprint is committed.

## Session handoff rule

At the end of every task, keep this file to: current phase/milestone/task, completed
brick IDs, next 3–10 actions, blockers, changed files, test result, human-test result,
and only important technical notes. Do not paste large logs here.
