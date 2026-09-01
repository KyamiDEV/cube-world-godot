class_name WorldBounds
extends RefCounted
## The single authoritative voxel-space extent of the game world (backlog brick 050).
##
## This is a policy decision, not a reverse-engineered value —
## `docs/reference/traceability.md` §4 already confirmed no reference matrix cites
## 031-055, and the reference's own recovered `Zone`/`WorldMap` classes (`matrix-world.md`)
## carry no recovered world-size constant to draw on anyway. Values are round powers of
## two, the same style `DEFAULT_VIEW_DISTANCE`/`mesh_block_size` already use, chosen large
## enough to never be a real near-term constraint and small enough to be a deliberate,
## named choice rather than the engine's own "effectively unbounded" `VoxelTerrain.bounds`
## default (`AABB(-536870900, ..., 1073741800, ...)`, roughly `+-2^29` voxels — confirmed
## against upstream `VoxelTerrain.xml`, brick 045/§11).
##
## Horizontal (X/Z) and vertical (Y) extents are independent on purpose: a voxel RPG
## world is far wider than it is tall (bedrock to sky), matching this project's Y-up
## convention (`CLAUDE.md` §1) and `WorldScale`'s own axis treatment.
##
## Revisitable: this is a policy ceiling for the current single-`VoxelTerrain` baseline
## (039-049), not a commitment to a specific multi-region streaming architecture — Phase E
## (091-105, real `world/regions/`/`world/zones/`) may re-derive its own region grid inside
## this outer boundary without this file changing.
##
## Static-only: never instantiate.

## +-2^19 voxels = +-262144 m = +-262.144 km per horizontal axis.
const HALF_EXTENT_HORIZONTAL_VOXELS := 524288

## +-2^11 voxels = +-1024 m = +-1.024 km vertically — generous room for deep caves through
## tall terrain without matching the horizontal scale (nothing needs a 262 km tall column).
const HALF_EXTENT_VERTICAL_VOXELS := 2048


## The authoritative world extent, in voxel coordinates. Assign this directly to
## `VoxelTerrain.bounds` (`voxel_terrain_builder.gd`) — do not invent a second bounds
## value anywhere else.
static func aabb() -> AABB:
	return AABB(
		Vector3(-HALF_EXTENT_HORIZONTAL_VOXELS, -HALF_EXTENT_VERTICAL_VOXELS,
				-HALF_EXTENT_HORIZONTAL_VOXELS),
		Vector3(HALF_EXTENT_HORIZONTAL_VOXELS * 2.0, HALF_EXTENT_VERTICAL_VOXELS * 2.0,
				HALF_EXTENT_HORIZONTAL_VOXELS * 2.0))


## True when `voxel_position` is inside the authoritative world extent. Equivalent to
## `aabb().has_point(Vector3(voxel_position))`, offered as a named call for a caller that
## has no live `VoxelTerrain` to read `.bounds` from (e.g. a future Phase D generator or a
## server-side check ahead of building a terrain) — `block_edit_validator.gd` (045) already
## has a live terrain and keeps reading `terrain.bounds` directly, unchanged by this brick.
static func contains(voxel_position: Vector3i) -> bool:
	return aabb().has_point(Vector3(voxel_position))
