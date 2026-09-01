extends TestCase
## `world/generation/erosion_pass.gd` — where the ground may be rugged (brick 062).
##
## Everything underneath is already covered (`test_value_noise.gd`,
## `test_continentalness.gd`, `test_elevation_field.gd`), so this file is about what 062
## adds: the two flattening curves, the invariant that the pass only ever lowers ground
## (`base <= at <= unshaped`), and the claim the brick exists to make — that the world now
## has both plains and rugged ground instead of one uniformly hilly landmass.

## The digest of `at()` over `GenerationFixtures.columns()` for the `typed` world.
const PINNED_SIGNATURE := "cc4f0f5ecb8fa581"

## The distribution sweep. Same shape and spacing as `test_elevation_field.gd`'s, so the
## two files' measurements are comparable column for column.
const SWEEP_SIDE := 48
const SWEEP_SPACING := 4093
const SWEEP_ORIGIN := -98232


func _pass_for(name: String) -> ErosionPass:
	return ErosionPass.for_world(GenerationFixtures.hash_for(name))


func _sampler_factory() -> Callable:
	return func(hash: GenerationHash) -> Callable:
		var shaped := ErosionPass.for_world(hash)
		return func(column: Vector2i) -> float: return shaped.at(column)


## Every column of the distribution sweep, as a plain list.
func _sweep_columns() -> Array[Vector2i]:
	var columns: Array[Vector2i] = []
	for ix in SWEEP_SIDE:
		for iz in SWEEP_SIDE:
			columns.append(Vector2i(SWEEP_ORIGIN + ix * SWEEP_SPACING,
					SWEEP_ORIGIN + iz * SWEEP_SPACING))
	return columns


# ---------------------------------------------------------------------------
# Binding
# ---------------------------------------------------------------------------

func test_requires_a_world_binding() -> void:
	assert_null(ErosionPass.for_world(null))


func test_binds_to_every_fixture_world() -> void:
	for name in GenerationFixtures.world_names():
		assert_not_null(_pass_for(name), "world '%s' has an erosion pass" % name)


func test_the_pinned_parameters_are_the_documented_ones() -> void:
	var shaped := _pass_for(GenerationFixtures.WORLD_TYPED)
	var ruggedness := shaped.ruggedness_noise()
	assert_eq(ruggedness.cell_size(), ErosionPass.RUGGEDNESS_CELL_SIZE_VOXELS)
	assert_eq(ruggedness.octaves(), ErosionPass.RUGGEDNESS_OCTAVES)
	# Its own salt: a ruggedness field that agreed with the relief it modulates would
	# place mountains exactly where the relief already peaks, which is not a decision.
	assert_eq(ruggedness.salt(), WorldHash.SALT_RUGGEDNESS)
	assert_ne(ruggedness.salt(), shaped.elevation().relief_noise().salt())
	assert_ne(ruggedness.salt(),
			shaped.elevation().continentalness().noise().salt())


func test_every_ruggedness_scale_is_coarser_than_every_relief_scale() -> void:
	# The property the octave count is chosen for: a weight field finer than the field it
	# weights stops placing relief and starts being relief.
	var shaped := _pass_for(GenerationFixtures.WORLD_TYPED)
	var finest_weight := shaped.ruggedness_noise().finest_cell_size()
	var coarsest_relief := shaped.elevation().relief_noise().cell_size()
	assert_true(finest_weight > coarsest_relief,
			"the finest ruggedness cell (%d) is coarser than the coarsest relief cell (%d)"
					% [finest_weight, coarsest_relief])
	assert_eq(finest_weight, 2048)
	assert_almost_eq(ErosionPass.ruggedness_cell_metres(), 4096.0)
	assert_almost_eq(ErosionPass.finest_ruggedness_metres(), 1024.0)


func test_the_range_is_the_field_it_shapes() -> void:
	# The pass multiplies relief by factors in [0, 1] and never touches the base, so it
	# inherits 061's range exactly. Asserted because every range check below uses it.
	assert_almost_eq(ErosionPass.MINIMUM_VOXELS, ElevationField.MINIMUM_VOXELS)
	assert_almost_eq(ErosionPass.MAXIMUM_VOXELS, ElevationField.MAXIMUM_VOXELS)


# ---------------------------------------------------------------------------
# The two curves
# ---------------------------------------------------------------------------

func test_the_ruggedness_curve_reaches_both_of_its_ends() -> void:
	assert_almost_eq(ErosionPass.ruggedness_weight(0.0), ErosionPass.RUGGEDNESS_FLOOR,
			1e-12)
	assert_almost_eq(ErosionPass.ruggedness_weight(1.0), 1.0, 1e-12)


func test_the_ruggedness_curve_is_monotone_and_leans_on_the_floor() -> void:
	# Squared, not linear: at the middle of its input the curve has to sit well below the
	# middle of its output, or "flat is the default" is only a comment.
	var midpoint := (ErosionPass.RUGGEDNESS_FLOOR + 1.0) * 0.5
	assert_true(ErosionPass.ruggedness_weight(0.5) < midpoint - 0.15,
			"half the noise buys much less than half the amplitude (%s vs %s)" % [
					ErosionPass.ruggedness_weight(0.5), midpoint])
	var previous := -1.0
	for step in 201:
		var value := ErosionPass.ruggedness_weight(float(step) / 200.0)
		assert_true(value >= previous, "the curve never goes back down at step %d" % step)
		assert_in_range(value, ErosionPass.RUGGEDNESS_FLOOR, 1.0,
				"step %d stays inside the weight range" % step)
		previous = value


func test_the_valley_curve_fixes_both_ends_and_lowers_everything_between() -> void:
	# Fixed points at 0 and 1 are what let 061's stated range survive this pass untouched;
	# strictly below in between is what makes it erosion rather than a rescale.
	assert_almost_eq(ErosionPass.valley_shaped(0.0), 0.0, 1e-12)
	assert_almost_eq(ErosionPass.valley_shaped(1.0), 1.0, 1e-12)
	var previous := -1.0
	for step in 201:
		var relief := float(step) / 200.0
		var shaped := ErosionPass.valley_shaped(relief)
		assert_in_range(shaped, 0.0, 1.0, "step %d stays in [0, 1]" % step)
		assert_true(shaped >= previous, "the curve never goes back down at step %d" % step)
		if step > 0 and step < 200:
			assert_true(shaped < relief,
					"relief %s is lowered to %s" % [relief, shaped])
		previous = shaped


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
		var shaped := _pass_for(name)
		var sampler := func(column: Vector2i) -> float: return shaped.at(column)
		assert_eq(GenerationFixtures.range_reason(sampler, GenerationFixtures.columns(),
				ErosionPass.MINIMUM_VOXELS, ErosionPass.MAXIMUM_VOXELS), "",
				"world '%s' stays in range" % name)


func test_varies_across_the_sample_columns() -> void:
	var shaped := _pass_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> float: return shaped.at(column)
	assert_eq(GenerationFixtures.variation_reason(sampler, GenerationFixtures.columns(),
			8), "")


func test_signature_is_pinned() -> void:
	var shaped := _pass_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> float: return shaped.at(column)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.columns()),
			PINNED_SIGNATURE)


# ---------------------------------------------------------------------------
# The invariant: a pass only ever lowers the ground
# ---------------------------------------------------------------------------

func test_the_pass_lowers_the_ground_and_never_raises_it() -> void:
	# `base <= at <= unshaped`, the invariant that makes this a pass over 061 rather than a
	# second height field — and the shape of all four of the original's own post-passes
	# (`terrain-base-height-field.md` INV-2). Checked on the fixture columns, which include
	# the negative axes and the world corners, and on the whole distribution sweep.
	for name in GenerationFixtures.world_names():
		var shaped := _pass_for(name)
		var columns: Array[Vector2i] = []
		columns.assign(GenerationFixtures.columns())
		columns.append_array(_sweep_columns())
		for column in columns:
			var height := shaped.at(column)
			assert_true(height <= shaped.unshaped_at(column) + 1e-9,
					"world '%s' column %s is not raised" % [name, column])
			assert_true(height >= shaped.base_at(column) - 1e-9,
					"world '%s' column %s stays above its base" % [name, column])


func test_the_terms_multiply_to_the_whole() -> void:
	# `base_at()`, `ruggedness_at()` and `shaped_relief_at()` are what bricks 063 and 066
	# will read; they have to be the terms `at()` actually combines, not a second
	# implementation that drifts from it.
	var shaped := _pass_for(GenerationFixtures.WORLD_TYPED)
	var ground := shaped.elevation()
	for column in GenerationFixtures.columns():
		var rebuilt := (shaped.base_at(column)
				+ ground.relief_amplitude_at(column) * shaped.shaped_relief_at(column))
		assert_almost_eq(shaped.at(column), rebuilt, 1e-9,
				"column %s decomposes into its own terms" % column)
		assert_almost_eq(shaped.shaped_relief_at(column),
				shaped.ruggedness_at(column)
						* ErosionPass.valley_shaped(shaped.relief_at(column)), 1e-12,
				"column %s's shaped relief is its two curves multiplied" % column)
		assert_true(shaped.removed_at(column) >= -1e-9,
				"column %s removed a non-negative amount" % column)


func test_a_voxel_reads_its_own_column() -> void:
	var shaped := _pass_for(GenerationFixtures.WORLD_TYPED)
	for voxel in GenerationFixtures.voxels():
		assert_eq(shaped.at_voxel(voxel),
				shaped.at(GenerationGrid.voxel_to_column(voxel)),
				"voxel %s reads its column" % voxel)


func test_at_metres_is_the_voxel_height_converted() -> void:
	var shaped := _pass_for(GenerationFixtures.WORLD_TYPED)
	for column in GenerationFixtures.columns():
		assert_almost_eq(shaped.at_metres(column),
				WorldScale.voxels_to_metres(shaped.at(column)), 1e-9)


# ---------------------------------------------------------------------------
# What the pass is for
# ---------------------------------------------------------------------------

func test_the_world_now_has_both_plains_and_rugged_ground() -> void:
	# The claim of the brick. Before 062 every landward column carried the same relief
	# budget; after it, the sweep has to contain ground near both ends of the ruggedness
	# weight, and the average column has to be closer to the floor than to the ceiling —
	# that is what squaring the weight field buys.
	var shaped := _pass_for(GenerationFixtures.WORLD_TYPED)
	var lowest := 2.0
	var highest := -1.0
	var total := 0.0
	var columns := _sweep_columns()
	for column in columns:
		var weight := shaped.ruggedness_at(column)
		lowest = minf(lowest, weight)
		highest = maxf(highest, weight)
		total += weight
	var mean := total / float(columns.size())
	assert_true(lowest < ErosionPass.RUGGEDNESS_FLOOR + 0.1,
			"the sweep finds near-flat ground (lowest weight %s)" % lowest)
	assert_true(highest > 0.7,
			"the sweep finds rugged ground (highest weight %s)" % highest)
	assert_true(mean < 0.45,
			"the average column is closer to flat than to rugged (mean %s)" % mean)


func test_the_flattest_ground_is_flatter_than_the_most_rugged() -> void:
	# `RUGGEDNESS_FLOOR` and the squaring only mean something if they are observable in the
	# terrain rather than only in the constants. Find the sweep's extremes of ruggedness,
	# then walk a kilometre through each and compare how much the ground climbs.
	var shaped := _pass_for(GenerationFixtures.WORLD_TYPED)
	var flattest := Vector2i.ZERO
	var roughest := Vector2i.ZERO
	var lowest := 2.0
	var highest := -1.0
	for column in _sweep_columns():
		# Only landward columns: an ocean floor is already flattened by 061's own ocean
		# scale, which would answer this question for the wrong reason.
		if shaped.elevation().shore_at(column) < 0.999:
			continue
		var weight := shaped.ruggedness_at(column)
		if weight < lowest:
			lowest = weight
			flattest = column
		if weight > highest:
			highest = weight
			roughest = column
	assert_true(highest > lowest, "the sweep found landward ground at both extremes")
	assert_true(_climb_along(shaped, flattest) * 2.0 < _climb_along(shaped, roughest),
			"the plain at %s climbs far less than the rugged ground at %s" % [
					flattest, roughest])


func test_the_pass_removes_real_height() -> void:
	# A pass whose factors were all near 1 would satisfy every invariant above and change
	# nothing. Measure how much ground it actually takes away across the sweep.
	var shaped := _pass_for(GenerationFixtures.WORLD_TYPED)
	var total := 0.0
	var largest := 0.0
	var columns := _sweep_columns()
	for column in columns:
		var removed := shaped.removed_at(column)
		total += removed
		largest = maxf(largest, removed)
	var mean := total / float(columns.size())
	assert_true(mean > 16.0,
			"the pass removes real height on average (%s voxels)" % mean)
	assert_true(largest > 80.0,
			"the pass flattens some column hard (%s voxels)" % largest)


func test_a_kilometre_of_walking_is_walkable() -> void:
	# 2000 voxels is a kilometre at 0.5 m per voxel. Every step stays inside the derived
	# bound, and the ground still goes somewhere over the distance — an erosion pass that
	# flattened everything would pass the bound and fail the world.
	var shaped := _pass_for(GenerationFixtures.WORLD_TYPED)
	var bound := shaped.max_step_per_voxel()
	var largest := 0.0
	var travelled := 0.0
	var previous := shaped.at(Vector2i(-1000, 613))
	for x in range(-999, 1001):
		var current := shaped.at(Vector2i(x, 613))
		var step := absf(current - previous)
		largest = maxf(largest, step)
		travelled += step
		previous = current
	assert_true(largest <= bound + 1e-12,
			"largest step %s is within the bound %s" % [largest, bound])
	assert_true(travelled > 4.0,
			"the ground moves along the kilometre (%s voxels of climb)" % travelled)


func test_the_step_bound_is_a_real_constraint() -> void:
	# The bound is only worth asserting if it can fail. Raw positional hashing over the
	# same range and the same amplitude is the terrain this pass exists not to produce.
	var shaped := _pass_for(GenerationFixtures.WORLD_TYPED)
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var bound := shaped.max_step_per_voxel()
	var span := ErosionPass.MAXIMUM_VOXELS - ErosionPass.MINIMUM_VOXELS
	var violations := 0
	var previous := hash.value01_column(Vector2i(-100, 613), WorldHash.SALT_RUGGEDNESS)
	for x in range(-99, 101):
		var current := hash.value01_column(Vector2i(x, 613), WorldHash.SALT_RUGGEDNESS)
		if absf(current - previous) * span > bound:
			violations += 1
		previous = current
	assert_true(violations > 100,
			"white noise breaks the bound almost everywhere (%d of 200)" % violations)


func test_the_shaped_world_still_spans_sea_floor_and_high_ground() -> void:
	# 061's own distribution check, re-run after the pass. Flattening the world is only
	# correct if the extremes survive it: a pass that pulled every peak down to the plain
	# would satisfy every invariant in this file and delete the terrain.
	var shaped := _pass_for(GenerationFixtures.WORLD_TYPED)
	var lowest := ErosionPass.MAXIMUM_VOXELS
	var highest := ErosionPass.MINIMUM_VOXELS
	for column in _sweep_columns():
		var value := shaped.at(column)
		lowest = minf(lowest, value)
		highest = maxf(highest, value)
	assert_true(lowest < ElevationField.OCEAN_FLOOR_VOXELS + 24.0,
			"the sweep still reaches an ocean basin (lowest %s)" % lowest)
	assert_true(highest > ElevationField.LAND_BASE_VOXELS + 48.0,
			"the sweep still reaches high ground (highest %s)" % highest)


## Total absolute change in shaped ground height over a kilometre east from `start`.
func _climb_along(shaped: ErosionPass, start: Vector2i) -> float:
	var travelled := 0.0
	var previous := shaped.at(start)
	for step in range(1, 2001):
		var current := shaped.at(start + Vector2i(step, 0))
		travelled += absf(current - previous)
		previous = current
	return travelled
