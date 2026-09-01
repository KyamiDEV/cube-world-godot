class_name VoxelTerrainMetrics
extends RefCounted
## Named, typed access to Voxel Tools' own debug statistics (backlog brick 051).
##
## Scope: this brick claims exactly one thing — a single shared place to read the two
## debug-statistics dictionaries Voxel Tools 1.7 already exposes, per the same
## "scale conversion belongs in one shared utility" rule `CLAUDE.md` §1 gives
## `core/math/world_scale.gd` and `world_bounds.gd` (050) already followed for their own
## constants. Without this, bricks 052-055 (mesh block size 16/32 benchmarks, choosing a
## size, documenting the performance budget) would each invent their own dictionary-key
## string literals against the same two engine dictionaries. No new measurement is taken
## here — both dictionaries are the engine's own counters, read as-is.
##
## Not reverse-engineered: `docs/reference/traceability.md` §4 already confirmed no
## reference matrix cites 031-055. Both key sets were checked against the actual C++
## source (`terrain/fixed_lod/voxel_terrain.cpp`'s `_b_get_statistics()`,
## `engine/voxel_engine_gd.cpp`'s `VoxelEngine::get_stats()` binding, `godot_voxel`
## reference repo, tag `v1.7`, fetched this brick) — **not just the XML doc**, since the
## two disagree for the terrain dictionary: `doc/classes/VoxelTerrain.xml` additionally
## documents `time_process_update_responses` and `remaining_main_thread_blocks`, but
## `_b_get_statistics()`'s actual body never sets either key (confirmed empirically too —
## this project's own headless test run never observes them). This file's `KEY_*`
## constants list only the 7 keys the source code really populates. `VoxelEngine.get_stats()`
## has no such discrepancy — its doc and `to_dict()` implementation agree.
## `dropped_block_meshs` keeps the engine's own misspelling, since the constant must match
## the live dictionary key exactly.
##
## `VoxelEngine` (confirmed via its own `brief_description`, "Singleton holding common
## settings and handling voxel processing tasks in background threads") is called directly
## by class name, the same way `OS`/`Input` are — no `.new()`, no `Engine.get_singleton()`
## lookup needed.
##
## Static-only: never instantiate.

# ---------------------------------------------------------------------------
# VoxelTerrain.get_statistics() keys
# ---------------------------------------------------------------------------

const KEY_TIME_DETECT_REQUIRED_BLOCKS := "time_detect_required_blocks"
const KEY_TIME_REQUEST_BLOCKS_TO_LOAD := "time_request_blocks_to_load"
const KEY_TIME_PROCESS_LOAD_RESPONSES := "time_process_load_responses"
const KEY_TIME_REQUEST_BLOCKS_TO_UPDATE := "time_request_blocks_to_update"
const KEY_DROPPED_BLOCK_LOADS := "dropped_block_loads"
## Engine's own spelling — must match `terrain_snapshot()`'s live dictionary key exactly.
const KEY_DROPPED_BLOCK_MESHES := "dropped_block_meshs"
const KEY_UPDATED_BLOCKS := "updated_blocks"

# ---------------------------------------------------------------------------
# VoxelEngine.get_stats() keys (top-level; the value at each is itself a Dictionary)
# ---------------------------------------------------------------------------

const KEY_THREAD_POOLS := "thread_pools"
const KEY_TASKS := "tasks"
const KEY_MEMORY_POOLS := "memory_pools"


## `terrain.get_statistics()`, validated. Returns `{}` (and logs why) for a null
## `terrain` instead of letting the engine call fail — the same defensive-return shape
## every other `world/terrain/*.gd` static helper already uses.
static func terrain_snapshot(terrain: VoxelTerrain) -> Dictionary:
	if not Log.check(terrain != null, Log.CH_VOXEL,
			"cannot snapshot statistics from a null VoxelTerrain"):
		return {}
	return terrain.get_statistics()


## `VoxelEngine.get_stats()` — global, shared across every terrain, not specific to one.
static func engine_snapshot() -> Dictionary:
	return VoxelEngine.get_stats()


## Emits `terrain_snapshot()` as one structured log line (`Log.debug`, `Log.CH_VOXEL` by
## default) — the actual "hook" a benchmark brick (052-055) or a manual profiling session
## calls per sample, instead of formatting the dictionary itself each time. Emits nothing
## for a null `terrain` (`terrain_snapshot()` already logged the reason).
static func log_terrain_snapshot(terrain: VoxelTerrain, channel: String = Log.CH_VOXEL) -> void:
	var stats := terrain_snapshot(terrain)
	if stats.is_empty():
		return
	Log.debug(channel, "voxel terrain statistics", stats)
