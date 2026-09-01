class_name BlockRaycastService
extends RefCounted
## Basic block raycast interaction service (backlog brick 043).
##
## Wraps `VoxelToolTerrain.raycast()` (godot_voxel `doc/classes/VoxelTool.xml`, CLAUDE.md
## §15 source) and resolves the hit into a `BlockRaycastHit`: `raycast()` itself only
## returns a raw hit voxel position, with no concept of `BlockRegistry` or the `+1` air
## offset `blocky_library_builder.gd` (037) established for voxel values. This service is
## the one place that bridges the two, so no later caller (block edit command model, 044)
## re-derives the offset itself.
##
## No player/camera exists yet (Phase F, bricks 106-130), so `cast()` takes an explicit
## `origin`/`direction` ray rather than reading one from a camera — same "no scene wiring
## yet" scope 039-042 left open, carried forward again here.
##
## `collision_mask` is left at `VoxelTool.raycast()`'s own default (every bit set): a
## non-solid block's model already gets collision_mask `0` from `blocky_library_builder.gd`
## (037), so it can never match any mask and is already excluded — no extra filtering
## decision was needed for a "basic" raycast.

## Default max reach distance, in world/voxel units (`core/math/world_scale.gd` — 1 voxel
## = 0.5 m, so this is 5 m). Matches `VoxelTool.raycast()`'s own default (10.0) exactly,
## named here so it reads as a deliberate interaction-reach placeholder rather than an
## implicit reliance on the engine default. Real player reach balance is Phase F/G, and
## may replace this default outright rather than extend it.
const DEFAULT_MAX_DISTANCE := 10.0


## Casts a ray against `terrain` and resolves the hit through `registry`. Returns null
## when the ray hits nothing, or on a programmer/data error (logged via `Log.check`):
## an unlocked registry, a zero direction, a terrain with no voxel tool (mesher/generator
## not configured), or a hit voxel whose value the registry cannot resolve (air, or a
## value from a registry the terrain was not built from).
static func cast(terrain: VoxelTerrain, registry: BlockRegistry, origin: Vector3,
		direction: Vector3, max_distance: float = DEFAULT_MAX_DISTANCE) -> BlockRaycastHit:
	if not Log.check(registry.is_locked(), Log.CH_VOXEL,
			"block registry must be locked before raycasting"):
		return null
	if not Log.check(direction != Vector3.ZERO, Log.CH_VOXEL,
			"raycast direction must not be zero"):
		return null

	var tool := terrain.get_voxel_tool()
	if not Log.check(tool != null, Log.CH_VOXEL,
			"terrain did not produce a voxel tool (mesher/generator not configured?)"):
		return null

	var result := tool.raycast(origin, direction.normalized(), max_distance)
	if result == null:
		return null

	var network_index := tool.get_voxel(result.position) - 1  # 037's air offset
	var id := registry.id_from_network_index(network_index)
	if not Log.check(not id.is_empty(), Log.CH_VOXEL,
			"raycast hit a voxel with no registered block id", {
				"position": result.position, "network_index": network_index}):
		return null

	return BlockRaycastHit.new(id, result.position, result.previous_position,
			result.normal, result.distance)
