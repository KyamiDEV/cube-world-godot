extends TestCase
## `world/generation/temperature_field.gd` — how warm a column is (brick 064).
##
## The noise underneath is already covered (`test_value_noise.gd`), so this file is about
## what 064 adds: the scale that makes climate the coarsest thing in the world, the
## redistribution curve that lets the field reach its own ends, and the two claims the
## brick exists to make — that climate is a **separate axis** from the height field, and
## that it is something a player walks into over kilometres rather than something that
## changes under their feet.

## The digest of `at()` over `GenerationFixtures.columns()` for the `typed` world.
const PINNED_SIGNATURE := "fb91406f3e801b7f"

## The distribution sweep. Same shape and spacing as `test_elevation_field.gd`'s and
## `test_erosion_pass.gd`'s, so the three files' measurements are comparable column for
## column — which is what makes the height/temperature correlation below meaningful.
const SWEEP_SIDE := 48
const SWEEP_SPACING := 4093
const SWEEP_ORIGIN := -98232

## The long east–west line the walking tests use. Long enough to cross several climate
## cells (a cell is 16384 voxels), sampled every `LINE_STEP` voxels.
const LINE_Z := 613
const LINE_ORIGIN := -200000
const LINE_STEP := 50
const LINE_SAMPLES := 8001

## Voxels in a kilometre, at `1 voxel = 0.5 m`, and the same distance counted in line
## samples. Both written out rather than divided: `LINE_STEP` has to divide the kilometre
## exactly for the sliding window below to mean what it says, and the assertion that it
## does is `KILOMETRE_SAMPLES * LINE_STEP == KILOMETRE_VOXELS` in
## `test_the_line_geometry_is_what_it_claims`.
const KILOMETRE_VOXELS := 2000
const KILOMETRE_SAMPLES := 40


func _field_for(name: String) -> TemperatureField:
	return TemperatureField.for_world(GenerationFixtures.hash_for(name))


func _sampler_factory() -> Callable:
	return func(hash: GenerationHash) -> Callable:
		var climate := TemperatureField.for_world(hash)
		return func(column: Vector2i) -> float: return climate.at(column)


func _sweep_columns() -> Array[Vector2i]:
	var columns: Array[Vector2i] = []
	for ix in SWEEP_SIDE:
		for iz in SWEEP_SIDE:
			columns.append(Vector2i(SWEEP_ORIGIN + ix * SWEEP_SPACING,
					SWEEP_ORIGIN + iz * SWEEP_SPACING))
	return columns


## Pearson correlation of two equal-length sample arrays. Returns 0 when either is
## constant, which is the answer a constant field deserves here.
func _correlation(left: Array[float], right: Array[float]) -> float:
	var count := float(left.size())
	var mean_left := 0.0
	var mean_right := 0.0
	for value in left:
		mean_left += value
	for value in right:
		mean_right += value
	mean_left /= count
	mean_right /= count
	var covariance := 0.0
	var variance_left := 0.0
	var variance_right := 0.0
	for index in left.size():
		var dl := left[index] - mean_left
		var dr := right[index] - mean_right
		covariance += dl * dr
		variance_left += dl * dl
		variance_right += dr * dr
	if variance_left <= 0.0 or variance_right <= 0.0:
		return 0.0
	return covariance / sqrt(variance_left * variance_right)


## How the samples fall across the ten tenths of `[0, 1]`, as fractions summing to 1.
func _deciles(values: Array[float]) -> PackedFloat64Array:
	var counts := PackedFloat64Array()
	counts.resize(10)
	for value in values:
		counts[clampi(int(value * 10.0), 0, 9)] += 1.0
	for index in counts.size():
		counts[index] /= float(values.size())
	return counts


func _standard_deviation(values: Array[float]) -> float:
	var mean := 0.0
	for value in values:
		mean += value
	mean /= float(values.size())
	var variance := 0.0
	for value in values:
		variance += (value - mean) * (value - mean)
	return sqrt(variance / float(values.size()))


# ---------------------------------------------------------------------------
# Binding
# ---------------------------------------------------------------------------

func test_requires_a_world_binding() -> void:
	assert_null(TemperatureField.for_world(null))


func test_binds_to_every_fixture_world() -> void:
	for name in GenerationFixtures.world_names():
		assert_not_null(_field_for(name), "world '%s' has a temperature field" % name)


func test_the_pinned_parameters_are_the_documented_ones() -> void:
	var climate := _field_for(GenerationFixtures.WORLD_TYPED)
	var layer := climate.noise()
	assert_eq(layer.cell_size(), TemperatureField.CELL_SIZE_VOXELS)
	assert_eq(layer.cell_size(), 16384)
	assert_eq(layer.octaves(), TemperatureField.OCTAVES)
	assert_almost_eq(layer.gain(), TemperatureField.GAIN)
	assert_eq(layer.salt(), WorldHash.SALT_TEMPERATURE)
	assert_almost_eq(TemperatureField.cell_size_metres(), 8192.0)
	assert_almost_eq(TemperatureField.finest_cell_metres(), 4096.0)


func test_the_temperature_salt_is_nobody_elses() -> void:
	# Two fields sharing a salt are one field. Climate would then be a relabelling of the
	# terrain it is supposed to be independent of, which is exactly what
	# `test_climate_is_a_separate_axis_from_the_ground` measures the consequence of.
	assert_ne(WorldHash.SALT_TEMPERATURE, WorldHash.SALT_CONTINENTALNESS)
	assert_ne(WorldHash.SALT_TEMPERATURE, WorldHash.SALT_ELEVATION)
	assert_ne(WorldHash.SALT_TEMPERATURE, WorldHash.SALT_RUGGEDNESS)
	assert_ne(WorldHash.SALT_TEMPERATURE, WorldHash.SALT_HUMIDITY)


func test_climate_is_the_coarsest_field_in_the_world() -> void:
	# The scale decision, stated as the inequality rather than as the octave count: every
	# scale climate carries is at or above the coarsest scale of every field under it, so
	# a biome is larger than the continent-scale features inside it.
	var climate := _field_for(GenerationFixtures.WORLD_TYPED)
	var finest := climate.noise().finest_cell_size()
	assert_true(climate.noise().cell_size() > Continentalness.CELL_SIZE_VOXELS,
			"the climate cell (%d) is coarser than the continent cell (%d)" % [
					climate.noise().cell_size(), Continentalness.CELL_SIZE_VOXELS])
	assert_eq(finest, Continentalness.CELL_SIZE_VOXELS)
	assert_eq(finest, ErosionPass.RUGGEDNESS_CELL_SIZE_VOXELS)
	assert_true(finest > ElevationField.RELIEF_CELL_SIZE_VOXELS,
			"the finest climate cell (%d) is coarser than the coarsest relief cell (%d)"
					% [finest, ElevationField.RELIEF_CELL_SIZE_VOXELS])


# ---------------------------------------------------------------------------
# The redistribution curve
# ---------------------------------------------------------------------------

func test_the_spread_curve_fixes_both_ends_and_the_middle() -> void:
	# Fixed points at 0, 0.5 and 1 are what let the stated range survive the curve and
	# what keep it from biasing the world warm or cold.
	assert_almost_eq(TemperatureField.spread(0.0), 0.0, 1e-12)
	assert_almost_eq(TemperatureField.spread(0.5), 0.5, 1e-12)
	assert_almost_eq(TemperatureField.spread(1.0), 1.0, 1e-12)


func test_the_spread_curve_pushes_values_away_from_the_middle() -> void:
	# The property that makes it a redistribution rather than a rescale: below the middle
	# it answers lower, above the middle higher, and it never goes back down. A curve that
	# did the opposite would concentrate an already-clustered field further.
	var previous := -1.0
	for step in 201:
		var raw := float(step) / 200.0
		var spread := TemperatureField.spread(raw)
		assert_in_range(spread, 0.0, 1.0, "step %d stays in [0, 1]" % step)
		assert_true(spread >= previous, "the curve never goes back down at step %d" % step)
		if step > 0 and step < 100:
			assert_true(spread < raw, "%s is pushed down to %s" % [raw, spread])
		if step > 100 and step < 200:
			assert_true(spread > raw, "%s is pushed up to %s" % [raw, spread])
		previous = spread


func test_the_field_is_its_layer_through_the_curve() -> void:
	# `raw_at()` is what brick 065 and a debug probe will read; it has to be the value
	# `at()` actually starts from, not a second sample that drifts from it.
	var climate := _field_for(GenerationFixtures.WORLD_TYPED)
	for column in GenerationFixtures.columns():
		assert_almost_eq(climate.at(column),
				TemperatureField.spread(climate.raw_at(column)), 1e-12,
				"column %s is its raw value through the curve" % column)
		assert_in_range(climate.raw_at(column), 0.0, 1.0,
				"column %s's raw value is in [0, 1]" % column)


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
		var climate := _field_for(name)
		var sampler := func(column: Vector2i) -> float: return climate.at(column)
		assert_eq(GenerationFixtures.range_reason(sampler, GenerationFixtures.columns(),
				TemperatureField.MINIMUM, TemperatureField.MAXIMUM), "",
				"world '%s' stays in range" % name)


func test_varies_across_the_sample_columns() -> void:
	var climate := _field_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> float: return climate.at(column)
	assert_eq(GenerationFixtures.variation_reason(sampler, GenerationFixtures.columns(),
			8), "")


func test_signature_is_pinned() -> void:
	var climate := _field_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> float: return climate.at(column)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.columns()),
			PINNED_SIGNATURE)


func test_a_voxel_reads_its_own_column() -> void:
	var climate := _field_for(GenerationFixtures.WORLD_TYPED)
	for voxel in GenerationFixtures.voxels():
		assert_eq(climate.at_voxel(voxel),
				climate.at(GenerationGrid.voxel_to_column(voxel)),
				"voxel %s reads its column" % voxel)


# ---------------------------------------------------------------------------
# What the field is for
# ---------------------------------------------------------------------------

func test_the_world_has_climates_at_both_ends_of_the_range() -> void:
	# The claim of the brick. A classifier can only find a desert or a snowfield if
	# columns near the ends of this field exist, and the sweep is where we find out.
	var climate := _field_for(GenerationFixtures.WORLD_TYPED)
	var values: Array[float] = []
	for column in _sweep_columns():
		values.append(climate.at(column))
	var lowest := 2.0
	var highest := -1.0
	for value in values:
		lowest = minf(lowest, value)
		highest = maxf(highest, value)
	assert_true(lowest < 0.02, "the sweep finds a coldest place (%s)" % lowest)
	assert_true(highest > 0.98, "the sweep finds a hottest place (%s)" % highest)


func test_no_tenth_of_the_climate_range_is_empty() -> void:
	# Stronger than reaching the ends, and the property biome thresholds actually depend
	# on: wherever brick 066 puts a boundary, a useful share of the world has to fall on
	# each side of it. A uniform field would put 10% in every decile; nothing here is
	# allowed to fall below half of that or to take more than a sixth of the world.
	var climate := _field_for(GenerationFixtures.WORLD_TYPED)
	var values: Array[float] = []
	for column in _sweep_columns():
		values.append(climate.at(column))
	var deciles := _deciles(values)
	for index in deciles.size():
		assert_in_range(deciles[index], 0.05, 0.16,
				"decile %d holds a workable share of the world (%.4f)" % [
						index, deciles[index]])
	# `1 / sqrt(12)` = 0.2887 is a uniform field's standard deviation.
	assert_true(_standard_deviation(values) > 0.26,
			"the field is close to uniform (sd %s)" % _standard_deviation(values))


func test_the_curve_is_what_earns_that_distribution() -> void:
	# The same sweep before `spread()`. The raw layer reaches neither end and piles two
	# thirds of the world into the middle four deciles — a field brick 066 could not put a
	# desert threshold on. This is the measurement the curve exists because of, and it is
	# here so that removing the curve fails a test rather than quietly flattening the map.
	var climate := _field_for(GenerationFixtures.WORLD_TYPED)
	var raw: Array[float] = []
	for column in _sweep_columns():
		raw.append(climate.raw_at(column))
	var lowest := 2.0
	var highest := -1.0
	for value in raw:
		lowest = minf(lowest, value)
		highest = maxf(highest, value)
	assert_true(lowest > 0.005 and highest < 0.995,
			"the raw layer reaches neither end (%s .. %s)" % [lowest, highest])
	var deciles := _deciles(raw)
	var middle := deciles[3] + deciles[4] + deciles[5] + deciles[6]
	assert_true(middle > 0.6,
			"the raw layer crowds its middle (%.4f of the world in four deciles)" % middle)
	assert_true(_standard_deviation(raw) < 0.2,
			"the raw layer is narrower than the field (sd %s)" % _standard_deviation(raw))


func test_climate_is_a_separate_axis_from_the_ground() -> void:
	# The finding brick 064 owes `terrain-base-height-field.md` U2, as a measurement:
	# temperature shares nothing with the height field or with continentalness. If a
	# future edit gave climate one of their salts or derived it from a height, this is
	# where it would show up — as a correlation, before it showed up as every mountain
	# being cold.
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var climate := TemperatureField.for_world(hash)
	var ground := ErosionPass.for_world(hash)
	var macro := Continentalness.for_world(hash)
	var temperatures: Array[float] = []
	var heights: Array[float] = []
	var continents: Array[float] = []
	for column in _sweep_columns():
		temperatures.append(climate.at(column))
		heights.append(ground.at(column))
		continents.append(macro.at(column))
	var with_height := _correlation(temperatures, heights)
	var with_continent := _correlation(temperatures, continents)
	assert_true(absf(with_height) < 0.05,
			"temperature is uncorrelated with ground height (r = %s)" % with_height)
	assert_true(absf(with_continent) < 0.05,
			"temperature is uncorrelated with continentalness (r = %s)" % with_continent)


func test_the_line_geometry_is_what_it_claims() -> void:
	# The two walking tests below read a sampled line, not every voxel of it. That is only
	# honest if the sampling step divides the kilometre exactly and the line is long
	# enough to contain several climate cells.
	assert_eq(KILOMETRE_SAMPLES * LINE_STEP, KILOMETRE_VOXELS)
	assert_almost_eq(WorldScale.voxels_to_metres(float(KILOMETRE_VOXELS)), 1000.0)
	var span := (LINE_SAMPLES - 1) * LINE_STEP
	assert_true(span > 8 * TemperatureField.CELL_SIZE_VOXELS,
			"the line (%d voxels) crosses several climate cells (%d voxels each)" % [
					span, TemperatureField.CELL_SIZE_VOXELS])


func test_a_kilometre_of_walking_never_changes_the_weather_much() -> void:
	# The other half of the brick's claim, and the one the scale constants exist for.
	# Every kilometre of the long line is checked, not one hand-picked one: the worst of
	# them has to stay inside the derived bound, and it also has to stay well short of the
	# whole range, or a climate is a texture rather than a place.
	var climate := _field_for(GenerationFixtures.WORLD_TYPED)
	var line: Array[float] = []
	for index in LINE_SAMPLES:
		line.append(climate.at(Vector2i(LINE_ORIGIN + index * LINE_STEP, LINE_Z)))
	var window := KILOMETRE_SAMPLES
	var bound := climate.max_step_per_voxel() * float(KILOMETRE_VOXELS)
	var worst := 0.0
	for start in range(0, line.size() - window):
		var lowest := 2.0
		var highest := -1.0
		for index in range(start, start + window + 1):
			lowest = minf(lowest, line[index])
			highest = maxf(highest, line[index])
		worst = maxf(worst, highest - lowest)
	assert_true(worst <= bound + 1e-12,
			"the worst kilometre (%s) is within the derived bound (%s)" % [worst, bound])
	assert_true(worst < 0.5,
			"no kilometre crosses half the climate range (worst %s)" % worst)
	# ... and the line is not flat: somewhere along it the climate really does change.
	assert_true(worst > 0.2,
			"some kilometre carries a real climate gradient (worst %s)" % worst)


func test_the_long_line_crosses_the_whole_climate_range() -> void:
	# The complement of the test above: gentle everywhere, and still a world with both
	# ends in it. A player walking east long enough leaves one climate and arrives in
	# another, which is the thing 400 km of line is here to prove.
	var climate := _field_for(GenerationFixtures.WORLD_TYPED)
	var lowest := 2.0
	var highest := -1.0
	for index in LINE_SAMPLES:
		var value := climate.at(Vector2i(LINE_ORIGIN + index * LINE_STEP, LINE_Z))
		lowest = minf(lowest, value)
		highest = maxf(highest, value)
	assert_true(lowest < 0.05, "the line reaches cold ground (%s)" % lowest)
	assert_true(highest > 0.95, "the line reaches hot ground (%s)" % highest)


func test_a_climate_crossing_is_at_least_a_kilometre_of_walking() -> void:
	# `minimum_climate_span_voxels()` is derived from the constants alone, so it is what a
	# later edit to `CELL_SIZE_VOXELS` or `OCTAVES` would move. Pinning the consequence
	# rather than the constant: however the layer is retuned, crossing from the coldest to
	# the hottest value must stay a journey.
	var climate := _field_for(GenerationFixtures.WORLD_TYPED)
	assert_almost_eq(climate.minimum_climate_span_voxels(),
			1.0 / climate.max_step_per_voxel(), 1e-9)
	assert_true(climate.minimum_climate_span_voxels() > float(KILOMETRE_VOXELS),
			"a full climate crossing is at least a kilometre (%s voxels)"
					% climate.minimum_climate_span_voxels())


func test_the_step_bound_is_a_real_constraint() -> void:
	# The bound is only worth asserting if it can fail. Raw positional hashing at this
	# salt is the climate map this field exists not to produce: a different biome in every
	# column.
	var climate := _field_for(GenerationFixtures.WORLD_TYPED)
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var bound := climate.max_step_per_voxel()
	var violations := 0
	var previous := hash.value01_column(Vector2i(-100, LINE_Z), WorldHash.SALT_TEMPERATURE)
	for x in range(-99, 101):
		var current := hash.value01_column(Vector2i(x, LINE_Z), WorldHash.SALT_TEMPERATURE)
		if absf(current - previous) > bound:
			violations += 1
		previous = current
	assert_true(violations > 100,
			"white noise breaks the bound almost everywhere (%d of 200)" % violations)
