class_name WaterLevel
extends RefCounted
## Where the water plane sits, and which columns it covers (backlog brick 080).
##
## `ElevationField` (061) and `TerracePass` (063) both said, in their own class comments,
## that they decide nothing about water: `y = 0` is a datum, not a sea level, and "which
## part of the rock is underwater is a separate constant applied to the same numbers" —
## kept separate specifically so this brick can move the waterline without regenerating a
## single column. This file is that constant, plus the two queries every consumer of it
## actually needs: is a column's ground above or below the plane, and by how much.
##
## ```gdscript
## var water := WaterLevel.for_world(GenerationHash.for_world(world_seed))
## if water.is_underwater_at(column):
##     var voxels_deep := water.depth_at(column)
## ```
##
## ## The plane is a constant, not a field
##
## Every noise-backed pass so far (`Continentalness`, the two climate fields, `CaveMask`)
## earns its own layer because *where* the thing varies is the question. A sea level does
## not: one plane for the whole world is what makes "the coast" a place a column's own
## terraced height can cross, rather than a second surface that would itself need shaping,
## eroding and terracing before it meant anything. `ElevationField.SHORE_MIDPOINT`/
## `SHORE_WIDTH` already carved the coastline's *shape* into the continentalness field
## (§6.3); this brick only has to say how high the water stands against it.
##
## ## Why `0`
##
## `y = 0` is already `TerracePass`'s own datum and — because `TERRACE_HEIGHT_VOXELS` (8)
## divides it — already an exact terrace plane, so no column's ground can straddle it: a
## column's terraced surface either sits at or above `y = 0` (dry) or strictly below it
## (underwater), never half of one shelf on each side. It is also the measured best of the
## only candidates a terrace-aligned plane offers nearby: over the same 2304-column sweep
## `docs/world-generation.md` §6.6/§7.5 use, against `TerracePass`'s *terraced* output (the
## actual block-world surface, not the continuous height those two sections measured),
## candidate sea levels of `-8`, `0` and `+8` voxels split the world `49.5/50.5`,
## `50.2/49.8` and `51.4/48.6` (underwater/land) — `0` is the closest of the three to an
## even split, and it is also the only one of them that needed no new number at all: it is
## the datum every other pass in this project already agreed on. §7.5's own finding — the
## erosion pass alone already put `49.8%` of columns below the datum, "not a statement
## about sea level" at the time — turns out to describe almost exactly the plane this brick
## picks.
##
## ## What this brick does not do
##
## No water block, no `VoxelGenerator` write, no shoreline material, no river or lake
## carving into the ground `TerracePass` already computed. Those are 081–084: a river or a
## lake is a *local* lowering of a column's own terrain below this plane, and "what covers
## a submerged column" is a material decision this file has no more business making than
## `CaveMask` had deciding what lines a cave (§16.2's own precedent). This is the plane
## alone, and the two questions — is a column under it, and by how much — that every one of
## those later bricks needs answered the same way.
##
## ## Reference
##
## `World_waterDepthField` (`0x0052d990`, `docs/reference/terrain-base-height-field.md`
## §1's own forward pointer to 080) was read for this brick. Despite its name, its body
## computes a chunk-type-gated *temperature* modulation — cosine terms over noise, folded
## against a moisture value from `World_roadField` — and never derives, reads or returns a
## height or a depth; the decompiler's own header rates it `confidence: low` and recovers
## no return value at all. It is not a water level model, named or otherwise, and there is
## nothing in it to diverge from. `World::waterProximityInfluence` (`0x00522e20`), the one
## other water-named function reached from it, is a per-region-grid falloff scan folded
## into a road/feature field, not a sea-level plane either. `docs/reference/
## terrain-base-height-field.md` §3 claim 10 records this reading.
##
## Contract: `docs/world-generation.md` §19.

## Height of the water plane, in voxels above the datum. See the class comment for why `0`.
## An exact terrace plane by construction (`self_check()` asserts it stays one), so a
## column's terraced surface is never split by it.
const SEA_LEVEL_VOXELS := 0

var _terrace: TerracePass


func _init(p_terrace: TerracePass) -> void:
	_terrace = p_terrace


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds the water plane to one world, or returns null (logged) when the binding is missing
## or the pass underneath it cannot be built. **The supported entry point.**
##
## Builds its own `TerracePass`, `TerracePass.for_world()`'s own reason repeated at every
## layer of this chain: the object is stateless and small, and a shared instance would be a
## second way for two passes to disagree about which world they are generating.
static func for_world(p_hash: GenerationHash) -> WaterLevel:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build the water level without a world binding"):
		return null
	var bound_terrace := TerracePass.for_world(p_hash)
	if bound_terrace == null:
		return null
	return WaterLevel.new(bound_terrace)


# ---------------------------------------------------------------------------
# The plane
# ---------------------------------------------------------------------------

## True where the column's terraced ground sits strictly below the water plane. A column
## whose surface sits exactly at `SEA_LEVEL_VOXELS` reads dry — the waterline itself is
## shore, not water — the same strict-inequality convention `CaveCarving.is_hollow_at()`
## draws at a column's own surface (§17's `voxel.y < surface_y(column)`, applied here to the
## plane instead of a voxel).
func is_underwater_at(column: Vector2i) -> bool:
	return is_underwater_for(_terrace.surface_y(column))


## How many voxels of water stand over the column's ground: `0` on dry land, otherwise
## `SEA_LEVEL_VOXELS - surface_y(column)`. Never negative.
func depth_at(column: Vector2i) -> int:
	return depth_for(_terrace.surface_y(column))


## The boundary itself, for a terrace surface height rather than a column: `true` strictly
## below `SEA_LEVEL_VOXELS`, `false` at or above it.
##
## Static, and separate from `is_underwater_at()`, for `ElevationField.shore_weight()`'s own
## reason: a test that wants to know what happens exactly on the plane or exactly below it
## should not have to hunt the world for a column whose terraced surface happens to land
## there.
static func is_underwater_for(surface_y: int) -> bool:
	return surface_y < SEA_LEVEL_VOXELS


## The depth itself, for a terrace surface height rather than a column. Static for the same
## reason as `is_underwater_for()`.
static func depth_for(surface_y: int) -> int:
	return maxi(0, SEA_LEVEL_VOXELS - surface_y)


## The same answer at a voxel: Y is dropped, exactly as every field in this chain drops it
## for a column-only question (`ElevationField.at_voxel()`, `TerracePass.at_voxel()`).
func is_underwater_at_voxel(voxel: Vector3i) -> bool:
	return is_underwater_at(GenerationGrid.voxel_to_column(voxel))


## The same depth at a voxel, Y dropped for the same reason.
func depth_at_voxel(voxel: Vector3i) -> int:
	return depth_at(GenerationGrid.voxel_to_column(voxel))


## The water plane in metres, for a log line, a design note or a debug overlay. Never for
## generation arithmetic — that stays in voxels, `ElevationField.at_metres()`'s own reason.
static func sea_level_metres() -> float:
	return WorldScale.voxels_to_metres(float(SEA_LEVEL_VOXELS))


# ---------------------------------------------------------------------------
# Shape of the pass
# ---------------------------------------------------------------------------

## The terrace pass underneath, for a consumer that wants the raw surface height with no
## water plane applied. Read-only by convention: neither object this file holds is mutable.
func terrace() -> TerracePass:
	return _terrace


# ---------------------------------------------------------------------------
# Self-check
# ---------------------------------------------------------------------------

## Empty string when `SEA_LEVEL_VOXELS` still is an exact terrace plane inside
## `TerracePass`'s own range, otherwise the reason. Same shape and purpose as `CaveMask.
## self_check()`/`SubsurfaceMaterial.self_check()`: the relationship is claimed in the class
## comment and asserted here rather than trusted from it.
static func self_check() -> String:
	if SEA_LEVEL_VOXELS % TerracePass.TERRACE_HEIGHT_VOXELS != 0:
		return "SEA_LEVEL_VOXELS (%d) is not an exact multiple of TERRACE_HEIGHT_VOXELS (%d)" % [
				SEA_LEVEL_VOXELS, TerracePass.TERRACE_HEIGHT_VOXELS]
	if SEA_LEVEL_VOXELS < TerracePass.MINIMUM_VOXELS or SEA_LEVEL_VOXELS > TerracePass.MAXIMUM_VOXELS:
		return "SEA_LEVEL_VOXELS (%d) is outside TerracePass's own range [%d, %d]" % [
				SEA_LEVEL_VOXELS, int(TerracePass.MINIMUM_VOXELS), int(TerracePass.MAXIMUM_VOXELS)]
	return ""
