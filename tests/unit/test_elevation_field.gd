extends TestCase
## `world/generation/elevation_field.gd` — where the ground stands (brick 061).
##
## The two layers underneath are already covered (`test_value_noise.gd`,
## `test_continentalness.gd`), so this file is about what 061 adds: the shore curve, the
## composition of base + amplitude · relief, the stated vertical range and its headroom
## inside `WorldBounds`, and the two claims a height field lives or dies by — that it is
## walkable (a bounded step per voxel) and that it actually produces both sea floor and
## high ground rather than one flat plane at the average of the two.

## The digest of `at()` over `GenerationFixtures.columns()` for the `typed` world.
const PINNED_SIGNATURE := "0babd0a337dd7cab"

## The distribution sweep. Same shape as `test_continentalness.gd`'s — a square grid spaced
## by a prime so no sample lands on a lattice line — but far tighter, because elevation has
## to be checked at scales a player walks through, not only at continent scale.
const SWEEP_SIDE := 48
const SWEEP_SPACING := 4093
const SWEEP_ORIGIN := -98232


func _field_for(name: String) -> ElevationField:
	return ElevationField.for_world(GenerationFixtures.hash_for(name))


func _sampler_factory() -> Callable:
	return func(hash: GenerationHash) -> Callable:
		var field := ElevationField.for_world(hash)
		return func(column: Vector2i) -> float: return field.at(column)


# ---------------------------------------------------------------------------
# Binding
# ---------------------------------------------------------------------------

func test_requires_a_world_binding() -> void:
	assert_null(ElevationField.for_world(null))


func test_binds_to_every_fixture_world() -> void:
	for name in GenerationFixtures.world_names():
		assert_not_null(_field_for(name), "world '%s' has an elevation field" % name)


func test_the_pinned_parameters_are_the_documented_ones() -> void:
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	var relief := field.relief_noise()
	assert_eq(relief.cell_size(), ElevationField.RELIEF_CELL_SIZE_VOXELS)
	assert_eq(relief.octaves(), ElevationField.RELIEF_OCTAVES)
	# Its own salt, not continentalness's: two fields sharing a salt are one field.
	assert_eq(relief.salt(), WorldHash.SALT_ELEVATION)
	assert_ne(relief.salt(), field.continentalness().noise().salt())
	# The relief layer starts exactly where continentalness stops, so the two fields meet
	# at the region grid instead of both carrying region-scale variation.
	assert_eq(ElevationField.RELIEF_CELL_SIZE_VOXELS,
			field.continentalness().noise().finest_cell_size())
	assert_eq(relief.finest_cell_size(), 32)
	assert_almost_eq(ElevationField.finest_relief_metres(), 16.0)


# ---------------------------------------------------------------------------
# The stated range
# ---------------------------------------------------------------------------

func test_the_stated_range_is_the_one_the_constants_produce() -> void:
	# Relief is additive-upward, so the floor is the bare ocean floor and the ceiling is
	# the continental base with all of its relief on top. Asserted rather than trusted,
	# because `MINIMUM_VOXELS` is what every range check in this file is measured against.
	assert_almost_eq(ElevationField.MINIMUM_VOXELS, -96.0)
	assert_almost_eq(ElevationField.MAXIMUM_VOXELS, 192.0)
	assert_true(ElevationField.MAXIMUM_VOXELS > ElevationField.MINIMUM_VOXELS,
			"the range is not inverted")


func test_the_range_leaves_headroom_inside_the_world_bounds() -> void:
	# A peak at the world ceiling has no sky above it and a sea floor at the world floor
	# has no room for brick 077's caves under it. A quarter of the extent, either way.
	var half := float(WorldBounds.HALF_EXTENT_VERTICAL_VOXELS)
	assert_true(ElevationField.MAXIMUM_VOXELS < half * 0.25,
			"peaks (%s) stay well under the world ceiling (%s)" % [
					ElevationField.MAXIMUM_VOXELS, half])
	assert_true(ElevationField.MINIMUM_VOXELS > -half * 0.25,
			"the sea floor (%s) stays well over the world floor (%s)" % [
					ElevationField.MINIMUM_VOXELS, -half])


# ---------------------------------------------------------------------------
# The shore curve
# ---------------------------------------------------------------------------

func test_the_shore_curve_is_flat_outside_its_band() -> void:
	var seaward: Array[float] = [0.0, 0.1, ElevationField.SHORE_LOW]
	for c in seaward:
		assert_almost_eq(ElevationField.shore_weight(c), 0.0, 1e-12,
				"continentalness %s is fully seaward" % c)
	var landward: Array[float] = [ElevationField.SHORE_HIGH, 0.9, 1.0]
	for c in landward:
		assert_almost_eq(ElevationField.shore_weight(c), 1.0, 1e-12,
				"continentalness %s is fully landward" % c)


func test_the_shore_curve_is_monotone_and_centred() -> void:
	assert_almost_eq(ElevationField.shore_weight(ElevationField.SHORE_MIDPOINT), 0.5,
			1e-12)
	var previous := -1.0
	for step in 201:
		var value := ElevationField.shore_weight(float(step) / 200.0)
		assert_true(value >= previous, "the curve never goes back down at step %d" % step)
		assert_in_range(value, 0.0, 1.0, "step %d stays in [0, 1]" % step)
		previous = value


func test_the_shore_curve_has_no_kink_at_the_band_edges() -> void:
	# The reason it is the quintic and not a cubic smoothstep: a slope discontinuity in a
	# blend becomes a crease running along a continentalness contour, which reads in-game
	# as a straight terrace following the coast. Measure the slope just inside each edge;
	# with zero first derivative at both ends it must be near zero, where a cubic
	# smoothstep would show its full 1.5 / SHORE_WIDTH.
	var delta := 1e-4
	var edges: Array[float] = [ElevationField.SHORE_LOW, ElevationField.SHORE_HIGH]
	var inward: Array[float] = [delta, -delta]
	for index in edges.size():
		var edge := edges[index]
		var slope := absf(ElevationField.shore_weight(edge + inward[index])
				- ElevationField.shore_weight(edge)) / delta
		assert_true(slope < 0.01 * ElevationField.shore_max_slope(),
				"the curve leaves edge %s flat (slope %s)" % [edge, slope])


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
				ElevationField.MINIMUM_VOXELS, ElevationField.MAXIMUM_VOXELS), "",
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
# Composition
# ---------------------------------------------------------------------------

func test_a_voxel_reads_its_own_column() -> void:
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	for voxel in GenerationFixtures.voxels():
		assert_eq(field.at_voxel(voxel), field.at(GenerationGrid.voxel_to_column(voxel)),
				"voxel %s reads its column" % voxel)


func test_the_pieces_sum_to_the_whole() -> void:
	# `base_at()`, `relief_amplitude_at()` and `relief_at()` are what bricks 062 and 063
	# will erode and terrace against; they have to be the same terms `at()` adds, not a
	# second implementation that drifts from it.
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	for column in GenerationFixtures.columns():
		var rebuilt := (field.base_at(column)
				+ field.relief_amplitude_at(column) * field.relief_at(column))
		assert_almost_eq(field.at(column), rebuilt, 1e-9,
				"column %s decomposes into its own terms" % column)


func test_relief_never_digs_below_the_base() -> void:
	# The one shape decision taken from the original: relief is additive-upward, so the
	# base is a floor. An ocean floor stays an ocean floor whatever the noise says.
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	for column in GenerationFixtures.columns():
		assert_true(field.at(column) >= field.base_at(column) - 1e-9,
				"column %s stands at or above its base" % column)


func test_at_metres_is_the_voxel_height_converted() -> void:
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	for column in GenerationFixtures.columns():
		assert_almost_eq(field.at_metres(column),
				WorldScale.voxels_to_metres(field.at(column)), 1e-9)


# ---------------------------------------------------------------------------
# The two claims a height field lives on
# ---------------------------------------------------------------------------

func test_a_kilometre_of_walking_is_walkable() -> void:
	# 2000 voxels is a kilometre at 0.5 m per voxel. Every step must stay inside the
	# derived bound, and the ground must actually go somewhere over the distance.
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
	assert_true(travelled > 8.0,
			"the ground moves along the kilometre (%s voxels of climb)" % travelled)


func test_the_step_bound_is_a_real_constraint() -> void:
	# The bound is only worth asserting if it can fail. Raw positional hashing over the
	# same range and the same amplitude is the field this brick exists not to be.
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var bound := field.max_step_per_voxel()
	var span := ElevationField.MAXIMUM_VOXELS - ElevationField.MINIMUM_VOXELS
	var violations := 0
	var previous := hash.value01_column(Vector2i(-100, 613), WorldHash.SALT_ELEVATION)
	for x in range(-99, 101):
		var current := hash.value01_column(Vector2i(x, 613), WorldHash.SALT_ELEVATION)
		if absf(current - previous) * span > bound:
			violations += 1
		previous = current
	assert_true(violations > 100,
			"white noise breaks the bound almost everywhere (%d of 200)" % violations)


func test_the_field_spans_sea_floor_and_high_ground() -> void:
	# A height field whose values all sit near the middle is deterministic, in range,
	# varied — and a featureless plain. Nothing else in this file checks it.
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	var lowest := ElevationField.MAXIMUM_VOXELS
	var highest := ElevationField.MINIMUM_VOXELS
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
	assert_true(lowest < ElevationField.OCEAN_FLOOR_VOXELS + 24.0,
			"the sweep reaches an ocean basin (lowest %s)" % lowest)
	assert_true(highest > ElevationField.LAND_BASE_VOXELS + 96.0,
			"the sweep reaches high ground (highest %s)" % highest)
	assert_in_range(total / float(count), ElevationField.MINIMUM_VOXELS + 32.0,
			ElevationField.MAXIMUM_VOXELS - 32.0,
			"the mean sits between the extremes rather than at one of them")


func test_the_relief_amplitude_blend_reaches_both_of_its_ends() -> void:
	assert_almost_eq(ElevationField.relief_amplitude_for(0.0),
			ElevationField.RELIEF_AMPLITUDE_VOXELS * ElevationField.RELIEF_OCEAN_SCALE,
			1e-9)
	assert_almost_eq(ElevationField.relief_amplitude_for(1.0),
			ElevationField.RELIEF_AMPLITUDE_VOXELS, 1e-9)


func test_the_deep_ocean_is_calmer_than_the_interior() -> void:
	# `RELIEF_OCEAN_SCALE` only means something if it is observable in the terrain rather
	# than only in the constant. Find the most seaward and the most landward column in the
	# sweep, then walk a kilometre through each and compare how much the ground climbs.
	var field := _field_for(GenerationFixtures.WORLD_TYPED)
	var seaward := Vector2i.ZERO
	var landward := Vector2i.ZERO
	var lowest := 2.0
	var highest := -1.0
	for ix in SWEEP_SIDE:
		for iz in SWEEP_SIDE:
			var column := Vector2i(SWEEP_ORIGIN + ix * SWEEP_SPACING,
					SWEEP_ORIGIN + iz * SWEEP_SPACING)
			var shore := field.shore_at(column)
			if shore < lowest:
				lowest = shore
				seaward = column
			if shore > highest:
				highest = shore
				landward = column
	assert_almost_eq(lowest, 0.0, 1e-9, "the sweep found a fully seaward column")
	assert_almost_eq(highest, 1.0, 1e-9, "the sweep found a fully landward column")
	assert_true(_climb_along(field, seaward) < _climb_along(field, landward),
			"the sea floor at %s climbs less than the interior at %s" % [
					seaward, landward])


## Total absolute change in ground height over a kilometre east from `start`.
func _climb_along(field: ElevationField, start: Vector2i) -> float:
	var travelled := 0.0
	var previous := field.at(start)
	for step in range(1, 2001):
		var current := field.at(start + Vector2i(step, 0))
		travelled += absf(current - previous)
		previous = current
	return travelled
