class_name SnowlineMaterial
extends RefCounted
## Which columns above the frost line read as snow, regardless of biome (backlog brick 085).
##
## `TemperatureField` (064) already says how cold a column's climate is, and
## `BiomeClassifier` (066) already turns "cold enough" into `biome.snow` at
## `TEMPERATURE_COLD` — but only at whatever height a column happens to sit at. A cold
## lowland and a cold mountaintop are both already `biome.snow`, and `ShorelineMaterial`
## (084) already keeps the ground looking right at the water's edge for every biome. What
## neither answers is the opposite case: a column whose *climate* reads warm but whose
## *ground* stands high enough that a real mountain would still be capped in snow —
## `TemperatureField`'s own class comment named this brick in advance for exactly that case:
## "cold peaks are brick 085's snowline reading this field **and** a height, not a lapse rate
## baked into this one."
##
## ```gdscript
## var snowline := SnowlineMaterial.for_world(hash, biomes, blocks)
## var block_id := snowline.block_id_at(column)   # "block.snow" above the frost line
## ```
##
## ## A lapse rate, derived rather than picked
##
## `effective_temperature_at()` subtracts a fixed rate per voxel of height above
## `ElevationField.LAND_BASE_VOXELS` from `TemperatureField.at()`, and `is_snow_covered_at()`
## compares the result against `BiomeClassifier.TEMPERATURE_COLD` — the same threshold the
## classifier already uses, so a column's climate alone still decides everything at the land
## baseline, and altitude only ever pushes a warm reading colder, never the reverse.
##
## `LAPSE_RATE_PER_VOXEL` is not tuned: it is set so that a column standing
## `ElevationField.RELIEF_AMPLITUDE_VOXELS` above the baseline — the most a landward column's
## relief can ever raise it — reads as snow-covered even at `TemperatureField.MAXIMUM`, the
## hottest climate the world can produce.
##
## ```text
## LAPSE_RATE_PER_VOXEL = (TemperatureField.MAXIMUM - BiomeClassifier.TEMPERATURE_COLD)
##                        / ElevationField.RELIEF_AMPLITUDE_VOXELS
## ```
##
## `self_check()` asserts the invariant it was derived for rather than trusting the formula:
## the tallest possible peak in the world is always snow-capped, in every climate, which is
## the one guarantee a snowline is supposed to make.
##
## ## Why the land baseline, and why the gate at zero
##
## Height is measured **above `ElevationField.LAND_BASE_VOXELS`**, not above the world datum:
## that constant is already "the height the ground would stand at with no relief at all"
## (061), so a column carrying no relief above its own baseline gets no lapse at all —
## `is_snow_covered_at()` returns `false` outright whenever a column's terraced height does
## not clear that baseline, **before** it ever compares a temperature. Below the baseline,
## `effective_temperature_at()` collapses to the same raw `TemperatureField.at()` value
## `BiomeClassifier.classify()` already tests at exactly the same `TEMPERATURE_COLD`
## threshold — so without the gate, this file would re-decide the `SNOW`/non-`SNOW` biome
## edge `BiomeTransition` (074) and `SurfaceMaterial` (075) already dither smoothly across,
## hardening it back into a straight line for every ordinary lowland column. The gate is what
## keeps this brick's altitude question from quietly re-litigating a biome-edge question 074
## already answered.
##
## ## One fixed block, reusing 084's own argument
##
## `SNOW_BLOCK_ID = "block.snow"`, already shipped by 075 — no new block, and no per-biome
## field, for exactly the reason `ShorelineMaterial.SHORE_BLOCK_ID` (084, §23.2) gives: no
## consumer distinguishes a snow-capped mountain from a snow-capped tundra, so a second field
## on `BiomeDefinition` naming the string every biome could already read from
## `surface_block_id` would be the "record grows, nothing reads it" shape 067 has already
## named five times.
##
## ## A pure combination over `ShorelineMaterial`, not `SurfaceMaterial`
##
## `SnowlineMaterial` holds a `ShorelineMaterial` (084), a `TemperatureField` (064) and a
## `TerracePass` (063), all built fresh in `for_world()` (`TerracePass.for_world()`'s own
## recurring reason: stateless, small, and a shared instance would be a second way for two
## passes to disagree about which world they are generating). Building on `ShorelineMaterial`
## rather than reaching past it to `SurfaceMaterial` directly means a wet or shoreline column
## is excluded the same way 084 excluded them from its own override — checked first, and
## returned untouched — so this brick never has to decide what a snowy beach or a frozen
## lake edge looks like, exactly the boundary `ShorelineMaterial`'s own class comment left
## open for "a narrower or wider shore band" and nothing else.
##
## ## Reference
##
## A case-insensitive grep of `reference/CubeWorld-Reversal` for "snow" turns up creature and
## item names only (`SnowGolem`, `SnowBush`, `golem-snow-*.cub`) — no generation mechanism —
## except one real hit: `terrain_surfaceColor_blend` (`0x005c56e0`, `[AUDIT] confidence: med`)
## blends a snow-coloured noise term into its terrain RGBA wherever a normalized `height`
## parameter exceeds `0.8` (a fainter blend from `0.75`) **and** `slope < 0.2` — height and
## flatness, continuously, with no biome, no moisture and no discrete material anywhere near
## it, despite `GAP_ANALYSIS.md`'s own one-line summary naming "moisture" as an input. One
## piece kept: snow as a **height** effect that can appear regardless of climate is exactly
## this brick's own idea, arrived at independently in `docs/world-generation.md` §9.3/§9.7
## before this function was ever read. Two pieces not kept: **slope** — this project already
## has a rugged-vs-flat measure (`ErosionPass.ruggedness_at()`), but it decides
## `biome.mountain` upstream of this file, and a second, independent flatness gate here would
## be a second way to reach the same question 066 already answers; and **no discrete `SNOW`
## id at all** — the original blends a colour, 066's own divergence (§12.5) carried forward
## rather than reopened.
##
## Contract: `docs/world-generation.md` §24.

## The block every snow-covered column reads, regardless of biome. Already shipped by 075;
## see the class comment for why this is a constant and not a per-biome field.
const SNOW_BLOCK_ID := "block.snow"

## Temperature lost per voxel of height above `ElevationField.LAND_BASE_VOXELS`. See the
## class comment: derived so the tallest possible relief always crosses `TEMPERATURE_COLD`
## even at the hottest possible climate, not picked or measured.
const LAPSE_RATE_PER_VOXEL := ((TemperatureField.MAXIMUM - BiomeClassifier.TEMPERATURE_COLD)
		/ ElevationField.RELIEF_AMPLITUDE_VOXELS)

var _shoreline: ShorelineMaterial
var _temperature: TemperatureField
var _terrace: TerracePass


func _init(p_shoreline: ShorelineMaterial, p_temperature: TemperatureField,
		p_terrace: TerracePass) -> void:
	_shoreline = p_shoreline
	_temperature = p_temperature
	_terrace = p_terrace


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds snowline material selection to one world and one loaded content set, or returns
## null (logged) when any piece cannot be built or the block registry has no `SNOW_BLOCK_ID`
## record. **The supported entry point.**
##
## Builds its own `TemperatureField` and `TerracePass` — `ShorelineMaterial.for_world()`'s own
## reason repeated once more: both are stateless and small, and a shared instance would be a
## second way for two passes to disagree about which world they are generating.
## `ShorelineMaterial.for_world()` already validates `biomes`/`blocks` locking, the biome
## catalog's own `self_check()`, every `surface_block_id` and its own fixed shore block; this
## adds the one check that is 085's own.
static func for_world(p_hash: GenerationHash, p_biomes: BiomeRegistry,
		p_blocks: BlockRegistry) -> SnowlineMaterial:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build snowline material selection without a world binding"):
		return null
	if not Log.check(snow_block_reason_for(p_blocks).is_empty(), Log.CH_GEN,
			"block registry has no record for the fixed snowline block",
			{"reason": snow_block_reason_for(p_blocks)}):
		return null
	var bound_shoreline := ShorelineMaterial.for_world(p_hash, p_biomes, p_blocks)
	if bound_shoreline == null:
		return null
	var bound_temperature := TemperatureField.for_world(p_hash)
	if bound_temperature == null:
		return null
	var bound_terrace := TerracePass.for_world(p_hash)
	if bound_terrace == null:
		return null
	return SnowlineMaterial.new(bound_shoreline, bound_temperature, bound_terrace)


## Empty string when `blocks` has a record for `SNOW_BLOCK_ID`, otherwise the reason.
## `ShorelineMaterial.shore_block_reason_for()`'s exact shape for its own fixed block.
static func snow_block_reason_for(p_blocks: BlockRegistry) -> String:
	if p_blocks == null or not p_blocks.has_block(SNOW_BLOCK_ID):
		return "block registry has no record for '%s', the fixed snowline block" % SNOW_BLOCK_ID
	return ""


# ---------------------------------------------------------------------------
# The classification
# ---------------------------------------------------------------------------

## How far a column's terraced ground stands above `ElevationField.LAND_BASE_VOXELS`, in
## voxels. Never negative: a column at or below the baseline carries no lapse at all.
func height_above_land_base_at(column: Vector2i) -> float:
	return maxf(0.0, _terrace.at(column) - ElevationField.LAND_BASE_VOXELS)


## `TemperatureField.at()`, reduced by `LAPSE_RATE_PER_VOXEL` for every voxel a column's
## ground stands above `ElevationField.LAND_BASE_VOXELS`. Equal to the raw climate reading at
## or below the baseline, and only ever colder above it.
func effective_temperature_at(column: Vector2i) -> float:
	return _temperature.at(column) - LAPSE_RATE_PER_VOXEL * height_above_land_base_at(column)


## True where altitude alone is enough to read a column as snow-covered.
##
## Gated on `height_above_land_base_at()` being strictly positive before anything else:
## exactly at or below the baseline, `effective_temperature_at()` is the same raw value
## `BiomeClassifier.classify()` already tests at the same `TEMPERATURE_COLD` threshold, so
## answering there too would re-decide — and re-harden — the `SNOW`/non-`SNOW` biome edge
## `BiomeTransition`/`SurfaceMaterial` already dither smoothly across. See the class comment.
func is_snow_covered_at(column: Vector2i) -> bool:
	if height_above_land_base_at(column) <= 0.0:
		return false
	return effective_temperature_at(column) < BiomeClassifier.TEMPERATURE_COLD


## The block id covering `column`: `SNOW_BLOCK_ID` above the frost line, otherwise whatever
## `ShorelineMaterial` already says there — including at a column it already calls wet or
## shoreline, where this file has no more business overriding the answer than
## `ShorelineMaterial` has overriding `OceanPass`'s own wet columns (see the class comment).
func block_id_at(column: Vector2i) -> String:
	if _shoreline.is_water_at(column) or _shoreline.is_shoreline_at(column):
		return _shoreline.block_id_at(column)
	if is_snow_covered_at(column):
		return SNOW_BLOCK_ID
	return _shoreline.block_id_at(column)


## The same answer at a voxel. Y is dropped, exactly as `ShorelineMaterial.
## is_shoreline_at_voxel()` drops it: snow cover is a property of the column.
func is_snow_covered_at_voxel(voxel: Vector3i) -> bool:
	return is_snow_covered_at(GenerationGrid.voxel_to_column(voxel))


## The same block id at a voxel, Y dropped for the same reason.
func block_id_at_voxel(voxel: Vector3i) -> String:
	return block_id_at(GenerationGrid.voxel_to_column(voxel))


# ---------------------------------------------------------------------------
# Shape of the pass
# ---------------------------------------------------------------------------

## The shoreline/surface material chain underneath, for a consumer that wants the unshored
## answer directly. Read-only by convention.
func shoreline() -> ShorelineMaterial:
	return _shoreline


## The climate field underneath, for a debug probe or a pass that wants the raw temperature
## rather than this file's lapsed use of it.
func temperature() -> TemperatureField:
	return _temperature


## The terraced height pass underneath, for a consumer that wants the raw height this file
## measures altitude from.
func terrace() -> TerracePass:
	return _terrace


## Empty string when the lapse rate still guarantees the invariant it was derived for,
## otherwise the reason. Asserts the relationship rather than trusting the formula —
## `BiomeClassifier.self_check()`'s own precedent for a threshold derived rather than picked.
static func self_check() -> String:
	var hottest_at_the_tallest_relief := (TemperatureField.MAXIMUM
			- LAPSE_RATE_PER_VOXEL * ElevationField.RELIEF_AMPLITUDE_VOXELS)
	if not is_equal_approx(hottest_at_the_tallest_relief, BiomeClassifier.TEMPERATURE_COLD):
		return ("the lapse rate no longer puts the hottest possible climate at "
				+ "TEMPERATURE_COLD at the tallest possible relief height (%s, expected %s)") % [
						hottest_at_the_tallest_relief, BiomeClassifier.TEMPERATURE_COLD]
	return ""
