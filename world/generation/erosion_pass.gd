class_name ErosionPass
extends RefCounted
## Where the ground is allowed to be rugged, and what shape that ruggedness takes
## (backlog brick 062).
##
## `ElevationField` (061) gives every column the same relief budget once its shore weight
## is known: a landward column always carries the full `RELIEF_AMPLITUDE_VOXELS`. That is a
## world where every stretch of land is equally hilly — no plains to cross, no ranges to
## stand out against them. This pass takes 061's three terms apart and puts them back
## together with the relief scaled down, never up.
##
## ```gdscript
## var ground := ErosionPass.for_world(GenerationHash.for_world(world_seed))
## var y := ground.at(column)        # voxels, signed, [MINIMUM_VOXELS, MAXIMUM_VOXELS]
## ```
##
## Two terms, both **flattening**, both applied to the relief and never to the base:
##
## | Term | Answers | Shape |
## |---|---|---|
## | **ruggedness** | *where* may the ground be rugged | a `ValueNoise` layer strictly coarser than every relief octave, remapped to `[0, 1]` and **squared**, then floored at `RUGGEDNESS_FLOOR` |
## | **valley bias** | *what shape* the surviving relief takes | a partial squaring of the relief itself, so mid heights sink toward the valley floor and high ground becomes the exception |
##
## The squaring is the mechanism, and it is taken from the original: it modulates each of
## its three relief tiers by a separate weight field one decade coarser than the tier,
## remapped to `[0, 1]` and multiplied by itself (`docs/reference/terrain-base-height-field.md`
## §3, claim 3). `w²` pushes most of its mass toward zero, so **flat is the default and
## rugged is the exception** — which is the half of that finding brick 061 deliberately
## left here (§6.7).
##
## The invariant that makes this a *pass* rather than a second height field:
##
## ```text
## base_at(column) <= at(column) <= elevation().at(column)
## ```
##
## Every term scales relief toward the base and never away from it, which is exactly the
## shape of all four of the original's own post-passes (claim 6, `INV-2`). It is why this
## pass needs no range of its own — it inherits 061's — and why the rivers, roads and
## structure flattening of bricks 080–083 and 089–090 can join it later as more factors in
## the same product rather than as a rewrite.
##
## Parameters are pinned constants rather than arguments, for the reason `Continentalness`
## and `ElevationField` give: they are part of every world made with them, so changing one
## is a generation version bump (`docs/world-generation.md` §2.1), not a tuning knob.
##
## Contract: `docs/world-generation.md` §7. Reference:
## `docs/reference/terrain-base-height-field.md` §3 claim 3, §8.

# ---------------------------------------------------------------------------
# The ruggedness field
# ---------------------------------------------------------------------------

## Cell edge of the coarsest ruggedness octave, in voxels: 8192 = 4096 m.
##
## Eight regions across, i.e. eight times `ElevationField.RELIEF_CELL_SIZE_VOXELS`. The
## original's weight field sits one *decade* coarser than the tier it modulates; a decade
## is not available to us (`ValueNoise` takes powers of two, and for the exactness reason
## `docs/world-generation.md` §5.2 gives), so this is the nearest power of two to it.
const RUGGEDNESS_CELL_SIZE_VOXELS := ElevationField.RELIEF_CELL_SIZE_VOXELS * 8

## Layers of ruggedness summed. Three takes the finest octave to `8192 >> 2` = 2048 voxels
## = 1024 m — still **twice** the coarsest relief cell, which is the property that matters:
## every scale this field carries is coarser than every scale it modulates. A ruggedness
## octave finer than a relief octave would stop placing relief and start being relief,
## with the amplitude of a multiplier and no slope bound of its own.
const RUGGEDNESS_OCTAVES := 3

## Amplitude ratio between one ruggedness octave and the next: the conventional half.
const RUGGEDNESS_GAIN := 0.5

## What a column keeps of its relief amplitude where the ruggedness field is at its lowest.
##
## Not zero. `w²` at zero is a mathematical plane, and a plane is not a plain — it reads as
## a bug the moment a player walks it. A tenth of `RELIEF_AMPLITUDE_VOXELS` is 12.8 voxels
## = 6.4 m of gentle roll across the flattest ground in the world, which is undulation, not
## terrain.
const RUGGEDNESS_FLOOR := 0.1

## How far the relief is squared toward the valley floor: `0` leaves 061's relief alone,
## `1` replaces it with its own square.
##
## A half. The curve is `lerp(r, r², VALLEY_BIAS)`, which is below `r` everywhere on
## `(0, 1)` and equal at both ends — so it lowers ground without moving either the valley
## floor or the ridge line, and the stated range survives it untouched.
##
## An *integer* power written as a multiplication, never `pow()`: the same argument §5.3
## makes about `cos`. `pow` is a libm entry point with no bit-exactness guarantee across
## platforms, and both server and client generate from the same seed, so a last-bit
## disagreement about a hillside is a disagreement about where the ground is.
const VALLEY_BIAS := 0.5

## The stated range of `at()`, in voxels — 061's, unchanged, because every term of this
## pass multiplies relief by something in `[0, 1]`.
##
## The minimum is still reachable (a column with no relief), and so is the maximum (full
## ruggedness on a fully landward column at a relief peak), so this is a closed range and
## not merely a bound.
const MINIMUM_VOXELS := ElevationField.MINIMUM_VOXELS
const MAXIMUM_VOXELS := ElevationField.MAXIMUM_VOXELS

var _elevation: ElevationField
var _ruggedness: ValueNoise


func _init(p_elevation: ElevationField, p_ruggedness: ValueNoise) -> void:
	_elevation = p_elevation
	_ruggedness = p_ruggedness


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds the pass to one world, or returns null (logged) when the binding is missing or a
## layer underneath it cannot be built. **The supported entry point.**
##
## Builds its own `ElevationField` for the reason 061 builds its own `Continentalness`: the
## objects are stateless and small, and a shared instance would be a second way for two
## passes to disagree about which world they are generating.
static func for_world(p_hash: GenerationHash) -> ErosionPass:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build the erosion pass without a world binding"):
		return null
	var ground := ElevationField.for_world(p_hash)
	if ground == null:
		return null
	var ruggedness_layer := ValueNoise.layer(p_hash, RUGGEDNESS_CELL_SIZE_VOXELS,
			RUGGEDNESS_OCTAVES, RUGGEDNESS_GAIN, WorldHash.SALT_RUGGEDNESS)
	if ruggedness_layer == null:
		return null
	return ErosionPass.new(ground, ruggedness_layer)


# ---------------------------------------------------------------------------
# Sampling
# ---------------------------------------------------------------------------

## Height of the shaped ground at a world column, in voxels above the datum.
##
## Pure, and inside `[MINIMUM_VOXELS, MAXIMUM_VOXELS]` for every column in the world.
## Continuous, not snapped — the blocky silhouette is still brick 063's, and this pass is
## deliberately upstream of it so the terraces follow eroded ground rather than 061's.
##
## The shore weight is sampled once and both of 061's blended terms are rebuilt from it,
## rather than calling `base_at()` and `relief_amplitude_at()` and paying for
## `Continentalness` twice.
func at(column: Vector2i) -> float:
	var shore := _elevation.shore_at(column)
	return (ElevationField.base_for(shore)
			+ ElevationField.relief_amplitude_for(shore) * shaped_relief_at(column))


## The same height, asked at a voxel: Y is dropped, exactly as `ElevationField.at_voxel()`
## drops it. "How high is the ground here" is a property of the column.
func at_voxel(voxel: Vector3i) -> float:
	return at(GenerationGrid.voxel_to_column(voxel))


## The same height in metres, for a log line, a design note or a debug overlay. Never for
## generation arithmetic — that stays in voxels, where the numbers are exact.
func at_metres(column: Vector2i) -> float:
	return WorldScale.voxels_to_metres(at(column))


# ---------------------------------------------------------------------------
# The terms, separately
# ---------------------------------------------------------------------------
#
# `at()` is the product; these are its factors. Brick 063 wants to know how much relief
# survived before it sizes a terrace, brick 066 wants ruggedness itself as a biome input,
# and a debug probe wants to know which factor flattened a column that looks wrong.

## The ruggedness noise at a column, in `[0, 1]`, **before** the squaring — the raw field,
## for a pass that wants a coarse per-place value rather than this pass's use of it.
func ruggedness_noise_at(column: Vector2i) -> float:
	return _ruggedness.value01(column)


## How much of its relief amplitude a column is allowed to keep, in
## `[RUGGEDNESS_FLOOR, 1]`. Squared, so most of the world sits near the floor.
func ruggedness_at(column: Vector2i) -> float:
	return ruggedness_weight(_ruggedness.value01(column))


## 061's relief at a column, in `[0, 1]`, before either term of this pass touches it.
func relief_at(column: Vector2i) -> float:
	return _elevation.relief_at(column)


## The relief this pass actually applies, in `[0, 1]`: ruggedness times the valley-shaped
## relief. Never larger than `relief_at()`, which is the whole claim of the pass.
func shaped_relief_at(column: Vector2i) -> float:
	return ruggedness_at(column) * valley_shaped(_elevation.relief_at(column))


## The height the ground would stand at with no relief at all, in voxels — 061's base,
## untouched by this pass and the floor `at()` can never go below.
func base_at(column: Vector2i) -> float:
	return _elevation.base_at(column)


## The unshaped height, in voxels: what 061 alone would have answered. The ceiling `at()`
## can never rise above.
func unshaped_at(column: Vector2i) -> float:
	return _elevation.at(column)


## How many voxels this pass removed at a column. Never negative.
func removed_at(column: Vector2i) -> float:
	return unshaped_at(column) - at(column)


## The ruggedness weight for a raw `[0, 1]` noise value: floored, then squared.
##
## The squaring is the redistribution curve the original uses and the reason flat is the
## default — `w²` for `w` spread over `[0, 1]` puts most of its mass near zero, so a
## minority of the world gets most of the stated amplitude and the rest gets a fraction of
## it (`docs/reference/terrain-base-height-field.md` §3, claim 3).
##
## Static: the curve is part of the world's definition and is worth asserting at both ends
## without building a field or hunting for a column that happens to sit at one of them.
static func ruggedness_weight(raw: float) -> float:
	return RUGGEDNESS_FLOOR + (1.0 - RUGGEDNESS_FLOOR) * raw * raw


## The valley-shaped relief for a raw `[0, 1]` relief value: `lerp(r, r², VALLEY_BIAS)`.
##
## Fixed points at `0` and `1` and strictly below `r` in between, so the valley floor and
## the ridge line stay where 061 put them and everything between them moves downhill. That
## is what "erosion" means here: the pass removes material from the slopes, not from the
## extremes that define the range.
##
## Static for `ruggedness_weight()`'s reason.
static func valley_shaped(relief: float) -> float:
	return relief + VALLEY_BIAS * (relief * relief - relief)


# ---------------------------------------------------------------------------
# Shape of the pass
# ---------------------------------------------------------------------------

## The field underneath, for a pass that wants unshaped elevation or one of its own terms.
## Read-only by convention: neither object holds mutable state.
func elevation() -> ElevationField:
	return _elevation


## The ruggedness layer, for a debug probe or a pass that wants a single octave of it.
func ruggedness_noise() -> ValueNoise:
	return _ruggedness


## The most `at()` can change between two columns one voxel apart, in voxels.
##
## Derived, not measured, in the same spirit as `ElevationField.max_step_per_voxel()`
## (§6.5). With `h = base(s) + A(s) · g`, `g = rug(w) · v(r)`, and every factor of `g` in
## `[0, 1]`:
##
## ```text
## |dh/dx| <= (|LAND_BASE - OCEAN_FLOOR| + RELIEF_AMPLITUDE·(1 - RELIEF_OCEAN_SCALE))
##            · shore_max_slope() · |dc/dx|                       # the coast, as in §6.5
##          + RELIEF_AMPLITUDE · ( 2·(1 - RUGGEDNESS_FLOOR)·|dw/dx|
##                               + (1 + VALLEY_BIAS)·|dr/dx| )    # the hillside
## ```
##
## `rug'(w) = 2·(1 − floor)·w` peaks at `w = 1`, and `v'(r) = (1 − bias) + 2·bias·r` peaks
## at `r = 1`, which is worth stating plainly: **this pass lowers ground but can locally
## steepen it.** The valley bias multiplies the relief's own slope by up to `1 + bias` at a
## ridge line, so the bound here is *larger* than 061's even though every height it
## produces is smaller. Steeper hillsides are the point of an erosion pass; the bound is
## what keeps "steeper" from quietly becoming "a cliff".
func max_step_per_voxel() -> float:
	var coast := ((ElevationField.LAND_BASE_VOXELS - ElevationField.OCEAN_FLOOR_VOXELS)
			+ ElevationField.RELIEF_AMPLITUDE_VOXELS
					* (1.0 - ElevationField.RELIEF_OCEAN_SCALE))
	var hillside := (2.0 * (1.0 - RUGGEDNESS_FLOOR) * _ruggedness.max_slope01_per_voxel()
			+ (1.0 + VALLEY_BIAS) * _elevation.relief_noise().max_slope01_per_voxel())
	return (coast * ElevationField.shore_max_slope()
			* _elevation.continentalness().max_step_per_voxel()
			+ ElevationField.RELIEF_AMPLITUDE_VOXELS * hillside)


## Cell edge of the coarsest ruggedness octave, in metres — how wide a mountain range or a
## plain can be.
static func ruggedness_cell_metres() -> float:
	return WorldScale.voxels_to_metres(float(RUGGEDNESS_CELL_SIZE_VOXELS))


## Cell edge of the finest ruggedness octave, in metres — the smallest patch of ground this
## pass can decide about on its own.
static func finest_ruggedness_metres() -> float:
	return WorldScale.voxels_to_metres(
			float(RUGGEDNESS_CELL_SIZE_VOXELS >> (RUGGEDNESS_OCTAVES - 1)))
