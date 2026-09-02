class_name ValueNoise
extends RefCounted
## A coherent, seed-bound noise layer over `GenerationHash` (backlog brick 060).
##
## `GenerationHash` (058) answers every coordinate independently: neighbouring columns get
## unrelated values. That is exactly right for a placement mask ("does a tree stand here?")
## and useless for a *field* — terrain built from white noise is a stack of one-voxel
## spikes, and no biome, river or coastline can be read out of it.
##
## This file is the missing half: **value noise**. Hash only the corners of a coarse
## lattice, then interpolate smoothly between them, and sum a few such layers at halving
## cell sizes (fractional Brownian motion). Neighbouring columns now differ by a bounded
## amount — `max_slope_per_voxel()` states by how much, and the test asserts it — while the
## field stays a pure function of `(seed, coordinates)`, with no state and no visit order.
##
## ```gdscript
## var layer := ValueNoise.layer(hash, 8192, 4, 0.5, WorldHash.SALT_CONTINENTALNESS)
## var v := layer.value(column)      # [-1, 1]
## var u := layer.value01(column)    # [0, 1]
## ```
##
## Every 2D form above has a **3D twin** — `value3()`, `value301()`, `octave_value3()`
## (brick 077) — sampled at a voxel rather than a column, trilinear rather than bilinear,
## hashed in voxel space rather than column space so the two never agree at a coordinate
## that happens to share both forms' numbers. §5.6 deferred this deliberately until a pass
## existed that actually needed a mask varying with height; caves are that pass.
##
## Four properties this implementation is built around, each of which is a determinism
## decision before it is a quality one:
##
## | Decision | Why |
## |---|---|
## | the lattice lives in **integer voxel space** | no float ever carries a world coordinate, so nothing loses exactness at the ±524288-voxel corners of `WorldBounds` |
## | cell sizes are **powers of two**, divided with `GenerationGrid.floor_div()` | truncating division puts voxel −1 and voxel 0 in the same cell and mirrors the whole field about the origin — the exact defect the original's own `valueNoise2D` has (`docs/reference/terrain-value-noise.md` §4). A power-of-two cell also makes `floor_mod / cell` an exact float, so the interpolation weight has no rounding |
## | the fade is a **polynomial**, never `cos()` | `+`, `-` and `*` on doubles are exactly specified by IEEE-754 and identical on every platform; `cos()` is a libm implementation detail. A server and a client that disagree in the last bit of a coastline disagree about where the land is (`docs/world-generation.md` §5.3) |
## | octaves are separated by a **lattice offset**, not by a salt | salts are one-per-pass and must stay below `GenerationHash.SPACE_SALT_STRIDE` (`docs/rng.md` §4), so `salt + octave` would walk into the next pass's salt. Offsetting the lattice reads a different part of the same hash field instead — and without it every octave samples lattice `(0, 0)` at the world origin and agrees there, putting a spike at the one coordinate everything else is measured from |
##
## Contract: `docs/world-generation.md` §5. Reference: `docs/reference/terrain-value-noise.md`.

## Largest number of octaves a layer may stack. Past this the amplitude of the next
## octave is below the noise floor of the sum, so it costs four hashes to change nothing.
const MAX_OCTAVES := 16

## Widest cell a layer may use, in voxels: the full horizontal width of `WorldBounds`.
## A cell wider than the world puts every column in one cell, and the "field" is one
## interpolation ramp across the whole map.
const MAX_CELL_SIZE_VOXELS := 2 * WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS

## Maximum slope of `fade()`, at `t = 0.5`: `fade'(t) = 30t²(1−t)²`, so `30/16`. Used by
## `max_slope_per_voxel()` — stated here rather than measured, because the whole point of
## the bound is that it is known before any sample is taken.
const FADE_MAX_SLOPE := 1.875

## How far each octave's lattice is shifted from the one below it. Two large odd numbers,
## unequal so the shift is not diagonal; the value is baked into every world generated
## with it and follows the same append-never-change rule as a salt (`docs/rng.md` §4).
const OCTAVE_LATTICE_STEP := Vector2i(1013, 7717)

## The 3D form of the same shift (brick 077), one more unequal odd number added for the
## vertical axis rather than reusing either horizontal one — a shift diagonal on two axes
## would still leave the third free to agree with the coarsest octave along it.
const OCTAVE_LATTICE_STEP_3D := Vector3i(1013, 4001, 7717)

## The world binding every corner is hashed through. Never a bare `WorldHash`:
## `GenerationHash` is what carries the seed, the checked generation version and the
## column-space tag (`docs/rng.md` §4).
var _hash: GenerationHash

## Cell edge of the first (coarsest) octave, in voxels. A power of two.
var _cell_size: int

var _octaves: int
var _gain: float
var _salt: int

## `1 + gain + gain² + …`, precomputed: the sum of the octave amplitudes, which is what
## `value()` divides by to land back in `[-1, 1]`.
var _amplitude_sum: float


func _init(p_hash: GenerationHash, p_cell_size: int, p_octaves: int, p_gain: float,
		p_salt: int) -> void:
	_hash = p_hash
	_cell_size = p_cell_size
	_octaves = p_octaves
	_gain = p_gain
	_salt = p_salt
	_amplitude_sum = 0.0
	var amplitude := 1.0
	for _octave in p_octaves:
		_amplitude_sum += amplitude
		amplitude *= p_gain


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Builds a layer, or returns null (logged) when the parameters are not ones this
## implementation can honour. **The supported entry point** — `ValueNoise.new()` skips the
## check, and every rejected parameter below is one whose absence would show up as terrain
## rather than as an error.
static func layer(p_hash: GenerationHash, p_cell_size: int, p_octaves: int, p_gain: float,
		p_salt: int) -> ValueNoise:
	var reason := reject_reason(p_hash, p_cell_size, p_octaves, p_gain, p_salt)
	if not Log.check(reason.is_empty(), Log.CH_GEN, "cannot build this noise layer",
			{"reason": reason, "cell": p_cell_size, "octaves": p_octaves, "salt": p_salt}):
		return null
	return ValueNoise.new(p_hash, p_cell_size, p_octaves, p_gain, p_salt)


## Empty string when the parameters describe a layer this implementation can produce,
## otherwise why they do not — the project's string-reason convention, so a caller that
## builds a layer from configuration can report the problem rather than only log it.
static func reject_reason(p_hash: GenerationHash, p_cell_size: int, p_octaves: int,
		p_gain: float, p_salt: int) -> String:
	if p_hash == null:
		return "no world binding"
	if p_cell_size < 1:
		return "cell size %d is not positive" % p_cell_size
	if p_cell_size > MAX_CELL_SIZE_VOXELS:
		return "cell size %d is wider than the world (%d voxels)" % [
				p_cell_size, MAX_CELL_SIZE_VOXELS]
	if p_cell_size & (p_cell_size - 1) != 0:
		# Powers of two only: `cell >> 1` stays exact down the octaves, `float(cell)` is
		# exact, and `floor_mod(x, cell) / float(cell)` is therefore an exact interpolation
		# weight rather than one that rounds differently in different cells.
		return "cell size %d is not a power of two" % p_cell_size
	if p_octaves < 1 or p_octaves > MAX_OCTAVES:
		return "octave count %d is outside 1..%d" % [p_octaves, MAX_OCTAVES]
	if p_cell_size >> (p_octaves - 1) < 1:
		# The finest octave would have a sub-voxel cell, where every column is its own
		# lattice point: that octave is white noise, and reintroduces exactly the spikes
		# this file exists to avoid.
		return "octave %d would have a cell smaller than one voxel at cell size %d" % [
				p_octaves, p_cell_size]
	if p_gain <= 0.0 or p_gain > 1.0:
		return "gain %s is outside (0, 1]" % p_gain
	if p_salt < 1:
		# Salt 0 is `GenerationHash`'s "no salt". A field that leaves it there correlates
		# with every other pass that also left it there (`docs/rng.md` §4).
		return "salt %d is not a named pass salt" % p_salt
	if p_salt >= GenerationHash.SPACE_SALT_STRIDE:
		return "salt %d is not below the space stride %d" % [
				p_salt, GenerationHash.SPACE_SALT_STRIDE]
	return ""


# ---------------------------------------------------------------------------
# Sampling
# ---------------------------------------------------------------------------

## The field at a world column, in `[-1, 1]`.
##
## Pure: same column, same answer, whatever was sampled before it. Clamped at the ends
## because the interpolation is floating point and a normalised sum of values that reach
## exactly ±1 can land one ulp outside — a caller that documents a closed range should get
## a closed range, not one that is closed except on the days it is not.
func value(column: Vector2i) -> float:
	var total := 0.0
	var amplitude := 1.0
	var cell := _cell_size
	var shift := Vector2i.ZERO
	for _octave in _octaves:
		total += amplitude * _octave_at(column, cell, shift)
		amplitude *= _gain
		cell >>= 1
		shift += OCTAVE_LATTICE_STEP
	return clampf(total / _amplitude_sum, -1.0, 1.0)


## The field at a world column, remapped to `[0, 1]`. The form a mask, a weight or a
## classifier wants; `value()` is the form an offset added to a height wants.
func value01(column: Vector2i) -> float:
	return (value(column) + 1.0) * 0.5


## The 3D form of `value()`, at a world voxel rather than a column (brick 077 — caves are
## the first pass that needs a mask varying with height as well as position, §5.6's
## deferred "3D noise").
##
## Trilinear rather than bilinear: each octave hashes the 8 corners of the voxel lattice
## cell it falls in instead of 4, and blends across all three axes with the same
## `fade()`. Everything else — the lattice living in integer voxel space, powers-of-two
## cells, the per-octave lattice offset, the amplitude normalisation — is unchanged from
## `value()`, which is the point: this is the *same* layer, sampled one dimension wider.
## `max_slope_per_voxel()` still bounds the change along any single axis, holding the
## other two fixed, so no separate 3D bound is needed.
func value3(voxel: Vector3i) -> float:
	var total := 0.0
	var amplitude := 1.0
	var cell := _cell_size
	var shift := Vector3i.ZERO
	for _octave in _octaves:
		total += amplitude * _octave_at_3d(voxel, cell, shift)
		amplitude *= _gain
		cell >>= 1
		shift += OCTAVE_LATTICE_STEP_3D
	return clampf(total / _amplitude_sum, -1.0, 1.0)


## `value3()`, remapped to `[0, 1]` — the form a density field or a mask wants.
func value301(voxel: Vector3i) -> float:
	return (value3(voxel) + 1.0) * 0.5


## One octave on its own, in `[-1, 1]`, with octave `0` the coarsest.
##
## For a debug probe, for a test that reconstructs the sum, and for a pass that wants only
## the macro shape of a field without the detail layered on top of it.
func octave_value(column: Vector2i, octave: int) -> float:
	if octave < 0 or octave >= _octaves:
		return 0.0
	return _octave_at(column, _cell_size >> octave, OCTAVE_LATTICE_STEP * octave)


## The 3D form of `octave_value()`.
func octave_value3(voxel: Vector3i, octave: int) -> float:
	if octave < 0 or octave >= _octaves:
		return 0.0
	return _octave_at_3d(voxel, _cell_size >> octave, OCTAVE_LATTICE_STEP_3D * octave)


# ---------------------------------------------------------------------------
# Shape of the layer
# ---------------------------------------------------------------------------

func cell_size() -> int:
	return _cell_size


func octaves() -> int:
	return _octaves


func gain() -> float:
	return _gain


func salt() -> int:
	return _salt


## Cell edge of the finest octave, in voxels — the smallest feature this layer can carry.
func finest_cell_size() -> int:
	return _cell_size >> (_octaves - 1)


## The most `value()` can change between two columns one voxel apart on an axis.
##
## Exact, not measured. Along one axis an octave is `lerp(a, b, fade(t))` with `a, b` in
## `[-1, 1]`, so its slope is at most `2 · FADE_MAX_SLOPE / cell` per voxel; the layer
## normalises by `_amplitude_sum`, so the bound is the amplitude-weighted sum of those.
##
## Worth having as a number rather than a comment: it is what
## `tests/unit/test_value_noise.gd` asserts a real walk of the field against, and a
## coherence claim nothing checks is a coherence claim that quietly stops being true. Note
## that with the usual `gain = 0.5` and halving cells, every octave contributes the *same*
## amount to this bound — detail octaves are not free coherence.
func max_slope_per_voxel() -> float:
	var bound := 0.0
	var amplitude := 1.0
	var cell := _cell_size
	for _octave in _octaves:
		bound += amplitude * 2.0 * FADE_MAX_SLOPE / float(cell)
		amplitude *= _gain
		cell >>= 1
	return bound / _amplitude_sum


## The same bound for `value01()`, which compresses the range by half.
func max_slope01_per_voxel() -> float:
	return max_slope_per_voxel() * 0.5


## Perlin's quintic fade, `6t⁵ − 15t⁴ + 10t³`. Zero first *and* second derivative at both
## ends, so cell boundaries leave no crease in the field — a cubic smoothstep leaves a
## visible one once the field becomes a slope, and a raw linear blend leaves a ridge along
## every lattice line.
##
## Public because it is the project's one blending curve: any later pass that blends
## between two shapes across a band (brick 061's shore band is the first) has the same
## reason to want a `C²` join, and a second copy of the polynomial would be a second thing
## to keep in step with `FADE_MAX_SLOPE`. `t` outside `[0, 1]` is the caller's business —
## clamp before calling, as `_octave_at()` does by construction.
static func fade(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## One octave: hash the four corners of the cell this column falls in, then blend.
##
## `floor_div`/`floor_mod` rather than `/` and `%` is the whole correctness story on
## negative axes — see the class comment.
func _octave_at(column: Vector2i, cell: int, shift: Vector2i) -> float:
	var corner := Vector2i(
			GenerationGrid.floor_div(column.x, cell),
			GenerationGrid.floor_div(column.y, cell)) + shift
	var inverse_cell := 1.0 / float(cell)
	var weight_x := fade(float(GenerationGrid.floor_mod(column.x, cell)) * inverse_cell)
	var weight_z := fade(float(GenerationGrid.floor_mod(column.y, cell)) * inverse_cell)
	var low := lerpf(_corner(corner), _corner(corner + Vector2i(1, 0)), weight_x)
	var high := lerpf(_corner(corner + Vector2i(0, 1)),
			_corner(corner + Vector2i(1, 1)), weight_x)
	return lerpf(low, high, weight_z)


## The value stored at one lattice point, in `[-1, 1)`. Hashed in **column space** — a
## lattice point is a 2D coordinate, and the space tag keeps it from colliding with a
## per-column pass that happens to share this salt.
func _corner(lattice: Vector2i) -> float:
	return _hash.value01_column(lattice, _salt) * 2.0 - 1.0


## One octave of the 3D form: hash the eight corners of the voxel-space lattice cell this
## voxel falls in, then blend across all three axes.
func _octave_at_3d(voxel: Vector3i, cell: int, shift: Vector3i) -> float:
	var corner := Vector3i(
			GenerationGrid.floor_div(voxel.x, cell),
			GenerationGrid.floor_div(voxel.y, cell),
			GenerationGrid.floor_div(voxel.z, cell)) + shift
	var inverse_cell := 1.0 / float(cell)
	var weight_x := fade(float(GenerationGrid.floor_mod(voxel.x, cell)) * inverse_cell)
	var weight_y := fade(float(GenerationGrid.floor_mod(voxel.y, cell)) * inverse_cell)
	var weight_z := fade(float(GenerationGrid.floor_mod(voxel.z, cell)) * inverse_cell)
	var low := lerpf(
			lerpf(_corner3(corner), _corner3(corner + Vector3i(1, 0, 0)), weight_x),
			lerpf(_corner3(corner + Vector3i(0, 1, 0)),
					_corner3(corner + Vector3i(1, 1, 0)), weight_x),
			weight_y)
	var high := lerpf(
			lerpf(_corner3(corner + Vector3i(0, 0, 1)),
					_corner3(corner + Vector3i(1, 0, 1)), weight_x),
			lerpf(_corner3(corner + Vector3i(0, 1, 1)),
					_corner3(corner + Vector3i(1, 1, 1)), weight_x),
			weight_y)
	return lerpf(low, high, weight_z)


## The value stored at one lattice point in **voxel space** — a 3D coordinate, tagged
## separately from `_corner()`'s column space so the two forms of the same layer never
## sample the same hashed corners.
func _corner3(lattice: Vector3i) -> float:
	return _hash.value01_voxel(lattice, _salt) * 2.0 - 1.0
