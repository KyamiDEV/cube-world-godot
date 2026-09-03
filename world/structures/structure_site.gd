class_name StructureSite
extends RefCounted
## One resolved structure: where it stands, how big it is, and the ground plane it sits on
## (backlog brick 091).
##
## `StructureSeed` (089) is the reproducible *input* — a region, a jittered anchor column and
## an opaque 64-bit sub-seed. `StructurePlacement` (090) decides which of those candidates is
## real. This record is the next step and the first one that describes a *thing*: the
## candidate's own stream resolved into a footprint, a wall height and the terrace plane the
## structure's floor sits on.
##
## | Field | Where it comes from |
## |---|---|
## | `region`, `anchor_column`, `structure_seed` | carried straight from the placed `StructureSeed` (089) |
## | `base_y` | `TerracePass.surface_y(anchor_column)` — **not** drawn: the ground plane 090's slope gate already checked is level across the pad |
## | `half_extent_voxels` | draw 1 of the site stream |
## | `wall_height_voxels` | draw 2 of the site stream |
##
## ```gdscript
## var site := generator.site_at(region)          # null unless a structure stands there
## if site != null and site.contains_column(column):
##     ...
## ```
##
## ## The footprint is a centred odd square, and the distance metric is Chebyshev
##
## The footprint is every column within `half_extent_voxels` of the anchor **in Chebyshev
## distance** — `max(|dx|, |dz|)`, the metric whose unit ball is a square. A blocky world
## builds squares, and using the metric the shape is actually made of means
## `contains_column()` is exact rather than an approximation of a circle drawn on a grid. The
## side is `2·half_extent_voxels + 1`, always odd, so the anchor column is the true centre and
## the structure has no ambiguous half-voxel offset.
##
## ## `base_y` is read, not rolled
##
## A structure's floor height is not a free choice: it is the ground. `StructurePlacement`
## already refused every anchor whose terraced surface spans more than one terrace across a
## 16-voxel pad (§29.3), so the terrace plane at the anchor is a plane the whole footprint can
## legitimately sit on — and `StructureGenerator.ground_falloff_at()` levels the remainder.
## Drawing a height instead would either float the structure or bury it, and would make 090's
## slope gate decorative.
##
## ## No rotation draw
##
## A centred square ring is invariant under quarter turns, so a rotation drawn here would be a
## number nothing reads — the "record grows, nothing reads it" shape this project has refused
## since brick 067 (`docs/world-generation.md` §12.3, §29.4). Brick 092's house has a door and
## an asymmetric interior and genuinely needs one; it appends the draw at the **end** of the
## site stream, which §28.4's draw-order rule makes free.
##
## Contract: `docs/world-generation.md` §30.

## The region grid cell this structure belongs to (its `StructureSeed.region`).
var region: Vector2i

## The world column the structure is centred on (its `StructureSeed.anchor_column`).
var anchor_column: Vector2i

## The voxel plane the floor occupies, in voxels above the datum. Always an exact multiple of
## `TerracePass.TERRACE_HEIGHT_VOXELS` — it *is* a terrace plane, read from `TerracePass` at
## the anchor rather than drawn.
var base_y: int

## Half-width of the square footprint, in voxels; the footprint side is `2·this + 1`.
var half_extent_voxels: int

## How far the walls rise above `base_y`, in voxels. The wall ring occupies
## `base_y + 1 .. base_y + wall_height_voxels`.
var wall_height_voxels: int

## The 64-bit seed this structure and everything under it derives from — 089's opaque
## sub-seed, carried unchanged so a later brick (092+) can fork its own named stream from the
## same parent without going back to the seed field.
var structure_seed: int


func _init(p_region: Vector2i, p_anchor_column: Vector2i, p_base_y: int,
		p_half_extent_voxels: int, p_wall_height_voxels: int, p_structure_seed: int) -> void:
	region = p_region
	anchor_column = p_anchor_column
	base_y = p_base_y
	half_extent_voxels = p_half_extent_voxels
	wall_height_voxels = p_wall_height_voxels
	structure_seed = p_structure_seed


# ---------------------------------------------------------------------------
# The footprint
# ---------------------------------------------------------------------------

## Chebyshev distance from the anchor to a world column, in voxels — `max(|dx|, |dz|)`. The
## metric the square footprint is actually made of; every extent question below is a
## comparison against this one number.
func distance_to_column(column: Vector2i) -> int:
	var delta := column - anchor_column
	return maxi(absi(delta.x), absi(delta.y))


## True when `column` is under the structure's floor slab.
func contains_column(column: Vector2i) -> bool:
	return distance_to_column(column) <= half_extent_voxels


## True when `column` is on the wall ring — the outermost band of the footprint.
func is_wall_column(column: Vector2i) -> bool:
	return distance_to_column(column) == half_extent_voxels


## Side length of the square footprint, in voxels: `2·half_extent_voxels + 1`, always odd.
func footprint_side_voxels() -> int:
	return 2 * half_extent_voxels + 1


## The lowest-coordinate corner of the footprint, inclusive.
func footprint_min() -> Vector2i:
	return anchor_column - Vector2i(half_extent_voxels, half_extent_voxels)


## The highest-coordinate corner of the footprint, inclusive.
func footprint_max() -> Vector2i:
	return anchor_column + Vector2i(half_extent_voxels, half_extent_voxels)


## The topmost voxel plane the walls reach.
func top_y() -> int:
	return base_y + wall_height_voxels


## Side length of the footprint in metres, for a log line or a design note. Never for
## generation arithmetic — that stays in voxels, where the numbers are exact.
func footprint_side_metres() -> float:
	return WorldScale.voxels_to_metres(float(footprint_side_voxels()))


# ---------------------------------------------------------------------------
# Streams
# ---------------------------------------------------------------------------

## A fresh stream owned by this structure, forked from the same 64-bit sub-seed
## `StructureSeed.rng()` returns. Identical to the seed record's stream by construction: this
## record carries the sub-seed rather than a stream, so every consumer forks its own named
## child (`docs/rng.md` §5) and none can shift another's draws.
func rng() -> DeterministicRng:
	return DeterministicRng.from_seed(structure_seed)


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

## Empty string when this record is internally coherent, otherwise the reason — the project's
## `validate()` convention, and `StructureSeed.validate()`'s own shape one level up. Checks
## the invariants a consumer relies on: the anchor belongs to its region, the extents are
## positive, and the floor sits on a real terrace plane.
func validate() -> String:
	if not GenerationGrid.is_region_in_world(region):
		return "region %s is outside the region grid" % region
	if GenerationGrid.column_to_region(anchor_column) != region:
		return "anchor column %s is not inside region %s" % [anchor_column, region]
	if half_extent_voxels <= 0:
		return "half extent %d is not positive" % half_extent_voxels
	if wall_height_voxels <= 0:
		return "wall height %d is not positive" % wall_height_voxels
	if base_y % TerracePass.TERRACE_HEIGHT_VOXELS != 0:
		return "base y %d is not a terrace plane (multiple of %d)" % [
				base_y, TerracePass.TERRACE_HEIGHT_VOXELS]
	return ""


func _to_string() -> String:
	return "StructureSite(region=%s anchor=%s base_y=%d side=%d height=%d)" % [
			region, anchor_column, base_y, footprint_side_voxels(), wall_height_voxels]
