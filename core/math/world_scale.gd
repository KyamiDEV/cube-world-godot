class_name WorldScale
extends RefCounted
## The single place where the world's unit system is defined (backlog brick 013).
##
## The rule (`CLAUDE.md` §1): **1 voxel = 0.5 m**, **1 m = 2 units**, Y-up.
##
## Three coordinate spaces exist, and confusing them is the bug this class exists to
## prevent:
##
## | Space | Type | Unit | Used by |
## |---|---|---|---|
## | metres | `float` / `Vector3` | 1 m | design values: a 1.8 m creature, a 4 m/s run |
## | world units | `float` / `Vector3` | 0.5 m | everything Godot touches: nodes, physics, raycasts |
## | voxel coordinates | `int` / `Vector3i` | one cell | terrain data, edits, generation, persistence |
##
## One world unit is exactly one voxel cell, because Voxel Tools meshes LOD0 at one
## voxel per unit. That identity is asserted by the tests; it is the reason a Godot
## position can be floored straight into a voxel coordinate.
##
## Design values are written in metres and converted here. A bare `0.5` or `2.0` in
## gameplay, world or client code is a bug — the conversion belongs in this file and
## nowhere else.
##
## Static-only: never instantiate.

## Edge length of one voxel, in metres.
const METRES_PER_VOXEL := 0.5

## Voxels along one metre.
const VOXELS_PER_METRE := 2.0

## Godot world units per voxel cell. Voxel Tools meshes LOD0 at 1:1, so changing this
## would mean rescaling the terrain node itself — it is a constant, not a setting.
const UNITS_PER_VOXEL := 1.0

## Godot world units per metre. Derived, stated once, used everywhere.
const UNITS_PER_METRE := VOXELS_PER_METRE * UNITS_PER_VOXEL

## Metres per Godot world unit.
const METRES_PER_UNIT := METRES_PER_VOXEL / UNITS_PER_VOXEL

## Volume of one voxel in cubic metres. Useful for density and mass tuning.
const CUBIC_METRES_PER_VOXEL := METRES_PER_VOXEL * METRES_PER_VOXEL * METRES_PER_VOXEL


# ---------------------------------------------------------------------------
# Metres <-> world units
# ---------------------------------------------------------------------------

## Design value in metres -> Godot world units. `WorldScale.m(1.8)` is the short form.
static func metres_to_units(metres: float) -> float:
	return metres * UNITS_PER_METRE


static func units_to_metres(units: float) -> float:
	return units * METRES_PER_UNIT


static func metres_to_units_v(metres: Vector3) -> Vector3:
	return metres * UNITS_PER_METRE


static func units_to_metres_v(units: Vector3) -> Vector3:
	return units * METRES_PER_UNIT


## Short alias for literal design values, so a scene or system reads as
## `WorldScale.m(1.8)` rather than a bare number times a factor.
static func m(metres: float) -> float:
	return metres * UNITS_PER_METRE


## Speeds and accelerations scale by the same linear factor: m/s -> units/s,
## m/s² -> units/s². Named separately because the call site reads better and because
## it documents that no per-second term is involved.
static func mps_to_ups(metres_per_second: float) -> float:
	return metres_per_second * UNITS_PER_METRE


static func ups_to_mps(units_per_second: float) -> float:
	return units_per_second * METRES_PER_UNIT


# ---------------------------------------------------------------------------
# World position <-> voxel coordinate
# ---------------------------------------------------------------------------

## World position -> the voxel cell containing it.
##
## Floor, never truncation: at x = -0.5 the containing cell is -1, and truncation would
## give 0. Getting this wrong makes generation and edits asymmetric around the origin —
## a determinism bug that only shows up in negative coordinates.
static func world_to_voxel(position: Vector3) -> Vector3i:
	return Vector3i(
		floori(position.x / UNITS_PER_VOXEL),
		floori(position.y / UNITS_PER_VOXEL),
		floori(position.z / UNITS_PER_VOXEL))


static func world_to_voxel_axis(units: float) -> int:
	return floori(units / UNITS_PER_VOXEL)


## Voxel coordinate -> world position of its minimum corner (the origin of the cell).
## This is the anchor Voxel Tools and blocky models use.
static func voxel_to_world_min(voxel: Vector3i) -> Vector3:
	return Vector3(voxel) * UNITS_PER_VOXEL


## Voxel coordinate -> world position of the cell's centre. Use this to place a prop or
## an effect inside a block, never `voxel_to_world_min`.
static func voxel_to_world_centre(voxel: Vector3i) -> Vector3:
	return (Vector3(voxel) + Vector3(0.5, 0.5, 0.5)) * UNITS_PER_VOXEL


## World position -> minimum corner of the voxel containing it. Equivalent to
## `voxel_to_world_min(world_to_voxel(position))`, without the round trip.
static func snap_to_voxel_min(position: Vector3) -> Vector3:
	return voxel_to_world_min(world_to_voxel(position))


static func snap_to_voxel_centre(position: Vector3) -> Vector3:
	return voxel_to_world_centre(world_to_voxel(position))


# ---------------------------------------------------------------------------
# Metres <-> voxels
# ---------------------------------------------------------------------------

## Metres -> voxel count as a real number (0.75 m -> 1.5 voxels). Round deliberately at
## the call site; this function will not choose for you.
static func metres_to_voxels(metres: float) -> float:
	return metres * VOXELS_PER_METRE


static func voxels_to_metres(voxels: float) -> float:
	return voxels * METRES_PER_VOXEL


## Metres -> the number of whole voxels needed to cover that distance. Rounds up, so a
## 1.7 m tall creature occupies 4 voxels of clearance rather than 3.
static func metres_to_voxels_ceil(metres: float) -> int:
	return ceili(metres * VOXELS_PER_METRE)


# ---------------------------------------------------------------------------
# Regions
# ---------------------------------------------------------------------------

## Inclusive voxel bounds covering a world-space AABB. Both corners are voxels that the
## box actually touches, so callers can iterate `min..max` inclusively.
static func aabb_to_voxel_bounds(box: AABB) -> Array[Vector3i]:
	var start := world_to_voxel(box.position)
	# `end` is exclusive in world space; a box ending exactly on a boundary must not
	# claim the next cell, so step back by one unit-epsilon-free trick: floor(end) and
	# drop a cell when the box ends exactly on that plane.
	var raw_end := box.position + box.size
	var last := Vector3i(
		_last_touched_axis(raw_end.x),
		_last_touched_axis(raw_end.y),
		_last_touched_axis(raw_end.z))
	last = Vector3i(maxi(last.x, start.x), maxi(last.y, start.y), maxi(last.z, start.z))
	return [start, last]


static func _last_touched_axis(end_units: float) -> int:
	var cell := floori(end_units / UNITS_PER_VOXEL)
	# Ending exactly on a cell boundary touches the cell before it, not the one starting
	# there.
	if is_equal_approx(float(cell) * UNITS_PER_VOXEL, end_units):
		return cell - 1
	return cell
