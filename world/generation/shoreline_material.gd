class_name ShorelineMaterial
extends RefCounted
## Which block covers a dry column immediately next to water (backlog brick 084).
##
## `OceanPass` (083, itself holding `LakePass`/`RiverPass`/`WaterLevel`) already answers
## "is this column wet"; `SurfaceMaterial` (075) already answers "what covers an ordinary
## dry column". Neither says anything about the columns *between* the two — the beach a
## coastline, riverbank or lakeshore actually has. This file is where those two meet: a
## column already wet keeps whatever `OceanPass` says about it (still nothing — no water
## material exists yet, §22.5/§22.8's own boundary, unmoved by this brick); a dry column
## touching one reads a fixed shore block instead of its biome's ordinary ground.
##
## ```gdscript
## var shoreline := ShorelineMaterial.for_world(hash, biomes, blocks)
## var block_id := shoreline.block_id_at(column)   # "block.sand" at the water's edge
## ```
##
## ## Adjacency, defined for the first time in this project
##
## Nothing before this brick has asked "what is next to this column" — every earlier field
## is a pure function of one column's own coordinates. `is_shoreline_at()` is deliberately
## the narrowest reading of "immediately adjacent" available: the four columns one voxel
## away sharing an edge (`Vector2i(±1, 0)`, `Vector2i(0, ±1)`), not the eight sharing a
## corner too. Two reasons, not one:
##
## 1. **Cost.** Each neighbour check is `OceanPass.is_ocean_at()` or `is_river_or_lake_at()`,
##    which pays for the whole `Continentalness` -> `ElevationField` -> `ErosionPass` ->
##    `TerracePass` chain (or a channel-noise lookup) per call. Four calls per column is
##    already four times the cost of every earlier per-column field; eight would be twice
##    that again for a case — a beach block missing at a purely diagonal water corner — a
##    blocky world tolerates far better than a smooth one would.
## 2. **Nothing downstream needs the wider answer yet.** No `VoxelGenerator` reads this file
##    (§ below), so there is no measured artifact today the corner case would visibly cause.
##    Widening to eight neighbours, or to a multi-voxel band, is a cheap, local change to
##    `_NEIGHBOR_OFFSETS`/`is_shoreline_at()` alone if a future brick's own consumer asks
##    for it — not invented here ahead of one that does.
##
## A column that is itself wet is never a shoreline column, whatever its neighbours are —
## `is_water_at()` is checked first and short-circuits, the same "exclusion first" shape
## `OceanPass.is_ocean_at()` already established for its own three-way split.
##
## ## One fixed block, not a per-biome field
##
## `BiomeDefinition`'s own class comment (067) once listed "water, shoreline, snowline,
## altitude bands" together as fields a later brick might add. Every water-adjacent brick
## since has landed the other way: `WaterLevel` (080) added a bare constant, `OceanPass`
## (083) added no field at all, and this brick follows the same line rather than breaking
## it — `SHORE_BLOCK_ID` is one constant (`block.sand`, already shipped by 075 for the
## desert biome) covering every shoreline column regardless of which biome's ground it
## interrupts. No consumer anywhere distinguishes a snowy shore from a sandy one; a field
## for that distinction would be exactly the "record grows, nothing reads it" shape 067
## already named four times (§12.3, §14.6, §15.2, §16.7) — `SubsurfaceMaterial.
## DEEP_BLOCK_ID`'s own precedent, one layer up instead of one layer down.
##
## No new block, either: `block.sand` already exists, so this brick adds nothing to
## `data/blocks/` and needs no `tools/generators` pass.
##
## ## A pure combination, the same shape as `UndergroundMaterial`/`OceanPass`
##
## `ShorelineMaterial` holds an `OceanPass` and a `SurfaceMaterial`, both built fresh in
## `for_world()` rather than shared (`TerracePass.for_world()`'s own recurring reason). No
## new noise layer, no new salt — `_NEIGHBOR_OFFSETS` is a fixed geometric constant, not a
## hashed one, so there is nothing for a `self_check()` to assert, `OceanPass`'s own
## precedent for a pure combinator.
##
## ## Reference
##
## A case-insensitive grep of `reference/CubeWorld-Reversal` for "shore" turns up nothing at
## all; "beach" turns up exactly two hits, both in the same landmark/prop name-to-id map
## `Cave`, `Lake` and `Ocean` were already found in (`server/world/World.cpp`):
## `L"BeachUmbrella"` and `L"BeachTowel"`, furniture item names with no generation mechanism
## anywhere near them. The same "landmark/prop label, not a coverage computation" finding
## `CaveMask` (§16.5), `LakePass` (§21.6) and `OceanPass` (§22.6) already recorded three
## times, a fourth time here for a different label pair. There is nothing to diverge from.
##
## ## What this brick does not do
##
## No water block, no `VoxelGenerator` write — the same boundary every Phase D brick since
## `WaterLevel` (080) has held. `block_id_at()` never asks whether its own column is wet; a
## column `OceanPass` already calls ocean, river or lake keeps reading through that pass
## exactly as it did before this brick existed, because nothing yet says what a wet column
## looks like. Snowline (085), decoration (086-088) and a narrower or wider shore band are
## all future brick's business, not this one's.
##
## Contract: `docs/world-generation.md` §23.

## The block every shoreline column reads, regardless of biome. See the class comment for
## why this is a constant and not a per-biome field.
const SHORE_BLOCK_ID := "block.sand"

## The four columns sharing an edge with this one — Von Neumann adjacency, not Moore. See
## the class comment for why corners are excluded.
const _NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

var _ocean: OceanPass
var _surface: SurfaceMaterial


func _init(p_ocean: OceanPass, p_surface: SurfaceMaterial) -> void:
	_ocean = p_ocean
	_surface = p_surface


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds shoreline material selection to one world and one loaded content set, or returns
## null (logged) when any piece cannot be built or the block registry has no
## `SHORE_BLOCK_ID` record. **The supported entry point.**
##
## Builds its own `OceanPass` and `SurfaceMaterial` — `TerracePass.for_world()`'s own reason
## repeated once more: both are stateless and small, and a shared instance would be a second
## way for two passes to disagree about which world they are generating.
## `SurfaceMaterial.for_world()` already validates `biomes`/`blocks` locking, the biome
## catalog's own `self_check()`, and every `surface_block_id`; this adds the one check that
## is 084's own.
static func for_world(p_hash: GenerationHash, p_biomes: BiomeRegistry,
		p_blocks: BlockRegistry) -> ShorelineMaterial:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build shoreline material selection without a world binding"):
		return null
	if not Log.check(shore_block_reason_for(p_blocks).is_empty(), Log.CH_GEN,
			"block registry has no record for the fixed shoreline block",
			{"reason": shore_block_reason_for(p_blocks)}):
		return null
	var bound_surface := SurfaceMaterial.for_world(p_hash, p_biomes, p_blocks)
	if bound_surface == null:
		return null
	var bound_ocean := OceanPass.for_world(p_hash)
	if bound_ocean == null:
		return null
	return ShorelineMaterial.new(bound_ocean, bound_surface)


## Empty string when `blocks` has a record for `SHORE_BLOCK_ID`, otherwise the reason.
## `SubsurfaceMaterial.subsurface_block_reason_for()`'s exact shape for its own
## `DEEP_BLOCK_ID` check, one constant instead of a per-biome loop because this brick has
## no per-biome field to loop over.
static func shore_block_reason_for(p_blocks: BlockRegistry) -> String:
	if p_blocks == null or not p_blocks.has_block(SHORE_BLOCK_ID):
		return "block registry has no record for '%s', the fixed shoreline block" % SHORE_BLOCK_ID
	return ""


# ---------------------------------------------------------------------------
# The classification
# ---------------------------------------------------------------------------

## True where `OceanPass` already claims this column, wet by any of its three mechanisms
## (ocean, river or lake). Exposed separately, `OceanPass.is_river_or_lake_at()`'s own
## reason: a test, or a later brick, can ask "is this column water" on its own terms
## without reaching into `OceanPass` for two separate calls each time.
func is_water_at(column: Vector2i) -> bool:
	return _ocean.is_ocean_at(column) or _ocean.is_river_or_lake_at(column)


## True where the column is dry but shares an edge with one that is wet. A wet column is
## never a shoreline column itself — checked first, so it always wins over whatever its own
## neighbours are, the same "exclusion first" shape `OceanPass.is_ocean_at()` already uses
## for its own river/lake split.
func is_shoreline_at(column: Vector2i) -> bool:
	if is_water_at(column):
		return false
	for offset in _NEIGHBOR_OFFSETS:
		if is_water_at(column + offset):
			return true
	return false


## The block id covering `column`: `SHORE_BLOCK_ID` at the water's edge, otherwise whatever
## `SurfaceMaterial` already says there — including at a column `OceanPass` itself calls
## water, where this file has no more business overriding the answer than `OceanPass` did
## (see the class comment's "what this brick does not do").
func block_id_at(column: Vector2i) -> String:
	if is_shoreline_at(column):
		return SHORE_BLOCK_ID
	return _surface.block_id_at(column)


## The same answer at a voxel. Y is dropped, exactly as `OceanPass.is_ocean_at_voxel()` and
## `SurfaceMaterial.block_id_at_voxel()` drop it: shoreline is a property of the column.
func is_shoreline_at_voxel(voxel: Vector3i) -> bool:
	return is_shoreline_at(GenerationGrid.voxel_to_column(voxel))


## The same block id at a voxel, Y dropped for the same reason.
func block_id_at_voxel(voxel: Vector3i) -> String:
	return block_id_at(GenerationGrid.voxel_to_column(voxel))


# ---------------------------------------------------------------------------
# Shape of the pass
# ---------------------------------------------------------------------------

## The ocean/river/lake coverage underneath, for a consumer that wants the raw wet/dry
## classification directly. Read-only by convention.
func ocean() -> OceanPass:
	return _ocean


## The ordinary dry-ground material underneath, for a consumer that wants the unshored
## answer directly. Read-only by convention.
func surface() -> SurfaceMaterial:
	return _surface
