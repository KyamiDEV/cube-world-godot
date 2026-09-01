class_name TemperatureField
extends RefCounted
## How warm a world column is (backlog brick 064).
##
## The first **climate** field, and the first field since `Continentalness` (060) that
## answers a question about the world map rather than about the ground. It says one thing
## per column — `0.0` is the coldest place in the world, `1.0` the hottest — and, exactly
## like `Continentalness`, it decides nothing on its own: which value is a desert and which
## is a snowfield is brick 066's classification and 067's catalog, not this field's
## business.
##
## ```gdscript
## var climate := TemperatureField.for_world(GenerationHash.for_world(world_seed))
## var t := climate.at(column)       # [0, 1], 0 = coldest, 1 = hottest
## ```
##
## Two pieces, and the second is the one worth reading twice:
##
## | Piece | What it contributes |
## |---|---|
## | a `ValueNoise` layer at `WorldHash.SALT_TEMPERATURE` | the field itself, at the coarsest scale anything in this project is generated at — two octaves down from `CELL_SIZE_VOXELS` |
## | `spread()` | the quintic, used as a **redistribution** curve rather than as a blend: summed noise clusters around its own middle, and a climate field that never reaches its own ends has no deserts and no snow |
##
## **Temperature does not read elevation, and that is a finding rather than a shortcut.**
## `docs/reference/terrain-climate-blend.md` reads the original's `World_temperatureBlend`
## and `World_humidityBlend`: climate there is a nearest-region-site blend over stored
## per-region values, sharing nothing with the height field but the noise that jitters the
## region sites. That closes `terrain-base-height-field.md` `U2` — which asked whether
## climate rides on elevation's weight fields; it does not — and contradicts that note's
## `MEDIUM` claim 7. So climate is its own axis here too: cold peaks are brick 085's
## snowline reading this field **and** a height, not a lapse rate baked into this one.
##
## Parameters are pinned constants rather than arguments, for the reason `Continentalness`
## gives: they are part of every world made with them, so changing one is a generation
## version bump (`docs/world-generation.md` §2.1), not a tuning knob.
##
## Contract: `docs/world-generation.md` §9. Reference:
## `docs/reference/terrain-climate-blend.md`.

## Cell edge of the coarsest octave, in voxels: 16384 voxels = **8192 m**.
##
## Twice `Continentalness.CELL_SIZE_VOXELS`, which makes climate the coarsest field in the
## world — coarser than the continents themselves. That ordering is the original's: its
## climate is blended over a window of region sites `0x4000` units across
## (`terrain-climate-blend.md` §3, claim 1) while its coarsest *relief* tier has a period
## of about 5000 units and the weight fields that place that relief about 10000, so climate
## sits roughly one and a half times above the coarsest thing under it. Ours sits exactly
## twice above it, on the nearest power of two (`docs/world-generation.md` §5.2).
const CELL_SIZE_VOXELS := Continentalness.CELL_SIZE_VOXELS * 2

## Layers summed. **Two**, so the finest octave is `16384 >> 1` = 8192 voxels — exactly
## `Continentalness.CELL_SIZE_VOXELS`, and exactly `ErosionPass.RUGGEDNESS_CELL_SIZE_VOXELS`.
##
## The same "meet, don't overlap" rule 061 used to size its relief layer against
## continentalness (`docs/world-generation.md` §6.4): climate carries every scale coarser
## than the coarsest field below it and no scale finer. A third octave would put climate
## detail at 4096 voxels, *inside* a continent — a two-kilometre cold patch in the middle
## of a landmass, which reads as noise rather than as climate and which brick 074's biome
## blending would then have to smooth back out.
##
## It is also what makes `spread()` land where it does: measured over the standard sweep,
## two octaves through the curve give an almost flat decile histogram and three give a
## visibly peaked one (`docs/world-generation.md` §9.5).
const OCTAVES := 2

## Amplitude ratio between one octave and the next: the conventional half.
const GAIN := 0.5

## The stated range of `at()`. Both ends are reachable — `spread()` fixes `0` and `1`, and
## the layer's own range is closed — so this is a closed range and not merely a bound.
const MINIMUM := 0.0
const MAXIMUM := 1.0

var _noise: ValueNoise


func _init(p_noise: ValueNoise) -> void:
	_noise = p_noise


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds the field to one world, or returns null (logged) when the binding is missing or
## the layer underneath it cannot be built. **The supported entry point.**
##
## Takes a `GenerationHash` for `Continentalness.for_world()`'s reason: the hash is where a
## world this build cannot reproduce is already refused (`docs/world-generation.md` §3.2).
static func for_world(p_hash: GenerationHash) -> TemperatureField:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build the temperature field without a world binding"):
		return null
	var built := ValueNoise.layer(p_hash, CELL_SIZE_VOXELS, OCTAVES, GAIN,
			WorldHash.SALT_TEMPERATURE)
	if built == null:
		return null
	return TemperatureField.new(built)


# ---------------------------------------------------------------------------
# Sampling
# ---------------------------------------------------------------------------

## How warm a world column is, in `[0, 1]`: `0` the coldest place in the world, `1` the
## hottest, and no unit in between.
##
## Unitless on purpose. A degree scale would be a number this project cannot check against
## anything — the original reads its own thresholds straight off a `[0, 1]` climate value
## (`terrain-climate-blend.md` §3, claim 5) — and it would invite a lapse rate, which is
## brick 085's decision and not this field's.
func at(column: Vector2i) -> float:
	return spread(_noise.value01(column))


## The same field, asked at a voxel. Y is dropped, exactly as `Continentalness.at_voxel()`
## drops it: climate is a property of the column, and a cave is under the same weather as
## the grass above it.
func at_voxel(voxel: Vector3i) -> float:
	return at(GenerationGrid.voxel_to_column(voxel))


## The field **before** `spread()`, in `[0, 1]` — the raw layer, for a debug probe that
## wants to see how much of the range the curve is responsible for, and for a later pass
## that wants a coarse per-place value rather than this field's use of it.
func raw_at(column: Vector2i) -> float:
	return _noise.value01(column)


## The redistribution curve: Perlin's quintic applied to a `[0, 1]` field.
##
## A sum of noise octaves is a sum of near-independent terms, so its values cluster around
## the middle of its range — measured over the standard sweep, the raw layer spends 70% of
## its columns in the middle four deciles and reaches neither end. A climate field like
## that has no deserts and no snowfields whatever thresholds brick 066 picks, because the
## columns those thresholds would select do not exist.
##
## `fade()` fixes that with the curve the project already has, and its shape as a *blend*
## is exactly why it works as a *spread*: `fade'(0.5) = 1.875` pulls the crowded middle
## apart, `fade'(0) = fade'(1) = 0` pushes the sparse tails out to the ends, and it is
## monotone with fixed points at `0` and `1`, so the ordering of any two columns and the
## stated range both survive it untouched. Measured, one application takes the sweep from a
## standard deviation of `0.181` to `0.280`, against `1/sqrt(12) = 0.289` for a uniform
## field, with an almost flat decile histogram (`docs/world-generation.md` §9.5).
##
## One application, not two, and no linear stretch before it: both were measured, and both
## overshoot into a **bimodal** field with a fifth of the world pinned at each extreme.
## Reusing `ValueNoise.fade()` rather than writing a curve here also keeps the project's
## promise that it has exactly one blending polynomial to keep in step with
## `FADE_MAX_SLOPE`.
##
## Static: the curve is part of the world's definition and is worth asserting at both ends
## without building a field or hunting for a column that happens to sit at one of them.
static func spread(raw: float) -> float:
	return ValueNoise.fade(raw)


# ---------------------------------------------------------------------------
# Shape of the field
# ---------------------------------------------------------------------------

## The layer this field is made of, for a debug probe or a pass that wants a single
## octave. Read-only by convention: `ValueNoise` holds no mutable state.
func noise() -> ValueNoise:
	return _noise


## Cell edge of the coarsest octave, in metres — the scale a player would call "a climate".
static func cell_size_metres() -> float:
	return WorldScale.voxels_to_metres(float(CELL_SIZE_VOXELS))


## Cell edge of the finest octave, in metres — the smallest patch of ground this field can
## decide about on its own.
static func finest_cell_metres() -> float:
	return WorldScale.voxels_to_metres(float(CELL_SIZE_VOXELS >> (OCTAVES - 1)))


## The most `at()` can change between two columns one voxel apart.
##
## Derived, not measured, like every other bound in Phase D: `spread()` is `fade()`, whose
## slope is at most `ValueNoise.FADE_MAX_SLOPE`, applied to a layer that states its own
## `[0, 1]` slope.
func max_step_per_voxel() -> float:
	return ValueNoise.FADE_MAX_SLOPE * _noise.max_slope01_per_voxel()


## The shortest distance, in voxels, over which `at()` could possibly cross its whole
## range.
##
## `1 / max_step_per_voxel()`, named because it is the number a design conversation
## actually wants: not "how fast can the field change" but "how far apart must the coldest
## column and the hottest one be". A lower bound — the real field is far gentler — and it
## is what makes "you walk into a climate" a checkable claim rather than an intention.
func minimum_climate_span_voxels() -> float:
	return (MAXIMUM - MINIMUM) / max_step_per_voxel()
