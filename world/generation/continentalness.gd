class_name Continentalness
extends RefCounted
## The macro land/ocean field: how far inland a column is (backlog brick 060).
##
## The first thing this project generates. It answers one question per world column —
## **how continental is this place?** — on a scale from `0.0` (the middle of an ocean) to
## `1.0` (the middle of a landmass), and it answers it at a scale far coarser than
## anything a player sees at once: the coarsest layer is 4 km across, so walking a
## kilometre moves this value a little and never jumps it.
##
## ```gdscript
## var field := Continentalness.for_world(GenerationHash.for_world(world_seed))
## var c := field.at(column)         # [0, 1]
## ```
##
## It deliberately decides nothing. It does not say where sea level is (brick 080), how
## high the ground stands (061), or what grows there (067–073) — every one of those reads
## this field and adds its own rule. Keeping the field and the thresholds apart is what
## lets 080 move a coastline without reshaping the continents underneath it.
##
## Parameters are pinned constants rather than arguments, because they are part of the
## generated world: changing one changes every world ever made with it, which is a
## generation version bump (`docs/world-generation.md` §2.1), not a tuning knob.
##
## Contract: `docs/world-generation.md` §5.5. The noise underneath it:
## `world/generation/value_noise.gd`.

## Cell edge of the coarsest layer, in voxels: eight regions, 8192 voxels, **4096 m**.
##
## Expressed against `GenerationGrid.REGION_SIZE_VOXELS` on purpose. With `OCTAVES` at 4
## the finest layer is exactly one region across, which gives the region grid — the grid
## brick 089 places structures on — a continentalness value that is meaningfully its own
## rather than an interpolation of its neighbours'.
const CELL_SIZE_VOXELS := GenerationGrid.REGION_SIZE_VOXELS * 8

## Layers summed. Four is what it takes to reach one region of detail from a cell of
## eight; a fifth would carry half-region wiggle into a field whose consumers all
## deliberately work at region scale or coarser.
const OCTAVES := 4

## Amplitude ratio between one layer and the next. The conventional half: the field stays
## dominated by its coarsest layer, which is the definition of a *macro* field.
const GAIN := 0.5

## The stated range of `at()`. Asserted by `tests/unit/test_continentalness.gd` through
## `GenerationFixtures.range_reason()`, which is also what catches a NaN.
const MINIMUM := 0.0
const MAXIMUM := 1.0

var _noise: ValueNoise


func _init(p_noise: ValueNoise) -> void:
	_noise = p_noise


## Binds the field to one world, or returns null (logged) when the binding is missing or
## the layer underneath it cannot be built. **The supported entry point.**
##
## Takes a `GenerationHash`, not a `WorldSeed`: the hash is where a world this build
## cannot reproduce is already refused (`docs/world-generation.md` §3.2), and every Phase D
## field will want the same binding rather than each one re-deriving it.
static func for_world(p_hash: GenerationHash) -> Continentalness:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build the continentalness field without a world binding"):
		return null
	var built := ValueNoise.layer(p_hash, CELL_SIZE_VOXELS, OCTAVES, GAIN,
			WorldHash.SALT_CONTINENTALNESS)
	if built == null:
		return null
	return Continentalness.new(built)


# ---------------------------------------------------------------------------
# Sampling
# ---------------------------------------------------------------------------

## How continental a world column is, in `[0, 1]`: `0` is the middle of an ocean, `1` the
## middle of a landmass, and the interesting parts of the world are neither.
func at(column: Vector2i) -> float:
	return _noise.value01(column)


## The same field, asked at a voxel. Y is dropped, not used: continentalness is a property
## of the column a voxel stands in, and a cave a hundred voxels down is under the same
## continent as the grass above it.
func at_voxel(voxel: Vector3i) -> float:
	return at(GenerationGrid.voxel_to_column(voxel))


# ---------------------------------------------------------------------------
# Shape of the field
# ---------------------------------------------------------------------------

## The layer this field is made of, for a debug probe or a pass that wants a single
## octave. Read-only by convention: `ValueNoise` holds no mutable state.
func noise() -> ValueNoise:
	return _noise


## Cell edge of the coarsest layer, in metres — the scale a player would call "a
## continent" if they could see the whole thing at once.
static func cell_size_metres() -> float:
	return WorldScale.voxels_to_metres(float(CELL_SIZE_VOXELS))


## The most `at()` can change between two columns one voxel apart. A bound, not a
## measurement; `tests/unit/test_continentalness.gd` walks the real field against it.
func max_step_per_voxel() -> float:
	return _noise.max_slope01_per_voxel()
