extends TestCase
## `world/generation/value_noise.gd` — the coherent noise layer (brick 060).
##
## Determinism is checked through `GenerationFixtures` (059) rather than by hand, so this
## file only has to supply the pass. What it adds on top of the shared floor is the one
## property the fixtures cannot know about: **coherence**. A field that passed every
## determinism check and still jumped by 2.0 between neighbouring columns would be white
## noise with extra steps, so `max_slope_per_voxel()` is asserted against a real walk of
## the field — and the same walk is run over raw `GenerationHash` values to prove the
## check can fail.

const SALT := WorldHash.SALT_CONTINENTALNESS
const CELL := 1024
const OCTAVES := 4
const GAIN := 0.5

## The digest of `value()` over `GenerationFixtures.columns()` for the `typed` world.
## When this moves, the question is the one `docs/world-generation.md` §2.1 asks: a bug,
## or a generation version bump?
const PINNED_SIGNATURE := "0d355b4d9ddddd7d"

## Slack allowed when comparing a measured step against an analytic bound: the bound is
## exact in real arithmetic, and the measurement is double precision.
const SLOPE_EPSILON := 1e-12


func _layer_for(hash: GenerationHash) -> ValueNoise:
	return ValueNoise.layer(hash, CELL, OCTAVES, GAIN, SALT)


func _sampler_factory() -> Callable:
	return func(hash: GenerationHash) -> Callable:
		var layer := _layer_for(hash)
		return func(column: Vector2i) -> float: return layer.value(column)


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func test_accepts_a_well_formed_layer() -> void:
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_eq(ValueNoise.reject_reason(hash, CELL, OCTAVES, GAIN, SALT), "")
	var layer := _layer_for(hash)
	assert_not_null(layer)
	assert_eq(layer.cell_size(), CELL)
	assert_eq(layer.octaves(), OCTAVES)
	assert_eq(layer.gain(), GAIN)
	assert_eq(layer.salt(), SALT)
	assert_eq(layer.finest_cell_size(), CELL >> (OCTAVES - 1))


func test_rejects_parameters_it_cannot_honour() -> void:
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var rejected := {
		"no world binding": [null, CELL, OCTAVES, GAIN, SALT],
		"cell size 0": [hash, 0, OCTAVES, GAIN, SALT],
		"negative cell size": [hash, -1024, OCTAVES, GAIN, SALT],
		"cell size wider than the world": [hash, ValueNoise.MAX_CELL_SIZE_VOXELS * 2,
				OCTAVES, GAIN, SALT],
		"cell size that is not a power of two": [hash, 1000, OCTAVES, GAIN, SALT],
		"zero octaves": [hash, CELL, 0, GAIN, SALT],
		"more octaves than the cap": [hash, CELL, ValueNoise.MAX_OCTAVES + 1, GAIN, SALT],
		"more octaves than the cell size can carry": [hash, 4, 4, GAIN, SALT],
		"zero gain": [hash, CELL, OCTAVES, 0.0, SALT],
		"gain above one": [hash, CELL, OCTAVES, 1.5, SALT],
		"the unsalted default": [hash, CELL, OCTAVES, GAIN, 0],
		"a salt at or above the space stride": [hash, CELL, OCTAVES, GAIN,
				GenerationHash.SPACE_SALT_STRIDE],
	}
	for description in rejected:
		var args: Array = rejected[description]
		assert_ne(ValueNoise.reject_reason(args[0], args[1], args[2], args[3], args[4]), "",
				"rejects %s" % description)
	# ... and the checked entry point returns null rather than a half-configured layer.
	assert_null(ValueNoise.layer(hash, 1000, OCTAVES, GAIN, SALT))


func test_the_finest_octave_is_still_at_least_one_voxel() -> void:
	# The boundary of the octave-count rule, from both sides: cell 8 carries four octaves
	# (8, 4, 2, 1) and not five.
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_eq(ValueNoise.reject_reason(hash, 8, 4, GAIN, SALT), "")
	assert_ne(ValueNoise.reject_reason(hash, 8, 5, GAIN, SALT), "")


# ---------------------------------------------------------------------------
# The shared determinism floor
# ---------------------------------------------------------------------------

func test_is_deterministic() -> void:
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory: Callable = _sampler_factory()
	assert_eq(GenerationFixtures.determinism_reason(factory.bind(hash),
			GenerationFixtures.columns()), "")


func test_is_seed_sensitive() -> void:
	assert_eq(GenerationFixtures.seed_sensitivity_reason(_sampler_factory(),
			GenerationFixtures.columns()), "")


func test_stays_in_its_stated_range() -> void:
	for name in GenerationFixtures.world_names():
		var layer := _layer_for(GenerationFixtures.hash_for(name))
		var signed := func(column: Vector2i) -> float: return layer.value(column)
		var unit := func(column: Vector2i) -> float: return layer.value01(column)
		assert_eq(GenerationFixtures.range_reason(signed, GenerationFixtures.columns(),
				-1.0, 1.0), "", "world '%s' stays in [-1, 1]" % name)
		assert_eq(GenerationFixtures.range_reason(unit, GenerationFixtures.columns(),
				0.0, 1.0), "", "world '%s' stays in [0, 1]" % name)


func test_varies_across_the_sample_columns() -> void:
	var layer := _layer_for(GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED))
	var sampler := func(column: Vector2i) -> float: return layer.value(column)
	assert_eq(GenerationFixtures.variation_reason(sampler, GenerationFixtures.columns(),
			8), "")


func test_signature_is_pinned() -> void:
	var layer := _layer_for(GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED))
	var sampler := func(column: Vector2i) -> float: return layer.value(column)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.columns()),
			PINNED_SIGNATURE)


# ---------------------------------------------------------------------------
# Coherence — the property the fixtures cannot check
# ---------------------------------------------------------------------------

## A walk of adjacent columns, starting well inside the negative quadrant so the walk
## crosses cell boundaries and the origin on the way.
func _walk() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for step in range(-600, 601):
		out.append(Vector2i(step, -37))
	return out


func test_neighbouring_columns_stay_within_the_slope_bound() -> void:
	var layer := _layer_for(GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED))
	var bound := layer.max_slope_per_voxel()
	var walk := _walk()
	var largest := 0.0
	var travelled := 0.0
	var previous := layer.value(walk[0])
	for index in range(1, walk.size()):
		var current := layer.value(walk[index])
		var step := absf(current - previous)
		largest = maxf(largest, step)
		travelled += step
		previous = current
	assert_true(largest <= bound + SLOPE_EPSILON,
			"largest step %s is within the bound %s" % [largest, bound])
	# ... and the field is not simply flat, which would also satisfy the bound.
	assert_true(travelled > bound, "the field actually moves along the walk (%s)" % travelled)


func test_the_slope_bound_is_a_real_constraint() -> void:
	# The same walk over raw positional hashing — the thing this layer exists to replace.
	# If white noise passed the check above, the check would be measuring nothing.
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var layer := _layer_for(hash)
	var bound := layer.max_slope_per_voxel()
	var walk := _walk()
	var largest := 0.0
	var previous := hash.value01_column(walk[0], SALT) * 2.0 - 1.0
	for index in range(1, walk.size()):
		var current := hash.value01_column(walk[index], SALT) * 2.0 - 1.0
		largest = maxf(largest, absf(current - previous))
		previous = current
	assert_true(largest > bound,
			"white noise breaks the bound (%s against %s)" % [largest, bound])


func test_crosses_the_origin_without_a_seam() -> void:
	# The floor-division test. A truncating implementation puts voxel -1 and voxel 0 in
	# the same cell with a negative interpolation weight, which shows up here as a step far
	# larger than the bound, and everywhere else as a world mirrored about the origin.
	var layer := _layer_for(GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED))
	var bound := layer.max_slope_per_voxel()
	for seam in [
		[Vector2i(-1, 0), Vector2i(0, 0)],
		[Vector2i(0, -1), Vector2i(0, 0)],
		[Vector2i(-1, -1), Vector2i(0, -1)],
	]:
		var step := absf(layer.value(seam[1]) - layer.value(seam[0]))
		assert_true(step <= bound + SLOPE_EPSILON,
				"%s -> %s is a step of %s, bound %s" % [seam[0], seam[1], step, bound])


func test_is_not_mirrored_about_the_origin() -> void:
	var layer := _layer_for(GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED))
	for column in [Vector2i(7, 9), Vector2i(512, 256), Vector2i(9, -9),
			Vector2i(CELL, 3 * CELL)]:
		assert_ne(layer.value(column), layer.value(-column),
				"%s and its mirror are different places" % column)


# ---------------------------------------------------------------------------
# Structure
# ---------------------------------------------------------------------------

func test_anchors_on_its_lattice_points() -> void:
	# A single octave sampled exactly on a lattice point must return that point's stored
	# value untouched: both interpolation weights are 0, so nothing is blended in. This is
	# what makes the layer a value noise rather than an unspecified smooth thing.
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var layer := ValueNoise.layer(hash, CELL, 1, GAIN, SALT)
	for lattice in [Vector2i(0, 0), Vector2i(1, -2), Vector2i(-3, -4)]:
		var expected := hash.value01_column(lattice, SALT) * 2.0 - 1.0
		assert_almost_eq(layer.value(lattice * CELL), expected, 1e-15,
				"lattice point %s" % lattice)


func test_is_the_normalised_sum_of_its_octaves() -> void:
	var layer := _layer_for(GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED))
	for column in GenerationFixtures.columns():
		var total := 0.0
		var amplitude := 1.0
		var normaliser := 0.0
		for octave in OCTAVES:
			total += amplitude * layer.octave_value(column, octave)
			normaliser += amplitude
			amplitude *= GAIN
		assert_almost_eq(layer.value(column), clampf(total / normaliser, -1.0, 1.0), 1e-12,
				"column %s" % column)


func test_octave_value_is_zero_outside_the_layer() -> void:
	var layer := _layer_for(GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED))
	assert_eq(layer.octave_value(Vector2i(3, 5), -1), 0.0)
	assert_eq(layer.octave_value(Vector2i(3, 5), OCTAVES), 0.0)


func test_octaves_do_not_all_agree_at_the_origin() -> void:
	# Without the per-octave lattice offset every octave samples lattice (0, 0) at the
	# world origin and returns the same value, putting a spike at the one coordinate every
	# other test measures from.
	var layer := _layer_for(GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED))
	var seen: Dictionary = {}
	for octave in OCTAVES:
		seen[layer.octave_value(Vector2i.ZERO, octave)] = true
	assert_size(seen, OCTAVES)


func test_max_slope_matches_the_analytic_bound() -> void:
	# With gain 0.5 and halving cells every octave contributes the same amount to the
	# bound — detail octaves buy detail, not coherence.
	var layer := _layer_for(GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED))
	var amplitude_sum := 0.0
	var amplitude := 1.0
	for _octave in OCTAVES:
		amplitude_sum += amplitude
		amplitude *= GAIN
	var expected := OCTAVES * 2.0 * ValueNoise.FADE_MAX_SLOPE / float(CELL) / amplitude_sum
	assert_almost_eq(layer.max_slope_per_voxel(), expected, 1e-15)
	assert_almost_eq(layer.max_slope01_per_voxel(), expected * 0.5, 1e-15)
