extends TestCase
## `world/generation/continentalness.gd` — the macro land/ocean field (brick 060).
##
## The layer underneath it is covered by `test_value_noise.gd`; this file is about the
## *configuration*, which is the part baked into every world: the pinned cell size, the
## octave count, the stated range, and whether the field actually spans that range instead
## of hovering around its own middle.

## The digest of `at()` over `GenerationFixtures.columns()` for the `typed` world.
const PINNED_SIGNATURE := "55915711b4f3d3c7"

## The distribution sweep: a square grid of columns spaced by a prime, so no sample lands
## on a lattice line and the span (about 24 coarse cells per axis) covers many continents.
const SWEEP_SIDE := 48
const SWEEP_SPACING := 4093
const SWEEP_ORIGIN := -98232


func _field_for(name: String) -> Continentalness:
	return Continentalness.for_world(GenerationFixtures.hash_for(name))


func _sampler_factory() -> Callable:
	return func(hash: GenerationHash) -> Callable:
		var field := Continentalness.for_world(hash)
		return func(column: Vector2i) -> float: return field.at(column)


# ---------------------------------------------------------------------------
# Binding
# ---------------------------------------------------------------------------

func test_requires_a_world_binding() -> void:
	assert_null(Continentalness.for_world(null))


func test_binds_to_every_fixture_world() -> void:
	for name in GenerationFixtures.world_names():
		assert_not_null(_field_for(name), "world '%s' has a continentalness field" % name)


func test_the_pinned_parameters_are_the_documented_ones() -> void:
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	var noise := field.noise()
	assert_eq(noise.cell_size(), Continentalness.CELL_SIZE_VOXELS)
	assert_eq(noise.octaves(), Continentalness.OCTAVES)
	assert_eq(noise.salt(), WorldHash.SALT_CONTINENTALNESS)
	# The coarsest layer is eight regions across and the finest is exactly one, which is
	# what gives brick 089's region grid a value of its own rather than a neighbour's.
	assert_eq(Continentalness.CELL_SIZE_VOXELS,
			GenerationGrid.REGION_SIZE_VOXELS * 8)
	assert_eq(noise.finest_cell_size(), GenerationGrid.REGION_SIZE_VOXELS)
	assert_almost_eq(Continentalness.cell_size_metres(), 4096.0)


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
		var field := _field_for(name)
		var sampler := func(column: Vector2i) -> float: return field.at(column)
		assert_eq(GenerationFixtures.range_reason(sampler, GenerationFixtures.columns(),
				Continentalness.MINIMUM, Continentalness.MAXIMUM), "",
				"world '%s' stays in range" % name)


func test_varies_across_the_sample_columns() -> void:
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> float: return field.at(column)
	assert_eq(GenerationFixtures.variation_reason(sampler, GenerationFixtures.columns(),
			8), "")


func test_signature_is_pinned() -> void:
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> float: return field.at(column)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.columns()),
			PINNED_SIGNATURE)


# ---------------------------------------------------------------------------
# Behaviour of the field itself
# ---------------------------------------------------------------------------

func test_a_voxel_reads_its_own_column() -> void:
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	for voxel in GenerationFixtures.voxels():
		assert_eq(field.at_voxel(voxel), field.at(GenerationGrid.voxel_to_column(voxel)),
				"voxel %s reads its column" % voxel)


func test_a_kilometre_of_walking_never_jumps_the_field() -> void:
	# The property the whole brick exists for, stated the way a player would feel it:
	# 2000 voxels is a kilometre at 0.5 m per voxel, and over it the field must drift.
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	var bound := field.max_step_per_voxel()
	var largest := 0.0
	var travelled := 0.0
	var previous := field.at(Vector2i(-1000, 613))
	for x in range(-999, 1001):
		var current := field.at(Vector2i(x, 613))
		var step := absf(current - previous)
		largest = maxf(largest, step)
		travelled += step
		previous = current
	assert_true(largest <= bound + 1e-12,
			"largest step %s is within the bound %s" % [largest, bound])
	assert_true(travelled > bound, "the field moves along the kilometre (%s)" % travelled)


func test_the_field_spans_its_range_across_the_world() -> void:
	# A macro field whose values all sit near 0.5 has no oceans and no interiors: it is
	# in range, deterministic, varied, and useless. Nothing else checks this.
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	var lowest := 1.0
	var highest := 0.0
	var total := 0.0
	var count := 0
	for ix in SWEEP_SIDE:
		for iz in SWEEP_SIDE:
			var value := field.at(Vector2i(
					SWEEP_ORIGIN + ix * SWEEP_SPACING,
					SWEEP_ORIGIN + iz * SWEEP_SPACING))
			lowest = minf(lowest, value)
			highest = maxf(highest, value)
			total += value
			count += 1
	assert_eq(count, SWEEP_SIDE * SWEEP_SIDE)
	assert_true(lowest < 0.35, "the sweep reaches ocean (lowest %s)" % lowest)
	assert_true(highest > 0.65, "the sweep reaches deep inland (highest %s)" % highest)
	assert_in_range(total / float(count), 0.4, 0.6,
			"the field is centred, not biased to one side")
