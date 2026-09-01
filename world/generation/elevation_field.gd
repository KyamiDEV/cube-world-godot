class_name ElevationField
extends RefCounted
## Where the ground stands, per world column (backlog brick 061).
##
## The first field that answers a question about *terrain* rather than about the world
## map. `Continentalness` (060) says how far inland a column is; this field turns that
## into a height in voxels, measured from the world datum `y = 0`, and adds the relief —
## the hills and valleys — that makes the number worth generating.
##
## ```gdscript
## var ground := ElevationField.for_world(GenerationHash.for_world(world_seed))
## var y := ground.at(column)        # voxels, signed, [MINIMUM_VOXELS, MAXIMUM_VOXELS]
## ```
##
## Three pieces, in the order they are combined:
##
## | Piece | What it contributes |
## |---|---|
## | the **shore weight** | `shore_weight()` turns continentalness into a `0 = sea floor, 1 = interior` blend across a narrow band, so a coastline is a place rather than a world-wide ramp |
## | the **base** | `lerp(OCEAN_FLOOR_VOXELS, LAND_BASE_VOXELS, shore)` — the height the ground would stand at with no relief at all |
## | the **relief** | a `ValueNoise` layer at `WorldHash.SALT_ELEVATION`, in `[0, 1]`, scaled by an amplitude that is itself blended by the shore weight, and added **upward** from the base |
##
## Relief is additive-upward, never signed. That is the one shape decision taken from the
## original, which stacks `(noise + 1) * amplitude` terms on a regional base height and so
## never digs below it (`docs/reference/terrain-base-height-field.md` §3, claim 4): the
## base is a floor, and an ocean floor stays an ocean floor no matter what the noise says.
##
## **It still decides nothing about water.** Sea level is brick 080. This field only says
## how high the rock is; which part of it is underwater is a separate constant applied to
## the same numbers, and keeping the two apart is what lets 080 move the waterline without
## regenerating a single column. Nor does it decide biome (066), erosion (062) or the
## blocky terracing that gives the world its silhouette (063) — 062 and 063 both read this.
##
## Parameters are pinned constants rather than arguments, for the reason `Continentalness`
## gives: they are part of every world made with them, so changing one is a generation
## version bump (`docs/world-generation.md` §2.1), not a tuning knob.
##
## Contract: `docs/world-generation.md` §6. Reference:
## `docs/reference/terrain-base-height-field.md`.

# ---------------------------------------------------------------------------
# The vertical datum
# ---------------------------------------------------------------------------
#
# Elevation is a signed height in **voxels** measured from `y = 0`, which is the centre of
# `WorldBounds`' vertical extent and the only vertical landmark this project has agreed on.
# Voxels, not metres, because the generator that will read this field writes voxels;
# `at_metres()` is there for a log line or a design conversation.

## Height of the ocean floor where the shore weight is fully seaward, in voxels: −48 m.
const OCEAN_FLOOR_VOXELS := -96.0

## Height of the continental base where the shore weight is fully landward: +32 m.
##
## The two anchors are not symmetric about the datum — with relief added upward, the mean
## of the land is `LAND_BASE_VOXELS + RELIEF_AMPLITUDE_VOXELS / 2`, and a symmetric pair
## would put that mean far above anything the ocean floor balances.
const LAND_BASE_VOXELS := 64.0

## The most relief a fully landward column can carry above its base, in voxels: 64 m of
## hill between a valley floor and a ridge line.
const RELIEF_AMPLITUDE_VOXELS := 128.0

## Fraction of that amplitude a fully seaward column gets. Not zero — a dead-flat sea floor
## is as wrong as a mountainous one — but small enough that the deep ocean reads as a
## basin. The original modulates each of its relief tiers by a separate squared weight
## field (`docs/reference/terrain-base-height-field.md` §3, claim 3); we modulate by the
## field we already have, and leave a second ruggedness field to brick 062.
const RELIEF_OCEAN_SCALE := 0.25

## Middle of the shore band, in continentalness.
##
## Deliberately the field's own middle. How much of the world ends up as *land* is decided
## by where brick 080 puts the water plane, not pre-baked here — `Continentalness` is
## centred on 0.5 (`docs/world-generation.md` §5.5), so this is the neutral choice.
const SHORE_MIDPOINT := 0.5

## Width of the shore band, in continentalness. Narrow, so the ocean floor and the interior
## are each themselves over most of their range and the transition is a coast; the whole
## `[0, 1]` would make every column a different blend of the two and no column either.
const SHORE_WIDTH := 0.16

const SHORE_LOW := SHORE_MIDPOINT - SHORE_WIDTH * 0.5
const SHORE_HIGH := SHORE_MIDPOINT + SHORE_WIDTH * 0.5

## Cell edge of the coarsest relief octave, in voxels: one region, 1024 voxels = 512 m.
##
## Exactly the cell size at which `Continentalness`' *finest* octave stops (§5.5), so the
## two fields meet at the region grid instead of overlapping: continentalness carries every
## scale coarser than a region, relief every scale finer.
const RELIEF_CELL_SIZE_VOXELS := GenerationGrid.REGION_SIZE_VOXELS

## Layers of relief summed. Six takes the finest octave to `1024 >> 5` = 32 voxels = 16 m —
## a hillside feature, and still four times the terrace height brick 063 will quantise to,
## so the detail survives that pass instead of being rounded away by it.
const RELIEF_OCTAVES := 6

## Amplitude ratio between one relief octave and the next: the conventional half.
const RELIEF_GAIN := 0.5

## The stated range of `at()`, in voxels. Derived from the constants above rather than
## typed: the minimum is the bare ocean floor (relief adds upward, so it cannot go under),
## the maximum the continental base with full relief on top.
##
## Both are far inside `WorldBounds.HALF_EXTENT_VERTICAL_VOXELS` (2048), which is the point
## — brick 077's caves need room below, and a world whose peaks touched the ceiling would
## have no sky. `tests/unit/test_elevation_field.gd` asserts the headroom.
const MINIMUM_VOXELS := OCEAN_FLOOR_VOXELS
const MAXIMUM_VOXELS := LAND_BASE_VOXELS + RELIEF_AMPLITUDE_VOXELS

var _continentalness: Continentalness
var _relief: ValueNoise


func _init(p_continentalness: Continentalness, p_relief: ValueNoise) -> void:
	_continentalness = p_continentalness
	_relief = p_relief


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds the field to one world, or returns null (logged) when the binding is missing or
## either layer underneath it cannot be built. **The supported entry point.**
##
## Builds its own `Continentalness` rather than taking one: the field is stateless and
## costs one small object, and a shared instance would be a second way for two passes to
## disagree about which world they are generating.
static func for_world(p_hash: GenerationHash) -> ElevationField:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build the elevation field without a world binding"):
		return null
	var macro := Continentalness.for_world(p_hash)
	if macro == null:
		return null
	var relief_layer := ValueNoise.layer(p_hash, RELIEF_CELL_SIZE_VOXELS, RELIEF_OCTAVES,
			RELIEF_GAIN, WorldHash.SALT_ELEVATION)
	if relief_layer == null:
		return null
	return ElevationField.new(macro, relief_layer)


# ---------------------------------------------------------------------------
# Sampling
# ---------------------------------------------------------------------------

## Height of the ground at a world column, in voxels above the datum.
##
## Pure, and inside `[MINIMUM_VOXELS, MAXIMUM_VOXELS]` for every column in the world.
## Continuous, not snapped: the voxel a column's surface lands in is the generator's
## business, and the blocky quantisation the world will actually show is brick 063.
func at(column: Vector2i) -> float:
	var shore := shore_weight(_continentalness.at(column))
	return base_for(shore) + relief_amplitude_for(shore) * _relief.value01(column)


## The same height, asked at a voxel: Y is dropped, exactly as `Continentalness.at_voxel()`
## drops it. "How high is the ground here" is a property of the column.
func at_voxel(voxel: Vector3i) -> float:
	return at(GenerationGrid.voxel_to_column(voxel))


## The same height in metres, for a log line, a design note or a debug overlay. Never for
## generation arithmetic — that stays in voxels, where the numbers are exact.
func at_metres(column: Vector2i) -> float:
	return WorldScale.voxels_to_metres(at(column))


# ---------------------------------------------------------------------------
# The pieces, separately
# ---------------------------------------------------------------------------
#
# `at()` is the sum; these are its terms. Brick 062 wants the base without the relief to
# erode against, brick 063 wants the amplitude to size its terraces, and a debug probe
# wants to know which of the three is responsible for a strange column.

## Continentalness at a column, in `[0, 1]` — the field this one is built on.
func continentalness_at(column: Vector2i) -> float:
	return _continentalness.at(column)


## The blend between sea floor and interior at a column, in `[0, 1]`.
func shore_at(column: Vector2i) -> float:
	return shore_weight(_continentalness.at(column))


## The height the ground would stand at with no relief, in voxels. Monotone in
## continentalness, and the floor `at()` can never go below at that column.
func base_at(column: Vector2i) -> float:
	return base_for(shore_at(column))


## How much relief this column may carry above its base, in voxels.
func relief_amplitude_at(column: Vector2i) -> float:
	return relief_amplitude_for(shore_at(column))


## The raw relief at a column, in `[0, 1]`, before the amplitude is applied.
func relief_at(column: Vector2i) -> float:
	return _relief.value01(column)


## The shore blend for a continentalness value: `0` at or below `SHORE_LOW`, `1` at or
## above `SHORE_HIGH`, and Perlin's quintic in between.
##
## The quintic rather than a plain `smoothstep()` for the reason `docs/world-generation.md`
## §5.3 gives one level down, and one that matters more here: a `C¹`-only curve leaves a
## slope discontinuity at each end of the band, and a slope discontinuity in a *blend*
## becomes a visible crease running along a continentalness contour — a straight-edged
## terrace following the coast at exactly the shore band's edge. It is also written through
## `ValueNoise.fade()` rather than the engine's `smoothstep()`, because the shape of the
## world should not depend on an engine implementation detail.
##
## Static: the curve is part of the world's definition and is worth asserting without
## building a field.
static func shore_weight(continental: float) -> float:
	return ValueNoise.fade(clampf((continental - SHORE_LOW) / SHORE_WIDTH, 0.0, 1.0))


## The base height for a shore weight, in voxels: the height the ground would stand at
## with no relief at all.
##
## Static, and separate from `base_at()`, for `relief_amplitude_for()`'s reason and one
## more: brick 062's shaping pass recomposes `base + amplitude * shaped_relief` from a
## shore weight it has already paid for, and a second `lerpf` written out at the call site
## would be a second place the vertical anchors live.
static func base_for(shore: float) -> float:
	return lerpf(OCEAN_FLOOR_VOXELS, LAND_BASE_VOXELS, shore)


## Relief amplitude for a shore weight, in voxels: fully seaward columns get
## `RELIEF_OCEAN_SCALE` of it, fully landward columns all of it.
##
## Static for the same reason as `shore_weight()`, and separate from
## `relief_amplitude_at()` so the two ends of the blend can be asserted without hunting the
## world for a column that happens to sit at either of them.
static func relief_amplitude_for(shore: float) -> float:
	return lerpf(RELIEF_AMPLITUDE_VOXELS * RELIEF_OCEAN_SCALE, RELIEF_AMPLITUDE_VOXELS,
			shore)


# ---------------------------------------------------------------------------
# Shape of the field
# ---------------------------------------------------------------------------

## The macro field underneath, for a pass that wants continentalness itself rather than the
## height it produced. Read-only by convention: neither field holds mutable state.
func continentalness() -> Continentalness:
	return _continentalness


## The relief layer, for a debug probe or a pass that wants a single octave of it.
func relief_noise() -> ValueNoise:
	return _relief


## Maximum slope of `shore_weight()` with respect to continentalness — the quintic's own
## maximum divided by the band it is squeezed into. Narrowing the band steepens the coast
## in exact proportion, which is the whole reason this is a named number.
static func shore_max_slope() -> float:
	return ValueNoise.FADE_MAX_SLOPE / SHORE_WIDTH


## The most `at()` can change between two columns one voxel apart, in voxels.
##
## Derived, not measured, in the same spirit as `ValueNoise.max_slope_per_voxel()`. With
## `h = base(s) + amplitude(s) · r` and `s = shore(c)`:
##
## ```text
## |dh/dx| <= (|LAND_BASE - OCEAN_FLOOR| + RELIEF_AMPLITUDE·(1 - RELIEF_OCEAN_SCALE))
##            · shore_max_slope() · |dc/dx|
##          + RELIEF_AMPLITUDE · |dr/dx|
## ```
##
## The first term is the coast — how fast the ground can climb out of the sea — and the
## second is the hillside. Both are bounds over the worst column in the world, so a real
## walk sits well under them; what they are for is that
## `tests/unit/test_elevation_field.gd` can assert a real walk against a number derived
## before any sample was taken, and catch the day a shaping pass quietly turns the terrain
## into cliffs.
func max_step_per_voxel() -> float:
	var coast := ((LAND_BASE_VOXELS - OCEAN_FLOOR_VOXELS)
			+ RELIEF_AMPLITUDE_VOXELS * (1.0 - RELIEF_OCEAN_SCALE))
	return (coast * shore_max_slope() * _continentalness.max_step_per_voxel()
			+ RELIEF_AMPLITUDE_VOXELS * _relief.max_slope01_per_voxel())


## Cell edge of the finest relief octave, in metres — the smallest hill this field carries.
static func finest_relief_metres() -> float:
	return WorldScale.voxels_to_metres(
			float(RELIEF_CELL_SIZE_VOXELS >> (RELIEF_OCTAVES - 1)))
