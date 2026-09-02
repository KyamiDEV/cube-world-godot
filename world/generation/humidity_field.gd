class_name HumidityField
extends RefCounted
## How wet a world column is (backlog brick 065).
##
## The second **climate** axis, and 064's mirror. It says one thing per column — `0.0` is
## the driest place in the world, `1.0` the wettest — and, exactly like `TemperatureField`,
## it decides nothing on its own: which pair of climate values is a desert and which is a
## rainforest is brick 066's classification and 067's catalog.
##
## ```gdscript
## var wet := HumidityField.for_world(GenerationHash.for_world(world_seed))
## var h := wet.at(column)           # [0, 1], 0 = driest, 1 = wettest
## ```
##
## Same two pieces as temperature, and — measured rather than assumed — the same constants:
##
## | Piece | What it contributes |
## |---|---|
## | a `ValueNoise` layer at `WorldHash.SALT_HUMIDITY` | the field itself, at the same coarsest-in-the-world scale temperature uses, for the same reason (`docs/world-generation.md` §9.2) |
## | `spread()` | the quintic as a **redistribution**: summed noise clusters, and a climate axis that never reaches its own ends has no deserts |
##
## Three things this file deliberately is *not*, each a decision rather than an omission
## (`docs/world-generation.md` §10.3):
##
## - **not coupled to `Continentalness`.** Real coasts are wetter than continental
##   interiors, but the reference offers no support for it — its humidity is the same
##   per-region blend its temperature is, with no continentalness term
##   (`terrain-climate-blend.md` claim 1) — and taking it would make humidity the first
##   climate axis derived from another field. Brick 066 reads both axes *and*
##   continentalness; a coastal-wetness term belongs there or in 074, where it can be seen.
## - **not coupled to `TemperatureField`.** The two axes are independent by construction
##   (different salts) and independent by measurement (`|r| < 0.05` over a climate-scale
##   sweep), which is what makes a hot-wet / hot-dry / cold-wet / cold-dry catalog possible.
## - **not a shared base class with `TemperatureField`.** Two files that happen to agree is
##   cheaper to retune than one class with two configurations, and brick 066 is the first
##   code to see both users (`docs/world-generation.md` §9.7).
##
## Parameters are pinned constants rather than arguments, for `Continentalness`' reason:
## they are part of every world made with them, so changing one is a generation version
## bump (`docs/world-generation.md` §2.1), not a tuning knob.
##
## Contract: `docs/world-generation.md` §10. Reference:
## `docs/reference/terrain-climate-blend.md`.

## Cell edge of the coarsest octave, in voxels: 16384 voxels = **8192 m**.
##
## `TemperatureField.CELL_SIZE_VOXELS`, and written as that expression rather than as the
## number so the two axes cannot silently drift to different scales — a humidity map at a
## different scale from the temperature map would put a climate boundary on one axis inside
## every cell of the other, which reads as a texture rather than as a place. This is not a
## shared constant with a shared owner: 065 is free to change this line, and the test that
## pins the equality is what would then ask whether that was meant.
const CELL_SIZE_VOXELS := TemperatureField.CELL_SIZE_VOXELS

## Layers summed. Two, so the finest octave is 8192 voxels — exactly
## `Continentalness.CELL_SIZE_VOXELS` and `ErosionPass.RUGGEDNESS_CELL_SIZE_VOXELS`, the
## "meet, don't overlap" rule of `docs/world-generation.md` §9.2.
const OCTAVES := TemperatureField.OCTAVES

## Amplitude ratio between one octave and the next: the conventional half.
const GAIN := TemperatureField.GAIN

## The stated range of `at()`. Both ends are reachable — `spread()` fixes `0` and `1`, and
## the layer's own range is closed — so this is a closed range and not merely a bound.
## Measured: a climate-scale sweep of any fixture world spans `0.0000 .. 1.0000` exactly.
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
static func for_world(p_hash: GenerationHash) -> HumidityField:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build the humidity field without a world binding"):
		return null
	var built := ValueNoise.layer(p_hash, CELL_SIZE_VOXELS, OCTAVES, GAIN,
			WorldHash.SALT_HUMIDITY)
	if built == null:
		return null
	return HumidityField.new(built)


# ---------------------------------------------------------------------------
# Sampling
# ---------------------------------------------------------------------------

## How wet a world column is, in `[0, 1]`: `0` the driest place in the world, `1` the
## wettest, and no unit in between.
##
## Unitless for temperature's reason: the original reads its humidity straight off a
## `[0, 1]` scale against bare literals (`> 0.8`, `terrain-climate-blend.md` claim 5), and
## millimetres of rainfall would be a number this project could not check against anything.
func at(column: Vector2i) -> float:
	return spread(_noise.value01(column))


## The same field, asked at a voxel. Y is dropped, exactly as `TemperatureField.at_voxel()`
## drops it: climate is a property of the column, and a cave is under the same weather as
## the grass above it.
func at_voxel(voxel: Vector3i) -> float:
	return at(GenerationGrid.voxel_to_column(voxel))


## The field **before** `spread()`, in `[0, 1]` — the raw layer, for a debug probe that
## wants to see how much of the range the curve is responsible for.
func raw_at(column: Vector2i) -> float:
	return _noise.value01(column)


## The redistribution curve: Perlin's quintic applied to a `[0, 1]` field.
##
## `TemperatureField.spread()`'s argument, re-measured on this layer rather than inherited
## (`docs/world-generation.md` §10.2). A sum of noise octaves clusters around its own
## middle — this layer puts about 60% of the world in the middle four deciles and under 3%
## in each end decile — so a humidity axis without the curve has no deserts and no swamps
## whatever thresholds brick 066 picks. One application of `fade()` takes every decile to
## between 7% and 16% of the world, and the standard deviation from `0.213` to `0.316`.
##
## Calls `TemperatureField.spread()` rather than `ValueNoise.fade()` directly: the two axes
## share a *curve decision*, and routing through it means an experiment that changes the
## redistribution changes both axes together, or is a deliberate two-line change. That is
## the one thing worth coupling here — the constants above are written as
## `TemperatureField`'s for the same reason, and neither makes this a subclass.
static func spread(raw: float) -> float:
	return TemperatureField.spread(raw)


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
## Derived, not measured: `spread()` is `fade()`, whose slope is at most
## `ValueNoise.FADE_MAX_SLOPE`, applied to a layer that states its own `[0, 1]` slope.
func max_step_per_voxel() -> float:
	return ValueNoise.FADE_MAX_SLOPE * _noise.max_slope01_per_voxel()


## The shortest distance, in voxels, over which `at()` could possibly cross its whole
## range — `1 / max_step_per_voxel()`, and the number a design conversation actually wants:
## not "how fast can the field change" but "how far apart must the driest column and the
## wettest one be".
func minimum_climate_span_voxels() -> float:
	return (MAXIMUM - MINIMUM) / max_step_per_voxel()
