extends TestCase
## `world/generation/terrace_pass.gd` — the block world (brick 063).
##
## Everything underneath is already covered (`test_value_noise.gd`,
## `test_continentalness.gd`, `test_elevation_field.gd`, `test_erosion_pass.gd`), so this
## file is about what 063 adds: that every height is an exact terrace plane, that the pass
## still only lowers ground, that a single step never crosses more than one riser — and the
## claim the brick exists to make, that the world now reads as flat shelves rather than as
## a smooth curve stored in voxels.

## The digest of `at()` over `GenerationFixtures.columns()` for the `typed` world.
const PINNED_SIGNATURE := "2af464f70e43590a"

## The distribution sweep. Same shape and spacing as `test_elevation_field.gd`'s and
## `test_erosion_pass.gd`'s, so all three files' measurements are comparable column for
## column.
const SWEEP_SIDE := 48
const SWEEP_SPACING := 4093
const SWEEP_ORIGIN := -98232


func _pass_for(name: String) -> TerracePass:
	return TerracePass.for_world(GenerationFixtures.hash_for(name))


func _sampler_factory() -> Callable:
	return func(hash: GenerationHash) -> Callable:
		var ground := TerracePass.for_world(hash)
		return func(column: Vector2i) -> float: return ground.at(column)


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
	assert_null(TerracePass.for_world(null))


func test_binds_to_every_fixture_world() -> void:
	for name in GenerationFixtures.world_names():
		assert_not_null(_pass_for(name), "world '%s' has a terrace pass" % name)


func test_the_terrace_height_is_the_one_brick_061_sized_its_octaves_for() -> void:
	# 061 chose `RELIEF_OCTAVES` so its finest relief cell is *four times* the terrace
	# height (`docs/world-generation.md` §6.4). Coarsen the terrace and that octave is
	# rounded away; this is the assertion that keeps the two constants tied together.
	var finest_relief := (ElevationField.RELIEF_CELL_SIZE_VOXELS
			>> (ElevationField.RELIEF_OCTAVES - 1))
	assert_eq(finest_relief, 4 * TerracePass.TERRACE_HEIGHT_VOXELS,
			"the finest relief cell (%d) is four terraces" % finest_relief)
	assert_almost_eq(TerracePass.terrace_height_metres(), 4.0)


func test_the_terrace_height_is_a_power_of_two() -> void:
	# Not a style preference: `h / H` is then an exact exponent shift for every finite
	# double, so the quantisation is bit-identical on every platform that generates this
	# world (`docs/world-generation.md` §5.3's argument, applied to a division).
	var height := TerracePass.TERRACE_HEIGHT_VOXELS
	assert_true(height > 0, "the terrace has a positive height")
	assert_eq(height & (height - 1), 0, "%d is a power of two" % height)


func test_the_range_is_the_pass_it_quantises() -> void:
	assert_almost_eq(TerracePass.MINIMUM_VOXELS, ErosionPass.MINIMUM_VOXELS)
	assert_almost_eq(TerracePass.MAXIMUM_VOXELS, ErosionPass.MAXIMUM_VOXELS)


func test_both_ends_of_the_range_are_terrace_planes() -> void:
	# `floor` is monotone, so quantising maps the range into itself *only* if both ends are
	# already terrace planes. They are a property of 061's vertical anchors, not of this
	# file, so a later change to `OCEAN_FLOOR_VOXELS` or `LAND_BASE_VOXELS` has to fail
	# here rather than silently push the world one terrace out of its own stated range.
	assert_almost_eq(TerracePass.terraced(TerracePass.MINIMUM_VOXELS),
			TerracePass.MINIMUM_VOXELS, 1e-12)
	assert_almost_eq(TerracePass.terraced(TerracePass.MAXIMUM_VOXELS),
			TerracePass.MAXIMUM_VOXELS, 1e-12)


# ---------------------------------------------------------------------------
# The curve
# ---------------------------------------------------------------------------

func test_the_curve_snaps_down_to_the_plane_below() -> void:
	var height := float(TerracePass.TERRACE_HEIGHT_VOXELS)
	assert_almost_eq(TerracePass.terraced(0.0), 0.0, 1e-12)
	assert_almost_eq(TerracePass.terraced(height - 0.001), 0.0, 1e-12)
	assert_almost_eq(TerracePass.terraced(height), height, 1e-12)
	# Downward on the negative side too: truncation toward zero would make voxel −1 and
	# voxel 0 share a terrace and mirror the staircase about the datum — the same defect
	# `GenerationGrid.floor_div()` exists to avoid one level down (§3.5).
	assert_almost_eq(TerracePass.terraced(-0.001), -height, 1e-12)
	assert_almost_eq(TerracePass.terraced(-height), -height, 1e-12)
	assert_almost_eq(TerracePass.terraced(-height - 0.001), -2.0 * height, 1e-12)


func test_the_curve_never_raises_and_never_removes_a_whole_terrace() -> void:
	var height := float(TerracePass.TERRACE_HEIGHT_VOXELS)
	for step in 1601:
		var value := TerracePass.MINIMUM_VOXELS + float(step) * 0.18
		var snapped := TerracePass.terraced(value)
		assert_true(snapped <= value + 1e-12, "%s is not raised to %s" % [value, snapped])
		assert_true(value - snapped < height,
				"%s loses less than a whole terrace (%s)" % [value, value - snapped])


func test_the_curve_is_monotone() -> void:
	# Monotonicity is what carries the family invariant across the quantisation: it is the
	# reason `terraced(base) <= terraced(erosion.at())` follows from `base <= erosion.at()`.
	var previous := -1e30
	for step in 1601:
		var snapped := TerracePass.terraced(TerracePass.MINIMUM_VOXELS + float(step) * 0.18)
		assert_true(snapped >= previous, "the curve never goes back down at step %d" % step)
		previous = snapped


func test_the_terrace_index_counts_from_the_datum() -> void:
	var height := float(TerracePass.TERRACE_HEIGHT_VOXELS)
	assert_eq(TerracePass.terrace_index(0.0), 0)
	assert_eq(TerracePass.terrace_index(height - 0.001), 0)
	assert_eq(TerracePass.terrace_index(height), 1)
	assert_eq(TerracePass.terrace_index(-0.001), -1)
	assert_eq(TerracePass.terrace_index(-height), -1)
	assert_eq(TerracePass.terrace_index(-height - 0.001), -2)


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
		var ground := _pass_for(name)
		var sampler := func(column: Vector2i) -> float: return ground.at(column)
		assert_eq(GenerationFixtures.range_reason(sampler, GenerationFixtures.columns(),
				TerracePass.MINIMUM_VOXELS, TerracePass.MAXIMUM_VOXELS), "",
				"world '%s' stays in range" % name)


func test_varies_across_the_sample_columns() -> void:
	# **This threshold is 2 where every other Phase D pass uses 8, and that is the pass
	# working rather than a weakened check.** `GenerationFixtures.columns()` is a list of
	# *nearby* coordinates — the origin, its neighbours, cell boundaries, the two region
	# corners — chosen to catch sign and boundary defects, not to sample the world. 062
	# answers 15 distinct continuous heights there, but they span barely 12 voxels, so
	# quantising them lands on exactly two shelves (`+64` and `+56`). Demanding 8 here would
	# demand the terrace be finer than the ground it is measuring.
	#
	# The real variation check for this pass is over the 2304-column sweep, where it has to
	# find a populated span of terraces:
	# `test_the_sweep_uses_a_real_spread_of_terraces`.
	var ground := _pass_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> float: return ground.at(column)
	assert_eq(GenerationFixtures.variation_reason(sampler, GenerationFixtures.columns(),
			2), "")


func test_signature_is_pinned() -> void:
	var ground := _pass_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> float: return ground.at(column)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.columns()),
			PINNED_SIGNATURE)


# ---------------------------------------------------------------------------
# The block world
# ---------------------------------------------------------------------------

func test_every_height_is_an_exact_terrace_plane() -> void:
	# The whole claim of the brick, and the reason `surface_y()` can be an exact int cast
	# rather than a rounding. Checked on the fixture columns — which include the negative
	# axes and the `WorldBounds` corners — and on the whole distribution sweep.
	var height := float(TerracePass.TERRACE_HEIGHT_VOXELS)
	for name in GenerationFixtures.world_names():
		var ground := _pass_for(name)
		var columns: Array[Vector2i] = []
		columns.assign(GenerationFixtures.columns())
		columns.append_array(_sweep_columns())
		for column in columns:
			var value := ground.at(column)
			assert_almost_eq(value, floorf(value / height) * height, 1e-12,
					"world '%s' column %s is a terrace plane" % [name, column])
			assert_eq(float(ground.surface_y(column)), value,
					"world '%s' column %s casts to its own voxel plane" % [name, column])


func test_the_pass_lowers_the_ground_and_never_raises_it() -> void:
	# `terraced(base) <= at <= erosion.at()`. The upper half is 062's invariant carried
	# forward; the lower half is the terraced form of it, and the honest one — the
	# *unterraced* base is no longer a floor, because a column sitting just above its base
	# is pulled down past it by less than one terrace.
	var height := float(TerracePass.TERRACE_HEIGHT_VOXELS)
	for name in GenerationFixtures.world_names():
		var ground := _pass_for(name)
		var columns: Array[Vector2i] = []
		columns.assign(GenerationFixtures.columns())
		columns.append_array(_sweep_columns())
		for column in columns:
			var value := ground.at(column)
			var continuous := ground.continuous_at(column)
			assert_true(value <= continuous + 1e-12,
					"world '%s' column %s is not raised" % [name, column])
			assert_true(value > continuous - height - 1e-12,
					"world '%s' column %s loses under a terrace" % [name, column])
			assert_true(value >= ground.terraced_base_at(column) - 1e-12,
					"world '%s' column %s stays on or above its terraced base"
							% [name, column])


func test_the_terms_decompose_the_whole() -> void:
	# `continuous_at()`, `removed_at()`, `fraction_at()` and `terrace_index_at()` are what
	# bricks 075, 084 and 085 will read; they have to be the terms `at()` actually produced,
	# not a second quantisation that drifts from it.
	var height := float(TerracePass.TERRACE_HEIGHT_VOXELS)
	var ground := _pass_for(GenerationFixtures.WORLD_TYPED)
	for column in GenerationFixtures.columns():
		var value := ground.at(column)
		assert_almost_eq(ground.continuous_at(column), ground.erosion().at(column), 1e-12,
				"column %s's continuous height is 062's" % column)
		assert_almost_eq(value + ground.removed_at(column), ground.continuous_at(column),
				1e-9, "column %s's removal accounts for the difference" % column)
		assert_in_range(ground.fraction_at(column), 0.0, 1.0 - 1e-12,
				"column %s sits inside its own terrace" % column)
		assert_almost_eq(float(ground.terrace_index_at(column)) * height, value, 1e-12,
				"column %s's terrace index is its own plane" % column)


func test_a_voxel_reads_its_own_column() -> void:
	var ground := _pass_for(GenerationFixtures.WORLD_TYPED)
	for voxel in GenerationFixtures.voxels():
		assert_eq(ground.at_voxel(voxel),
				ground.at(GenerationGrid.voxel_to_column(voxel)),
				"voxel %s reads its column" % voxel)


func test_at_metres_is_the_voxel_height_converted() -> void:
	var ground := _pass_for(GenerationFixtures.WORLD_TYPED)
	for column in GenerationFixtures.columns():
		assert_almost_eq(ground.at_metres(column),
				WorldScale.voxels_to_metres(ground.at(column)), 1e-9)


# ---------------------------------------------------------------------------
# What replaces the step bound
# ---------------------------------------------------------------------------

func test_the_ground_is_never_steep_enough_to_skip_a_terrace() -> void:
	# The sizing property the whole pass rests on: 062's continuous step bound is below one
	# terrace, so `floor` can never move two planes at once and every riser in the world is
	# a single face. Derived from the constants, asserted before any column is sampled.
	var ground := _pass_for(GenerationFixtures.WORLD_TYPED)
	var height := float(TerracePass.TERRACE_HEIGHT_VOXELS)
	assert_true(ground.erosion().max_step_per_voxel() < height,
			"062's step bound (%s) is under one terrace (%s)" % [
					ground.erosion().max_step_per_voxel(), height])
	assert_almost_eq(ground.max_riser_voxels(), height, 1e-12)


func test_a_kilometre_of_walking_is_a_staircase() -> void:
	# 2000 voxels is a kilometre at 0.5 m per voxel. Three claims at once: every step is an
	# exact whole number of terraces (never a slope), no step is taller than one riser, and
	# the ground still goes somewhere — a terraced world that never changes shelf is a
	# floor, not terrain.
	var ground := _pass_for(GenerationFixtures.WORLD_TYPED)
	var height := float(TerracePass.TERRACE_HEIGHT_VOXELS)
	var bound := ground.max_riser_voxels()
	var risers := 0
	var largest := 0.0
	var previous := ground.at(Vector2i(-1000, 613))
	for x in range(-999, 1001):
		var current := ground.at(Vector2i(x, 613))
		var step := absf(current - previous)
		if step > 1e-12:
			risers += 1
			assert_almost_eq(step, roundf(step / height) * height, 1e-12,
					"the step at x=%d is a whole number of terraces (%s)" % [x, step])
		largest = maxf(largest, step)
		previous = current
	assert_true(largest <= bound + 1e-12,
			"largest riser %s is within the bound %s" % [largest, bound])
	assert_true(risers > 0, "the kilometre crosses at least one riser")


func test_the_riser_bound_is_a_real_constraint() -> void:
	# The bound is only worth asserting if it can fail. Quantising raw positional hashing
	# over the same amplitude — the terrain 062 exists not to produce — skips terraces
	# almost everywhere, which is exactly what `max_riser_voxels()` claims cannot happen to
	# the real field.
	var ground := _pass_for(GenerationFixtures.WORLD_TYPED)
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var bound := ground.max_riser_voxels()
	var span := TerracePass.MAXIMUM_VOXELS - TerracePass.MINIMUM_VOXELS
	var violations := 0
	var previous := TerracePass.terraced(TerracePass.MINIMUM_VOXELS
			+ span * hash.value01_column(Vector2i(-100, 613), WorldHash.SALT_ELEVATION))
	for x in range(-99, 101):
		var current := TerracePass.terraced(TerracePass.MINIMUM_VOXELS
				+ span * hash.value01_column(Vector2i(x, 613), WorldHash.SALT_ELEVATION))
		if absf(current - previous) > bound:
			violations += 1
		previous = current
	assert_true(violations > 100,
			"white noise skips terraces almost everywhere (%d of 200)" % violations)


# ---------------------------------------------------------------------------
# What the pass is for
# ---------------------------------------------------------------------------

func test_the_world_is_made_of_shelves_rather_than_slopes() -> void:
	# The claim of the brick. Walk a kilometre and count how much of it is flat: before
	# 063 essentially every neighbouring pair of columns differed, after it the large
	# majority have to be at exactly the same height, or "terrace" is only a comment.
	var ground := _pass_for(GenerationFixtures.WORLD_TYPED)
	var shaped := ground.erosion()
	var flat := 0
	var continuous_flat := 0
	var previous := ground.at(Vector2i(-1000, 613))
	var previous_continuous := shaped.at(Vector2i(-1000, 613))
	for x in range(-999, 1001):
		var current := ground.at(Vector2i(x, 613))
		var current_continuous := shaped.at(Vector2i(x, 613))
		if absf(current - previous) <= 1e-12:
			flat += 1
		if absf(current_continuous - previous_continuous) <= 1e-12:
			continuous_flat += 1
		previous = current
		previous_continuous = current_continuous
	assert_true(flat > 1900,
			"the kilometre is mostly flat shelf (%d of 2000 steps)" % flat)
	assert_true(continuous_flat * 2 < flat,
			"the ground it was made from was not (%d of 2000 steps)" % continuous_flat)


func test_the_terraced_world_still_spans_sea_floor_and_high_ground() -> void:
	# 061's and 062's distribution check, re-run after the quantisation. Snapping the world
	# down is only correct if the extremes survive it: they may each move down by up to one
	# terrace, and no further.
	var ground := _pass_for(GenerationFixtures.WORLD_TYPED)
	var height := float(TerracePass.TERRACE_HEIGHT_VOXELS)
	var lowest := TerracePass.MAXIMUM_VOXELS
	var highest := TerracePass.MINIMUM_VOXELS
	for column in _sweep_columns():
		var value := ground.at(column)
		lowest = minf(lowest, value)
		highest = maxf(highest, value)
	assert_true(lowest < ElevationField.OCEAN_FLOOR_VOXELS + 24.0,
			"the sweep still reaches an ocean basin (lowest %s)" % lowest)
	assert_true(highest > ElevationField.LAND_BASE_VOXELS + 48.0 - height,
			"the sweep still reaches high ground (highest %s)" % highest)


func test_the_sweep_uses_a_real_spread_of_terraces() -> void:
	# A world that used three shelves would satisfy every invariant above. Count the
	# distinct terrace indices the sweep lands on, and check the whole span between the
	# lowest and the highest is populated rather than clustered at one end.
	var ground := _pass_for(GenerationFixtures.WORLD_TYPED)
	var seen := {}
	var lowest := 1 << 30
	var highest := -(1 << 30)
	for column in _sweep_columns():
		var index := ground.terrace_index_at(column)
		seen[index] = true
		lowest = mini(lowest, index)
		highest = maxi(highest, index)
	assert_true(seen.size() >= 16,
			"the sweep lands on many distinct terraces (%d)" % seen.size())
	assert_true(seen.size() * 2 > highest - lowest,
			"the terraces it uses are not clustered at one end (%d of %d)" % [
					seen.size(), highest - lowest + 1])
