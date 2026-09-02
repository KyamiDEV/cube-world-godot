extends TestCase
## `world/generation/humidity_field.gd` — how wet a column is (brick 065).
##
## The noise underneath is already covered (`test_value_noise.gd`) and the climate *shape*
## by `test_temperature_field.gd`, so this file is about what 065 adds: that the second
## axis really does carry the same distribution as the first rather than being assumed to,
## that it is **independent** of the first, and that the two of them together cover the
## climate square brick 066 will classify on.
##
## One thing here is not a copy of 064's file, and it is the brick's finding: the sweep.
## 064 measured its distribution on the 2304-column sweep `test_elevation_field.gd` and
## `test_erosion_pass.gd` use, at a spacing of 4093 voxels — a quarter of one climate cell.
## That sweep resolves a relief field beautifully and a climate field not at all: its 2304
## columns are only about 144 independent climate cells, so its decile histogram and its
## correlations are small-sample estimates that move by more than the thing they measure
## when the seed changes (`docs/world-generation.md` §10.4). Everything distributional here
## runs on a **climate-scale sweep** instead — spacing above one cell edge, spanning very
## nearly the whole world — and on all four fixture worlds rather than one.

## The digest of `at()` over `GenerationFixtures.columns()` for the `typed` world.
const PINNED_SIGNATURE := "76802ec9aa907fee"

## The climate-scale sweep: 4096 columns at a spacing wider than one climate cell, spanning
## 1032003 of the world's 1048576 voxels on each axis and staying inside `WorldBounds` at
## both ends. 16381 is prime and just under the 16384-voxel cell, so consecutive samples
## walk the phase of the lattice instead of landing on the same corner of every cell.
const SWEEP_SIDE := 64
const SWEEP_SPACING := 16381
const SWEEP_ORIGIN := -524192

## The long east–west line the walking tests use: 800 km, centred on the origin and inside
## `WorldBounds` at both ends, sampled every `LINE_STEP` voxels.
##
## Twice 064's line, and that is a measurement rather than a preference: at 400 km this
## field's line on the `typed` world spans `0.088 .. 0.994`, so it never reaches its dry
## end. A climate field is not obliged to cross its whole range in any particular 400 km,
## and shortening the claim to fit the line — or hunting for a latitude where 400 km
## happens to work — would be tuning the test to the seed.
const LINE_Z := 613
const LINE_ORIGIN := -400000
const LINE_STEP := 50
const LINE_SAMPLES := 16001

## Voxels in a kilometre, at `1 voxel = 0.5 m`, and the same distance counted in line
## samples. Both written out rather than divided, and
## `test_the_line_geometry_is_what_it_claims` asserts they agree.
const KILOMETRE_VOXELS := 2000
const KILOMETRE_SAMPLES := 40

## The band every decile of the field has to fall inside, and the standard deviation it has
## to land in. Measured over 24 climate layers (12 seeds × both climate salts) on this
## sweep: deciles `0.0713 .. 0.1584`, sd `0.3117 .. 0.3200`
## (`docs/world-generation.md` §10.2). The band is wide enough for seed variance and still
## catches both ways the curve can be got wrong — dropping it puts under `0.03` in each end
## decile, and applying it twice puts over `0.27` there.
const DECILE_FLOOR := 0.055
const DECILE_CEILING := 0.18
const SD_FLOOR := 0.30
const SD_CEILING := 0.33

## Side of the joint climate grid `test_every_climate_a_biome_could_ask_for_exists` counts
## over, and the share of the world each of its 16 cells has to hold. Measured over 12
## seeds: `0.0393 .. 0.0930` against an even `0.0625`.
const JOINT_SIDE := 4
const JOINT_FLOOR := 0.03
const JOINT_CEILING := 0.11


func _field_for(name: String) -> HumidityField:
	return HumidityField.for_world(GenerationFixtures.hash_for(name))


func _sampler_factory() -> Callable:
	return func(hash: GenerationHash) -> Callable:
		var wet := HumidityField.for_world(hash)
		return func(column: Vector2i) -> float: return wet.at(column)


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


func _sweep_values(name: String) -> Array[float]:
	var wet := _field_for(name)
	var values: Array[float] = []
	for column in _sweep_columns():
		values.append(wet.at(column))
	return values


# ---------------------------------------------------------------------------
# Binding
# ---------------------------------------------------------------------------

func test_requires_a_world_binding() -> void:
	assert_null(HumidityField.for_world(null))


func test_binds_to_every_fixture_world() -> void:
	for name in GenerationFixtures.world_names():
		assert_not_null(_field_for(name), "world '%s' has a humidity field" % name)


func test_the_pinned_parameters_are_the_documented_ones() -> void:
	var wet := _field_for(GenerationFixtures.WORLD_TYPED)
	var layer := wet.noise()
	assert_eq(layer.cell_size(), HumidityField.CELL_SIZE_VOXELS)
	assert_eq(layer.cell_size(), 16384)
	assert_eq(layer.octaves(), HumidityField.OCTAVES)
	assert_almost_eq(layer.gain(), HumidityField.GAIN)
	assert_eq(layer.salt(), WorldHash.SALT_HUMIDITY)
	assert_almost_eq(HumidityField.cell_size_metres(), 8192.0)
	assert_almost_eq(HumidityField.finest_cell_metres(), 4096.0)


func test_the_humidity_salt_is_nobody_elses() -> void:
	# Two fields sharing a salt are one field, and here that would mean humidity is a
	# relabelling of the axis it is supposed to be independent of — which
	# `test_humidity_is_a_separate_axis_from_temperature` measures the consequence of.
	assert_ne(WorldHash.SALT_HUMIDITY, WorldHash.SALT_TEMPERATURE)
	assert_ne(WorldHash.SALT_HUMIDITY, WorldHash.SALT_CONTINENTALNESS)
	assert_ne(WorldHash.SALT_HUMIDITY, WorldHash.SALT_ELEVATION)
	assert_ne(WorldHash.SALT_HUMIDITY, WorldHash.SALT_RUGGEDNESS)


func test_the_two_climate_axes_are_measured_at_the_same_scale() -> void:
	# 065's answer to "are its constants really 064's": yes, and the equality is asserted
	# rather than left to two files that happen to agree. Different scales would put a
	# humidity boundary inside every temperature cell, which reads as a texture rather
	# than as a place — so if this ever fails, it should be because someone meant it.
	assert_eq(HumidityField.CELL_SIZE_VOXELS, TemperatureField.CELL_SIZE_VOXELS)
	assert_eq(HumidityField.OCTAVES, TemperatureField.OCTAVES)
	assert_almost_eq(HumidityField.GAIN, TemperatureField.GAIN)


func test_climate_is_the_coarsest_field_in_the_world() -> void:
	# The §9.2 scale decision, restated for this axis: every scale humidity carries is at
	# or above the coarsest scale of every field under it.
	var wet := _field_for(GenerationFixtures.WORLD_TYPED)
	var finest := wet.noise().finest_cell_size()
	assert_true(wet.noise().cell_size() > Continentalness.CELL_SIZE_VOXELS,
			"the climate cell (%d) is coarser than the continent cell (%d)" % [
					wet.noise().cell_size(), Continentalness.CELL_SIZE_VOXELS])
	assert_eq(finest, Continentalness.CELL_SIZE_VOXELS)
	assert_eq(finest, ErosionPass.RUGGEDNESS_CELL_SIZE_VOXELS)
	assert_true(finest > ElevationField.RELIEF_CELL_SIZE_VOXELS,
			"the finest climate cell (%d) is coarser than the coarsest relief cell (%d)"
					% [finest, ElevationField.RELIEF_CELL_SIZE_VOXELS])


# ---------------------------------------------------------------------------
# The redistribution curve
# ---------------------------------------------------------------------------

func test_the_spread_curve_is_the_one_temperature_uses() -> void:
	# The two axes share a curve *decision*, not a class. Asserting the whole curve rather
	# than its name is what makes that a checked claim: an experiment that redistributes
	# one axis differently from the other fails here rather than in a biome map.
	for step in 201:
		var raw := float(step) / 200.0
		assert_almost_eq(HumidityField.spread(raw), TemperatureField.spread(raw), 1e-12,
				"the two axes redistribute %s the same way" % raw)


func test_the_spread_curve_fixes_both_ends_and_the_middle() -> void:
	assert_almost_eq(HumidityField.spread(0.0), 0.0, 1e-12)
	assert_almost_eq(HumidityField.spread(0.5), 0.5, 1e-12)
	assert_almost_eq(HumidityField.spread(1.0), 1.0, 1e-12)


func test_the_field_is_its_layer_through_the_curve() -> void:
	# `raw_at()` is what a debug probe reads; it has to be the value `at()` actually starts
	# from, not a second sample that drifts from it.
	var wet := _field_for(GenerationFixtures.WORLD_TYPED)
	for column in GenerationFixtures.columns():
		assert_almost_eq(wet.at(column), HumidityField.spread(wet.raw_at(column)), 1e-12,
				"column %s is its raw value through the curve" % column)
		assert_in_range(wet.raw_at(column), 0.0, 1.0,
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
		var wet := _field_for(name)
		var sampler := func(column: Vector2i) -> float: return wet.at(column)
		assert_eq(GenerationFixtures.range_reason(sampler, GenerationFixtures.columns(),
				HumidityField.MINIMUM, HumidityField.MAXIMUM), "",
				"world '%s' stays in range" % name)


func test_varies_across_the_sample_columns() -> void:
	var wet := _field_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> float: return wet.at(column)
	assert_eq(GenerationFixtures.variation_reason(sampler, GenerationFixtures.columns(),
			8), "")


func test_signature_is_pinned() -> void:
	var wet := _field_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> float: return wet.at(column)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.columns()),
			PINNED_SIGNATURE)


func test_a_voxel_reads_its_own_column() -> void:
	var wet := _field_for(GenerationFixtures.WORLD_TYPED)
	for voxel in GenerationFixtures.voxels():
		assert_eq(wet.at_voxel(voxel), wet.at(GenerationGrid.voxel_to_column(voxel)),
				"voxel %s reads its column" % voxel)


# ---------------------------------------------------------------------------
# What the field measures
# ---------------------------------------------------------------------------

func test_the_sweep_is_wide_enough_to_measure_a_climate() -> void:
	# The finding of the brick, asserted as geometry so the tests below cannot quietly go
	# back to a sweep that is too fine to see this field. A sample spacing under one cell
	# edge measures the same cell several times over: 064's 2304-column sweep contains only
	# about 144 independent climate cells, and its decile histogram moves by more than a
	# tenth of the range between fixture worlds.
	assert_true(SWEEP_SPACING > HumidityField.CELL_SIZE_VOXELS >> 1,
			"the sweep spacing (%d) is on the scale of a climate cell (%d)" % [
					SWEEP_SPACING, HumidityField.CELL_SIZE_VOXELS])
	var lowest := SWEEP_ORIGIN
	var highest := SWEEP_ORIGIN + (SWEEP_SIDE - 1) * SWEEP_SPACING
	assert_true(lowest >= -WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS
			and highest <= WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS,
			"the sweep (%d .. %d) stays inside the world" % [lowest, highest])
	assert_true(highest - lowest > WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS,
			"the sweep spans most of the world (%d voxels)" % (highest - lowest))


func test_the_world_has_wet_and_dry_ends_in_every_world() -> void:
	# The claim of the brick. A classifier can only find a desert or a swamp if columns
	# near the ends of this field exist — in every world, not in the one the test picked.
	for name in GenerationFixtures.world_names():
		var lowest := 2.0
		var highest := -1.0
		for value in _sweep_values(name):
			lowest = minf(lowest, value)
			highest = maxf(highest, value)
		assert_true(lowest < 0.001, "world '%s' has a driest place (%s)" % [name, lowest])
		assert_true(highest > 0.999, "world '%s' has a wettest place (%s)" % [
				name, highest])


func test_no_tenth_of_the_humidity_range_is_empty() -> void:
	# Stronger than reaching the ends, and the property biome thresholds actually depend
	# on: wherever brick 066 puts a boundary, a useful share of the world falls on each
	# side of it. The field is mildly U-shaped rather than uniform — the curve pushes the
	# tails out further than it thins the middle — so the band is not centred on 10%.
	for name in GenerationFixtures.world_names():
		var values := _sweep_values(name)
		var deciles := _deciles(values)
		for index in deciles.size():
			assert_in_range(deciles[index], DECILE_FLOOR, DECILE_CEILING,
					"world '%s' decile %d holds a workable share (%.4f)" % [
							name, index, deciles[index]])
		assert_in_range(_standard_deviation(values), SD_FLOOR, SD_CEILING,
				"world '%s' is spread across its range (sd %s)" % [
						name, _standard_deviation(values)])


func test_the_curve_is_what_earns_that_distribution() -> void:
	# The same sweep before `spread()`. The raw layer piles about 60% of the world into
	# the middle four deciles and leaves under 3% in each end decile — a humidity axis
	# brick 066 could not put a desert threshold on. This is the measurement the curve
	# exists because of, and it is here so that removing the curve fails a test rather than
	# quietly flattening the map.
	#
	# Note what is *not* asserted: that the raw layer never reaches the ends. Over a sweep
	# this wide it does, on a handful of columns out of 4096 (064's narrower sweep saw
	# `0.016 .. 0.983` and concluded otherwise). Reaching an end on 0.1% of the world is
	# not the same as having a decile there, and the distribution is the honest claim.
	for name in GenerationFixtures.world_names():
		var wet := _field_for(name)
		var raw: Array[float] = []
		for column in _sweep_columns():
			raw.append(wet.raw_at(column))
		var deciles := _deciles(raw)
		var middle := deciles[3] + deciles[4] + deciles[5] + deciles[6]
		assert_true(middle > 0.55,
				"world '%s' raw layer crowds its middle (%.4f in four deciles)" % [
						name, middle])
		assert_true(deciles[0] < 0.03 and deciles[9] < 0.03,
				"world '%s' raw layer leaves its ends nearly empty (%.4f / %.4f)" % [
						name, deciles[0], deciles[9]])
		assert_true(_standard_deviation(raw) < 0.24,
				"world '%s' raw layer is narrower than the field (sd %s)" % [
						name, _standard_deviation(raw)])


func test_humidity_is_a_separate_axis_from_temperature() -> void:
	# What makes a climate a *pair* rather than a line through the square: a hot place is
	# no more likely to be wet than a cold one. If a future edit gave the two axes one
	# salt, or derived one from the other, this is where it shows up — before it shows up
	# as a world with four biomes in it instead of nine.
	for name in GenerationFixtures.world_names():
		var hash := GenerationFixtures.hash_for(name)
		var wet := HumidityField.for_world(hash)
		var warm := TemperatureField.for_world(hash)
		var humidities: Array[float] = []
		var temperatures: Array[float] = []
		for column in _sweep_columns():
			humidities.append(wet.at(column))
			temperatures.append(warm.at(column))
		var r := _correlation(humidities, temperatures)
		assert_true(absf(r) < 0.05,
				"world '%s': humidity is uncorrelated with temperature (r = %s)" % [
						name, r])


func test_humidity_is_a_separate_axis_from_the_ground() -> void:
	# 064's finding, owed again by this axis: climate shares nothing with the height field
	# (`terrain-climate-blend.md` claim 7). Continentalness is the interesting one here —
	# real coasts are wetter than continental interiors, and this test is what says we did
	# not quietly take that (`docs/world-generation.md` §10.3).
	for name in GenerationFixtures.world_names():
		var hash := GenerationFixtures.hash_for(name)
		var wet := HumidityField.for_world(hash)
		var ground := ErosionPass.for_world(hash)
		var macro := Continentalness.for_world(hash)
		var humidities: Array[float] = []
		var heights: Array[float] = []
		var continents: Array[float] = []
		for column in _sweep_columns():
			humidities.append(wet.at(column))
			heights.append(ground.at(column))
			continents.append(macro.at(column))
		var with_height := _correlation(humidities, heights)
		var with_continent := _correlation(humidities, continents)
		assert_true(absf(with_height) < 0.05,
				"world '%s': humidity is uncorrelated with ground height (r = %s)" % [
						name, with_height])
		assert_true(absf(with_continent) < 0.05,
				"world '%s': humidity is uncorrelated with continentalness (r = %s)" % [
						name, with_continent])


func test_every_climate_a_biome_could_ask_for_exists() -> void:
	# The pair of axes is only worth two fields if the whole square is populated. Brick 066
	# will cut this square up; this is the test that says none of its pieces is empty in
	# any world — including the corners, which are the hot desert, the hot swamp, the cold
	# desert and the tundra.
	for name in GenerationFixtures.world_names():
		var hash := GenerationFixtures.hash_for(name)
		var wet := HumidityField.for_world(hash)
		var warm := TemperatureField.for_world(hash)
		var grid := PackedFloat64Array()
		grid.resize(JOINT_SIDE * JOINT_SIDE)
		var columns := _sweep_columns()
		for column in columns:
			var row := clampi(int(warm.at(column) * JOINT_SIDE), 0, JOINT_SIDE - 1)
			var col := clampi(int(wet.at(column) * JOINT_SIDE), 0, JOINT_SIDE - 1)
			grid[row * JOINT_SIDE + col] += 1.0
		for row in JOINT_SIDE:
			for col in JOINT_SIDE:
				var share := grid[row * JOINT_SIDE + col] / float(columns.size())
				assert_in_range(share, JOINT_FLOOR, JOINT_CEILING,
						"world '%s': climate cell (T %d, H %d) holds %.4f of the world" % [
								name, row, col, share])


# ---------------------------------------------------------------------------
# Walking into a climate
# ---------------------------------------------------------------------------

func test_the_line_geometry_is_what_it_claims() -> void:
	# The walking tests read a sampled line, not every voxel of it. That is only honest if
	# the sampling step divides the kilometre exactly, the line is long enough to contain
	# several climate cells, and it stays inside the world at both ends.
	assert_eq(KILOMETRE_SAMPLES * LINE_STEP, KILOMETRE_VOXELS)
	assert_almost_eq(WorldScale.voxels_to_metres(float(KILOMETRE_VOXELS)), 1000.0)
	var span := (LINE_SAMPLES - 1) * LINE_STEP
	assert_true(span > 16 * HumidityField.CELL_SIZE_VOXELS,
			"the line (%d voxels) crosses many climate cells (%d voxels each)" % [
					span, HumidityField.CELL_SIZE_VOXELS])
	assert_true(LINE_ORIGIN >= -WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS
			and LINE_ORIGIN + span <= WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS,
			"the line stays inside the world (%d .. %d)" % [
					LINE_ORIGIN, LINE_ORIGIN + span])


func _line_values(field_at: Callable) -> Array[float]:
	var line: Array[float] = []
	for index in LINE_SAMPLES:
		line.append(field_at.call(Vector2i(LINE_ORIGIN + index * LINE_STEP, LINE_Z)))
	return line


func test_a_kilometre_of_walking_never_changes_the_weather_much() -> void:
	# The other half of the brick's claim, and the one the scale constants exist for.
	# Every kilometre of the long line is checked, not one hand-picked one.
	var wet := _field_for(GenerationFixtures.WORLD_TYPED)
	var line := _line_values(func(column: Vector2i) -> float: return wet.at(column))
	var bound := wet.max_step_per_voxel() * float(KILOMETRE_VOXELS)
	var worst := 0.0
	for start in range(0, line.size() - KILOMETRE_SAMPLES):
		var lowest := 2.0
		var highest := -1.0
		for index in range(start, start + KILOMETRE_SAMPLES + 1):
			lowest = minf(lowest, line[index])
			highest = maxf(highest, line[index])
		worst = maxf(worst, highest - lowest)
	assert_true(worst <= bound + 1e-12,
			"the worst kilometre (%s) is within the derived bound (%s)" % [worst, bound])
	assert_true(worst < 0.5,
			"no kilometre crosses half the humidity range (worst %s)" % worst)
	# ... and the line is not flat: somewhere along it the climate really does change.
	assert_true(worst > 0.2,
			"some kilometre carries a real humidity gradient (worst %s)" % worst)


func test_the_long_line_crosses_the_whole_humidity_range() -> void:
	# The complement of the test above: gentle everywhere, and still a world with both ends
	# in it. A player walking east long enough leaves one climate and arrives in another.
	var wet := _field_for(GenerationFixtures.WORLD_TYPED)
	var lowest := 2.0
	var highest := -1.0
	for value in _line_values(func(column: Vector2i) -> float: return wet.at(column)):
		lowest = minf(lowest, value)
		highest = maxf(highest, value)
	assert_true(lowest < 0.05, "the line reaches dry ground (%s)" % lowest)
	assert_true(highest > 0.95, "the line reaches wet ground (%s)" % highest)


func test_the_two_axes_can_be_at_opposite_ends_at_once() -> void:
	# Independence measured as a correlation is a statement about the whole map; this is
	# the same statement in the form brick 066 will use it. Somewhere on one straight line
	# the two axes disagree almost completely — which is what makes a hot desert a place
	# that can exist rather than an average of two middling fields.
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var wet := HumidityField.for_world(hash)
	var warm := TemperatureField.for_world(hash)
	var humidities := _line_values(func(column: Vector2i) -> float: return wet.at(column))
	var temperatures := _line_values(
			func(column: Vector2i) -> float: return warm.at(column))
	var widest := 0.0
	for index in humidities.size():
		widest = maxf(widest, absf(humidities[index] - temperatures[index]))
	assert_true(widest > 0.8,
			"the two axes are at opposite ends somewhere on the line (%s)" % widest)


func test_a_climate_crossing_is_at_least_a_kilometre_of_walking() -> void:
	# `minimum_climate_span_voxels()` is derived from the constants alone, so it is what a
	# later edit to `CELL_SIZE_VOXELS` or `OCTAVES` would move. Pinning the consequence
	# rather than the constant: however the layer is retuned, crossing from the driest to
	# the wettest value must stay a journey. Identical constants, so identical to
	# temperature's — asserted, because two axes that disagreed here would be two axes at
	# different scales.
	var wet := _field_for(GenerationFixtures.WORLD_TYPED)
	var warm := TemperatureField.for_world(
			GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED))
	assert_almost_eq(wet.minimum_climate_span_voxels(), 1.0 / wet.max_step_per_voxel(),
			1e-9)
	assert_almost_eq(wet.minimum_climate_span_voxels(),
			warm.minimum_climate_span_voxels(), 1e-9)
	assert_true(wet.minimum_climate_span_voxels() > float(KILOMETRE_VOXELS),
			"a full climate crossing is at least a kilometre (%s voxels)"
					% wet.minimum_climate_span_voxels())


func test_the_step_bound_is_a_real_constraint() -> void:
	# The bound is only worth asserting if it can fail. Raw positional hashing at this salt
	# is the humidity map this field exists not to produce: a different biome in every
	# column.
	var wet := _field_for(GenerationFixtures.WORLD_TYPED)
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var bound := wet.max_step_per_voxel()
	var violations := 0
	var previous := hash.value01_column(Vector2i(-100, LINE_Z), WorldHash.SALT_HUMIDITY)
	for x in range(-99, 101):
		var current := hash.value01_column(Vector2i(x, LINE_Z), WorldHash.SALT_HUMIDITY)
		if absf(current - previous) > bound:
			violations += 1
		previous = current
	assert_true(violations > 100,
			"white noise breaks the bound almost everywhere (%d of 200)" % violations)
