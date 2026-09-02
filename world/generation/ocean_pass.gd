class_name OceanPass
extends RefCounted
## Which columns count as ocean — the large, contiguous water coverage a river or a lake is
## not (backlog brick 083).
##
## `LakePass`'s own class comment (082, §21.8) named this brick in advance: "`LakePass`
## decides nothing about a large connected body of water, only isolated basins from the same
## channel field's tail — an ocean is a different shape." A river (081) and a lake (082) are
## both *rare, local* clips carved into lowland ground by the same 2D channel field, measured
## at 1.65% and 1.82% of the world respectively. An ocean is the opposite shape: not a carved
## feature at all, but wherever the ordinary, unclipped ground the whole terrain chain already
## produces happens to sit below the water plane `WaterLevel` (080) placed — roughly half the
## world (§19.2's own 49.5%–51.4% sweep), contiguous because a coastline is one connected
## shape in `ElevationField`'s own continentalness field, not a scatter of blobs.
##
## ```gdscript
## var ocean := OceanPass.for_world(GenerationHash.for_world(world_seed))
## if ocean.is_ocean_at(column):
##     var voxels_deep := ocean.ocean_depth_at(column)
## ```
##
## ```text
## is_ocean_at(column) = not (river.is_river_at(column) or lake.is_lake_at(column))
##                        and water.is_underwater_for(lake.surface_y(column))
## ```
##
## ## A pure combination, the same shape as `UndergroundMaterial` (079)
##
## `OceanPass` holds a `LakePass` (which already holds a `RiverPass`, which already holds a
## `TerracePass`) and a `WaterLevel`. No new noise layer, no new salt, no new constant — every
## number this brick needs already exists (`WaterLevel.SEA_LEVEL_VOXELS`, `RiverPass.
## is_river_at()`, `LakePass.is_lake_at()`), so, like `UndergroundMaterial` combining
## `CaveCarving` and `SubsurfaceMaterial` with nothing of its own to check, this file has no
## `self_check()` — there is no new relationship for one to assert.
##
## ## The exclusion always runs first, so it is what actually keeps the two apart
##
## A column already claimed by `RiverPass.is_river_at()` or `LakePass.is_lake_at()` never reads
## as ocean, whatever its own surface height is — those are named, local features with their
## own mechanism (a channel-noise contour), and giving the same column two labels would leave
## a later material brick (084) with no single answer for what covers it. This is not a rare
## edge case reached only in theory: measured over the same 2304-column sweep §19.2/§20.4/§21.3
## use, a real river column exists whose *raw, uncarved* `TerracePass` surface already sits
## below `WaterLevel.SEA_LEVEL_VOXELS` (a river genuinely running through land that was already
## low enough to be sea) — the exclusion is what keeps it reading as a river, not a second,
## unintended "ocean" label. `test_a_river_or_lake_column_never_reads_as_ocean_even_when_
## already_underwater` pins the case down with that exact column.
##
## Because the exclusion check always runs first and returns before the water-plane comparison
## is ever reached, *which* surface height that comparison reads against — `LakePass.
## surface_y()` or `RiverPass`/`TerracePass`'s own, unclipped one — makes no observable
## difference to `is_ocean_at()` today: wherever the comparison actually executes, the column
## is (by the exclusion having just passed) neither a river nor a lake, so `LakePass.
## surface_y()` and `TerracePass.surface_y()` agree there by definition. `is_ocean_at()` still
## reads `_lake.surface_y()` rather than reaching one layer further down to `_lake.river().
## terrace().surface_y()` — the same "read through the pass already held, don't reach around
## it" convention every composed pass in this chain follows — and it is the more defensive
## choice besides: if a future brick ever narrows the exclusion (a river mouth that empties
## into the sea counting as ocean at the columns where it does, say), reading the clipped
## surface is what makes that change local to the exclusion check rather than also requiring a
## second edit here.
##
## ## What this brick does not do
##
## No water block, no `VoxelGenerator` write, no shoreline or wet material — `SurfaceMaterial`/
## `SubsurfaceMaterial` (075–076) still decide what covers a column, and this file has no more
## business making that decision than `WaterLevel` did (§19.7's own precedent). Nothing
## downstream reads `OceanPass` yet; that wiring is 084's job, the same "the brick after the
## one that draws the shape" pattern `CaveCarving` (078) and `RiverPass`/`LakePass` (081, 082)
## already established for the mask they compose.
##
## ## Reference
##
## A case-insensitive grep of `reference/CubeWorld-Reversal` for "ocean" turns up one hit with
## content, in a different file than `Cave`'s and `Lake`'s own landmark table (`World.cpp`):
## `GameController_show_region_name` (`0x004e5320`, `cube/control/GameController.cpp`), which
## formats a displayed region name — `"Lands of <name>"`, or `L"Ocean"` when a queried zone's
## own field reads negative. Rated `[AUDIT] confidence: med`. This is the same "landmark/POI
## display label, not a generation mechanism" finding `CaveMask` (§16.5) and `LakePass` (§21.6)
## already recorded twice, in a third location this time — a region-naming heuristic, not a
## height or coverage computation. Read only far enough to answer this brick's one question (is
## there a coverage mechanism to diverge from); not traced further into the zone/region system
## either function reaches, which belongs to 089–090. There is nothing here to diverge from.
##
## Contract: `docs/world-generation.md` §22.

var _lake: LakePass
var _water: WaterLevel


func _init(p_lake: LakePass, p_water: WaterLevel) -> void:
	_lake = p_lake
	_water = p_water


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds ocean coverage to one world, or returns null (logged) when the binding is missing or
## either pass underneath it cannot be built. **The supported entry point.**
##
## Builds its own `LakePass` and `WaterLevel`, `TerracePass.for_world()`'s own reason repeated
## at every layer of this chain: both are stateless and small, and a shared instance would be
## a second way for two passes to disagree about which world they are generating.
static func for_world(p_hash: GenerationHash) -> OceanPass:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build the ocean pass without a world binding"):
		return null
	var bound_lake := LakePass.for_world(p_hash)
	if bound_lake == null:
		return null
	var bound_water := WaterLevel.for_world(p_hash)
	if bound_water == null:
		return null
	return OceanPass.new(bound_lake, bound_water)


# ---------------------------------------------------------------------------
# The classification
# ---------------------------------------------------------------------------

## True where the column is ordinary underwater coverage: not a river, not a lake, and its
## river-and-lake-clipped ground sits strictly below `WaterLevel.SEA_LEVEL_VOXELS`.
func is_ocean_at(column: Vector2i) -> bool:
	if is_river_or_lake_at(column):
		return false
	return _water.is_underwater_for(_lake.surface_y(column))


## True where `RiverPass` or `LakePass` already claims this column — the two named, local
## features `is_ocean_at()` excludes rather than double-labels. Exposed separately so a test,
## or a later brick, can ask the exclusion question on its own terms.
func is_river_or_lake_at(column: Vector2i) -> bool:
	return _lake.river().is_river_at(column) or _lake.is_lake_at(column)


## How many voxels of water stand over an ocean column: `0` everywhere `is_ocean_at()` is
## false (dry land, or a river/lake this pass leaves to its own mechanism), otherwise
## `WaterLevel.depth_for()` against the same clipped surface `is_ocean_at()` reads.
func ocean_depth_at(column: Vector2i) -> int:
	if not is_ocean_at(column):
		return 0
	return _water.depth_for(_lake.surface_y(column))


## The same answer at a voxel: Y is dropped, exactly as every field in this chain drops it for
## a column-only question (`WaterLevel.is_underwater_at_voxel()`, `LakePass.at_voxel()`).
func is_ocean_at_voxel(voxel: Vector3i) -> bool:
	return is_ocean_at(GenerationGrid.voxel_to_column(voxel))


## The same depth at a voxel, Y dropped for the same reason.
func ocean_depth_at_voxel(voxel: Vector3i) -> int:
	return ocean_depth_at(GenerationGrid.voxel_to_column(voxel))


# ---------------------------------------------------------------------------
# Shape of the pass
# ---------------------------------------------------------------------------

## The lake pass underneath, for a consumer that wants the river-and-lake-clipped surface
## directly, or its own `river()`/`terrace()` accessors further down. Read-only by convention:
## neither object this file holds is mutable.
func lake() -> LakePass:
	return _lake


## The river pass underneath `lake()`, exposed directly rather than making a caller write
## `ocean.lake().river()` for the one accessor `is_river_or_lake_at()` itself already needs.
func river() -> RiverPass:
	return _lake.river()


## The water plane this pass reads. Read-only by convention.
func water() -> WaterLevel:
	return _water
