class_name BlockRaycastHit
extends RefCounted
## Result of a `BlockRaycastService.cast()` hit (backlog brick 043).
##
## Wraps Voxel Tools' own `VoxelRaycastResult` with the block id resolved through a
## `BlockRegistry` — a raw voxel value on its own is meaningless without the registry that
## assigned it (`BlockRegistry.network_index(id) + 1`, `blocky_library_builder.gd`, 037).

## The block kind that was hit, e.g. `"block.stone"`.
var block_id: String

## Integer voxel coordinates of the hit voxel — the block to interact with/mine.
var hit_position: Vector3i

## Integer voxel coordinates of the voxel just before the hit along the ray — where a new
## block would be placed on top of the hit one.
var placement_position: Vector3i

## Unit surface normal at the hit, pointing away from the struck face.
var normal: Vector3

## Distance in world/voxel units from the ray origin to the hit surface.
var distance: float


func _init(p_block_id: String, p_hit_position: Vector3i, p_placement_position: Vector3i,
		p_normal: Vector3, p_distance: float) -> void:
	block_id = p_block_id
	hit_position = p_hit_position
	placement_position = p_placement_position
	normal = p_normal
	distance = p_distance
