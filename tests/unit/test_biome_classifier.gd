extends TestCase
## `world/biomes/biome_classifier.gd` — which biome a column is in (brick 066).
##
## The three fields underneath are already covered (`test_temperature_field.gd`,
## `test_humidity_field.gd`, `test_erosion_pass.gd`), so this file is about what 066 adds:
## the **partition**, and what it does to the actual world.
##
## Two things make it read differently from the four Phase D field tests before it.
##
## 1. **The answer is an id, not a float.** `GenerationFixtures.range_reason()` does not
##    apply — there is no range — and `test_answers_only_with_ids_it_declares` is what
##    replaces it. `signature()` still applies and is type-strict, so a classifier that
##    started returning integers fails the pin.
## 2. **The partition is testable without a world.** `BiomeClassifier.classify()` is pure,
##    so totality, rule order and the boundary conventions are asserted exhaustively over a
##    dense grid of the unit cube rather than hunted for among columns.
##
## The world-scale measurements run on brick 065's **climate-scale sweep** — 4096 columns
## at a spacing above one climate cell — for the reason 065 found (`docs/world-generation.md`
## §10.4): a classifier is a climate consumer, and the 2304-column sweep the relief tests
## use resolves a 16384-voxel field only about 144 times.

## The digest of `at()` over `GenerationFixtures.columns()` for the `typed` world.
const PINNED_SIGNATURE := "33a42963660cb452"

## The climate-scale sweep, identical to `test_humidity_field.gd`'s: 4096 columns at a
## spacing wider than one climate cell, spanning 1032003 of the world's 1048576 voxels on
## each axis and staying inside `WorldBounds` at both ends.
const SWEEP_SIDE := 64
const SWEEP_SPACING := 16381
const SWEEP_ORIGIN := -524192

## The 800 km east–west line the walking tests read, on 065's geometry.
const LINE_Z := 613
const LINE_ORIGIN := -400000
const LINE_STEP := 50
const LINE_SAMPLES := 16001

## Voxels in a kilometre, at `1 voxel = 0.5 m`, and the same distance counted in line
## samples.
const KILOMETRE_VOXELS := 2000
const KILOMETRE_SAMPLES := 40

## The share of the world every biome has to hold, on every world.
##
## Measured over the climate-scale sweep on 12 seeds: `0.1426 .. 0.2102` against an even
## `0.1667` (`docs/world-generation.md` §11.4). The band is wide enough for seed variance
## and still an order of magnitude tighter than what a mis-ordered rule does — swapping the
## cold test above the mountain test empties nothing but moves two biomes by a third.
const SHARE_FLOOR := 0.12
const SHARE_CEILING := 0.24

## The mean length of a run of one biome along the line, in kilometres. Measured
## `3.05 .. 3.25` on the four fixture worlds.
const MEAN_RUN_KILOMETRES_FLOOR := 2.0

## Share of mountain columns that are also cold. Mountains are placed by a field that
## shares nothing with climate, so this should be the share of the *world* that is cold —
## about `0.24` — rather than 0 or 1.
const COLD_MOUNTAIN_FLOOR := 0.15
const COLD_MOUNTAIN_CEILING := 0.35

## Resolution of the exhaustive grid over the unit cube. 21 steps per axis puts a sample
## exactly on every threshold (`0.2`, `0.5`, `0.8`) as well as between them.
const GRID_STEPS := 21


## Sweeps and lines are cached per world for the run, keyed by world name. The runner
## builds this class once per file, and classifying 4096 columns costs three noise fields
## per column — recomputing it in each of the four tests that want it would make this file
## the slowest in the suite for no extra coverage. Nothing here mutates the cache after
## first fill, so test order stays irrelevant.
var _sweep_cache: Dictionary = {}
var _line_cache: Dictionary = {}


func _classifier_for(name: String) -> BiomeClassifier:
	return BiomeClassifier.for_world(GenerationFixtures.hash_for(name))


func _sampler_factory() -> Callable:
	return func(hash: GenerationHash) -> Callable:
		var biomes := BiomeClassifier.for_world(hash)
		return func(column: Vector2i) -> String: return biomes.at(column)


func _sweep_columns() -> Array[Vector2i]:
	var columns: Array[Vector2i] = []
	for ix in SWEEP_SIDE:
		for iz in SWEEP_SIDE:
			columns.append(Vector2i(SWEEP_ORIGIN + ix * SWEEP_SPACING,
					SWEEP_ORIGIN + iz * SWEEP_SPACING))
	return columns


## The classified sweep of one world: `{"ids": PackedStringArray, "samples": Array[Vector3]}`,
## in `_sweep_columns()` order. Both halves come from one pass, because the tests that want
## the inputs also want the answers.
func _sweep_of(name: String) -> Dictionary:
	if _sweep_cache.has(name):
		var cached: Dictionary = _sweep_cache[name]
		return cached
	var biomes := _classifier_for(name)
	var ids := PackedStringArray()
	var samples: Array[Vector3] = []
	for column in _sweep_columns():
		var sample := biomes.sample_at(column)
		samples.append(sample)
		ids.append(BiomeClassifier.classify(sample.x, sample.y, sample.z))
	var entry := {"ids": ids, "samples": samples}
	_sweep_cache[name] = entry
	return entry


## How the sweep of one world falls across the six ids, as shares summing to 1.
func _shares(name: String) -> Dictionary:
	var ids: PackedStringArray = _sweep_of(name)["ids"]
	var counts: Dictionary = {}
	for id in BiomeClassifier.IDS:
		counts[id] = 0.0
	for id in ids:
		counts[id] += 1.0
	for id in counts:
		counts[id] /= float(ids.size())
	return counts


## The biome at every sample of the 800 km line, in order.
func _line_ids(name: String) -> PackedStringArray:
	if _line_cache.has(name):
		var cached: PackedStringArray = _line_cache[name]
		return cached
	var biomes := _classifier_for(name)
	var line := PackedStringArray()
	for index in LINE_SAMPLES:
		line.append(biomes.at(Vector2i(LINE_ORIGIN + index * LINE_STEP, LINE_Z)))
	_line_cache[name] = line
	return line


## Lengths, in samples, of each maximal run of one biome along `line`.
func _run_lengths(line: PackedStringArray) -> Array[int]:
	var runs: Array[int] = []
	var previous := ""
	var length := 0
	for id in line:
		if id == previous:
			length += 1
		else:
			if not previous.is_empty():
				runs.append(length)
			previous = id
			length = 1
	runs.append(length)
	return runs


# ---------------------------------------------------------------------------
# Binding
# ---------------------------------------------------------------------------

func test_requires_a_world_binding() -> void:
	assert_null(BiomeClassifier.for_world(null))


func test_binds_to_every_fixture_world() -> void:
	for name in GenerationFixtures.world_names():
		assert_not_null(_classifier_for(name), "world '%s' has a classifier" % name)


func test_the_partition_is_coherent() -> void:
	# The whole threshold table in one assertion, for `GenerationVersion.self_check()`'s
	# reason: a table that has quietly drifted makes every biome in the world wrong while
	# each individual test below still passes.
	assert_eq(BiomeClassifier.self_check(), "")


func test_the_ids_are_stable_ids_in_the_biome_domain() -> void:
	# A biome id is written into save files and logs (`CLAUDE.md` §9), so it obeys the same
	# grammar as an item or a block id. `self_check()` covers this too; asserting it here
	# as well is what makes the failure point at the id rather than at the table.
	assert_size(BiomeClassifier.IDS, 6)
	for id in BiomeClassifier.IDS:
		assert_eq(StableId.validate(id), "", "'%s' is a stable id" % id)
		assert_eq(StableId.domain_of(id), "biome", "'%s' is a biome" % id)
		assert_true(BiomeClassifier.is_biome_id(id), "'%s' is recognised" % id)
	assert_false(BiomeClassifier.is_biome_id("biome.tundra"))
	assert_false(BiomeClassifier.is_biome_id("grassland"))


# ---------------------------------------------------------------------------
# Where the thresholds come from
# ---------------------------------------------------------------------------

func test_the_climate_cuts_are_the_references_literals() -> void:
	# `docs/reference/terrain-climate-blend.md` claim 5: the original reads climate on a
	# bare `[0, 1]` scale against `< 0.2` and `> 0.8`. We could not reuse its climate
	# *mechanism* — it blends stored per-region values and ours is a noise layer (§9.3) —
	# but the scale it reads the result on is exactly ours, and these two literals are the
	# one piece of its classification that survived the read. Asserted so that retuning
	# them is a decision about a divergence, not an edit.
	assert_almost_eq(BiomeClassifier.TEMPERATURE_COLD, 0.2)
	assert_almost_eq(BiomeClassifier.HUMIDITY_WETLAND, 0.8)


func test_the_dry_and_wet_cuts_are_symmetric() -> void:
	# `HUMIDITY_ARID` is written as `1 - HUMIDITY_WETLAND`, so the two ends of the axis are
	# cut at the same distance from it. This asserts what that buys: moving one end moves
	# the other, instead of leaving a world that is dry three times more often than it is
	# wet without anyone deciding so.
	assert_almost_eq(BiomeClassifier.HUMIDITY_ARID + BiomeClassifier.HUMIDITY_WETLAND, 1.0)
	assert_almost_eq(BiomeClassifier.HUMIDITY_ARID, 0.2)
	assert_true(BiomeClassifier.HUMIDITY_ARID < BiomeClassifier.HUMIDITY_WOODED
			and BiomeClassifier.HUMIDITY_WOODED < BiomeClassifier.HUMIDITY_WETLAND,
			"the three humidity cuts are in order")


func test_the_wooded_cut_is_the_fields_own_middle() -> void:
	# The one threshold with no reference anchor, and the neutral choice for
	# `ElevationField.SHORE_MIDPOINT`'s reason: `HumidityField.spread()` fixes `0.5`, so
	# this cuts the temperate band in half rather than pre-baking how much of the world is
	# wooded.
	assert_almost_eq(BiomeClassifier.HUMIDITY_WOODED, 0.5)
	assert_almost_eq(HumidityField.spread(BiomeClassifier.HUMIDITY_WOODED),
			BiomeClassifier.HUMIDITY_WOODED, 1e-12)


func test_the_mountain_threshold_is_where_relief_starts_winning() -> void:
	# `RUGGEDNESS_MOUNTAIN` is derived from `ErosionPass`, not chosen: it is the ruggedness
	# at which `ruggedness_weight()` reaches the middle of its own range, so the rule reads
	# "a column that keeps more than half the relief in the world". Retuning
	# `RUGGEDNESS_FLOOR` moves the weight curve but not this identity; changing the
	# *shape* of the curve breaks it here, which is where that decision should be answered.
	var midpoint := (ErosionPass.RUGGEDNESS_FLOOR + 1.0) * 0.5
	assert_almost_eq(ErosionPass.ruggedness_weight(BiomeClassifier.RUGGEDNESS_MOUNTAIN),
			midpoint, 1e-12)
	assert_true(ErosionPass.ruggedness_weight(BiomeClassifier.RUGGEDNESS_MOUNTAIN * 0.99)
			< midpoint, "just below the threshold keeps less than half the relief")


# ---------------------------------------------------------------------------
# The partition, with no world attached
# ---------------------------------------------------------------------------

func test_every_point_of_the_input_cube_gets_a_declared_id() -> void:
	# Totality. A decision list whose last rule matches everything cannot fail this, which
	# is the point: the assertion is here so that adding a guard clause to `classify()`
	# without a fallback fails immediately rather than in a chunk that silently generates
	# nothing.
	for it in GRID_STEPS:
		for ih in GRID_STEPS:
			for ir in GRID_STEPS:
				var id := BiomeClassifier.classify(float(it) / (GRID_STEPS - 1),
						float(ih) / (GRID_STEPS - 1), float(ir) / (GRID_STEPS - 1))
				assert_true(BiomeClassifier.is_biome_id(id),
						"(%d, %d, %d) classified as '%s'" % [it, ih, ir, id])


func test_every_rule_is_reachable() -> void:
	# A rule shadowed by one above it is a biome that exists in the catalog and nowhere in
	# the world. The dense grid finds all six or names the missing one.
	var seen: Dictionary = {}
	for it in GRID_STEPS:
		for ih in GRID_STEPS:
			for ir in GRID_STEPS:
				seen[BiomeClassifier.classify(float(it) / (GRID_STEPS - 1),
						float(ih) / (GRID_STEPS - 1), float(ir) / (GRID_STEPS - 1))] = true
	for id in BiomeClassifier.IDS:
		assert_true(seen.has(id), "'%s' is reachable" % id)


func test_the_partition_is_the_documented_decision_list() -> void:
	# One representative point per rule, in the middle of its region rather than on an
	# edge. This is the table in the class comment, written as an assertion.
	assert_eq(BiomeClassifier.classify(0.5, 0.5, 0.9), BiomeClassifier.MOUNTAIN)
	assert_eq(BiomeClassifier.classify(0.1, 0.5, 0.1), BiomeClassifier.SNOW)
	assert_eq(BiomeClassifier.classify(0.5, 0.1, 0.1), BiomeClassifier.DESERT)
	assert_eq(BiomeClassifier.classify(0.5, 0.9, 0.1), BiomeClassifier.WETLAND)
	assert_eq(BiomeClassifier.classify(0.5, 0.65, 0.1), BiomeClassifier.FOREST)
	assert_eq(BiomeClassifier.classify(0.5, 0.35, 0.1), BiomeClassifier.GRASSLAND)


func test_relief_outranks_climate() -> void:
	# Rule 1's whole content: a column rugged enough to be a mountain is a mountain in any
	# weather. If a later edit moved the mountain test below the cold test, half the
	# mountains in the world would become snowfields — visible on a map, invisible in a
	# test that only samples the middle of the climate square.
	for it in GRID_STEPS:
		for ih in GRID_STEPS:
			assert_eq(BiomeClassifier.classify(float(it) / (GRID_STEPS - 1),
					float(ih) / (GRID_STEPS - 1), BiomeClassifier.RUGGEDNESS_MOUNTAIN),
					BiomeClassifier.MOUNTAIN,
					"(T %d, H %d) at the mountain threshold is a mountain" % [it, ih])


func test_cold_outranks_wet_and_dry() -> void:
	# Rule 2's content: cold-and-dry is tundra and cold-and-wet is taiga, and with six
	# baseline biomes both of those are `biome.snow`. Asserted across the whole humidity
	# axis so that the claim is "humidity does not matter when it is cold", not "one cold
	# sample happened to be snow".
	for ih in GRID_STEPS:
		assert_eq(BiomeClassifier.classify(0.0, float(ih) / (GRID_STEPS - 1), 0.0),
				BiomeClassifier.SNOW, "the coldest column at H %d is snow" % ih)


func test_the_cuts_are_half_open_at_the_documented_end() -> void:
	# Which side of a threshold the boundary itself falls on. Every rule uses `<` for a low
	# cut and `>=` for a high one, so a column sitting exactly on a threshold belongs to the
	# *upper* region — the convention `TerracePass` already uses for its risers. Asserted
	# because it is invisible in a grid test whose samples miss the boundaries, and because
	# `HUMIDITY_ARID` and `HUMIDITY_WETLAND` are exact binary fractions that columns really
	# can land on.
	assert_eq(BiomeClassifier.classify(BiomeClassifier.TEMPERATURE_COLD, 0.35, 0.0),
			BiomeClassifier.GRASSLAND, "exactly at the cold cut is not cold")
	assert_eq(BiomeClassifier.classify(0.5, BiomeClassifier.HUMIDITY_ARID, 0.0),
			BiomeClassifier.GRASSLAND, "exactly at the arid cut is not desert")
	assert_eq(BiomeClassifier.classify(0.5, BiomeClassifier.HUMIDITY_WOODED, 0.0),
			BiomeClassifier.FOREST, "exactly at the wooded cut is forest")
	assert_eq(BiomeClassifier.classify(0.5, BiomeClassifier.HUMIDITY_WETLAND, 0.0),
			BiomeClassifier.WETLAND, "exactly at the wetland cut is wetland")


func test_the_extremes_of_the_climate_square_are_the_biomes_they_should_be() -> void:
	# The four corners brick 065 measured the population of (`docs/world-generation.md`
	# §10.3), each read as the biome a player would name it.
	assert_eq(BiomeClassifier.classify(1.0, 0.0, 0.0), BiomeClassifier.DESERT)
	assert_eq(BiomeClassifier.classify(1.0, 1.0, 0.0), BiomeClassifier.WETLAND)
	assert_eq(BiomeClassifier.classify(0.0, 0.0, 0.0), BiomeClassifier.SNOW)
	assert_eq(BiomeClassifier.classify(0.0, 1.0, 0.0), BiomeClassifier.SNOW)


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


func test_answers_only_with_ids_it_declares() -> void:
	# What replaces `range_reason()` for a classifier: there is no range to stay inside,
	# and the equivalent failure — an answer nothing downstream can look up — is an id
	# outside `IDS`. The type check is deliberate: a classifier that started returning an
	# index would pass a naive `IDS.has()` on nothing at all.
	for name in GenerationFixtures.world_names():
		var biomes := _classifier_for(name)
		for column in GenerationFixtures.columns():
			var answer: Variant = biomes.at(column)
			assert_eq(typeof(answer), TYPE_STRING,
					"world '%s' column %s answered with a string" % [name, column])
			assert_true(BiomeClassifier.is_biome_id(str(answer)),
					"world '%s' column %s answered '%s'" % [name, column, answer])


func test_varies_across_the_sample_columns() -> void:
	# The fixture columns sit deliberately close together (`docs/world-generation.md` §8.4),
	# and this field is coarser than every field before it — one climate cell is 16384
	# voxels and most of those columns are inside a single cell. Two distinct biomes is
	# what that sample set can honestly demand; the world-scale claim is
	# `test_every_biome_is_a_real_share_of_every_world`.
	var biomes := _classifier_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> String: return biomes.at(column)
	assert_eq(GenerationFixtures.variation_reason(sampler, GenerationFixtures.columns(),
			2), "")


func test_signature_is_pinned() -> void:
	var biomes := _classifier_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> String: return biomes.at(column)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.columns()),
			PINNED_SIGNATURE)


func test_a_voxel_reads_its_own_column() -> void:
	var biomes := _classifier_for(GenerationFixtures.WORLD_TYPED)
	for voxel in GenerationFixtures.voxels():
		assert_eq(biomes.at_voxel(voxel),
				biomes.at(GenerationGrid.voxel_to_column(voxel)),
				"voxel %s reads its column" % voxel)


func test_the_classifier_is_its_three_fields_through_the_partition() -> void:
	# `sample_at()` is what a debug probe and brick 074 read; it has to be the same three
	# numbers `at()` actually classified, not a second set of samples that can drift from
	# them.
	var biomes := _classifier_for(GenerationFixtures.WORLD_TYPED)
	for column in GenerationFixtures.columns():
		var sample := biomes.sample_at(column)
		assert_almost_eq(sample.x, biomes.temperature_field().at(column), 1e-12)
		assert_almost_eq(sample.y, biomes.humidity_field().at(column), 1e-12)
		assert_almost_eq(sample.z, biomes.erosion_pass().ruggedness_noise_at(column), 1e-12)
		assert_eq(biomes.at(column),
				BiomeClassifier.classify(sample.x, sample.y, sample.z),
				"column %s is its sample through the partition" % column)


# ---------------------------------------------------------------------------
# What the classifier measures
# ---------------------------------------------------------------------------

func test_the_sweep_is_wide_enough_to_measure_a_climate() -> void:
	# 065's finding, owed by every climate consumer: a sample spacing under one cell edge
	# measures the same cell several times over and reports it as a sample of the world
	# (`docs/world-generation.md` §10.4). Asserted as geometry so the measurements below
	# cannot quietly move to a finer sweep.
	assert_true(SWEEP_SPACING > TemperatureField.CELL_SIZE_VOXELS >> 1,
			"the sweep spacing (%d) is on the scale of a climate cell (%d)" % [
					SWEEP_SPACING, TemperatureField.CELL_SIZE_VOXELS])
	var lowest := SWEEP_ORIGIN
	var highest := SWEEP_ORIGIN + (SWEEP_SIDE - 1) * SWEEP_SPACING
	assert_true(lowest >= -WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS
			and highest <= WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS,
			"the sweep (%d .. %d) stays inside the world" % [lowest, highest])
	assert_true(highest - lowest > WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS,
			"the sweep spans most of the world (%d voxels)" % (highest - lowest))


func test_every_biome_is_a_real_share_of_every_world() -> void:
	# The claim of the brick, and the thing 067–073 depend on: six biomes, every one of
	# them a place in every world. None of the five thresholds was fitted to make this come
	# out even — the evenness is inherited from `spread()`, which leaves about a quarter of
	# each climate axis below `0.2` and a quarter above `0.8` — so this is a measurement
	# rather than a target (`docs/world-generation.md` §11.4).
	for name in GenerationFixtures.world_names():
		var shares := _shares(name)
		for id in BiomeClassifier.IDS:
			var share: float = shares[id]
			assert_in_range(share, SHARE_FLOOR, SHARE_CEILING,
					"world '%s': '%s' holds %.4f of the world" % [name, id, share])


func test_the_mountains_are_not_a_climate() -> void:
	# Mountains are placed by a field that shares no salt and no term with either climate
	# axis, so the mountains of a world should be as cold as the world is. If a later edit
	# derived ruggedness from temperature — or classified on a height, which follows
	# continentalness — this is where it shows up, before it shows up as every mountain in
	# the world being snow-capped.
	for name in GenerationFixtures.world_names():
		var sweep := _sweep_of(name)
		var ids: PackedStringArray = sweep["ids"]
		var samples: Array[Vector3] = sweep["samples"]
		var mountains := 0
		var cold_mountains := 0
		for index in ids.size():
			if ids[index] != BiomeClassifier.MOUNTAIN:
				continue
			mountains += 1
			if samples[index].x < BiomeClassifier.TEMPERATURE_COLD:
				cold_mountains += 1
		assert_true(mountains > 0, "world '%s' has mountains" % name)
		assert_in_range(float(cold_mountains) / float(mountains),
				COLD_MOUNTAIN_FLOOR, COLD_MOUNTAIN_CEILING,
				"world '%s': %d of %d mountains are cold" % [
						name, cold_mountains, mountains])


# ---------------------------------------------------------------------------
# Walking across a biome
# ---------------------------------------------------------------------------

func test_the_line_geometry_is_what_it_claims() -> void:
	assert_eq(KILOMETRE_SAMPLES * LINE_STEP, KILOMETRE_VOXELS)
	assert_almost_eq(WorldScale.voxels_to_metres(float(KILOMETRE_VOXELS)), 1000.0)
	var span := (LINE_SAMPLES - 1) * LINE_STEP
	assert_true(span > 16 * TemperatureField.CELL_SIZE_VOXELS,
			"the line (%d voxels) crosses many climate cells (%d voxels each)" % [
					span, TemperatureField.CELL_SIZE_VOXELS])
	assert_true(LINE_ORIGIN >= -WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS
			and LINE_ORIGIN + span <= WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS,
			"the line stays inside the world (%d .. %d)" % [
					LINE_ORIGIN, LINE_ORIGIN + span])


func test_a_biome_is_a_place_a_player_walks_across() -> void:
	# The consequence of classifying fields whose cells are kilometres wide: a biome is
	# somewhere you spend minutes, not a texture that changes every few steps. Averaged
	# rather than floored, deliberately — a threshold on a continuous field always produces
	# the occasional sliver where the line grazes a boundary, and a minimum-run assertion
	# would be a test of where the line happens to be rather than of the classifier
	# (`docs/world-generation.md` §11.5). Brick 074 is what smooths those.
	var runs := _run_lengths(_line_ids(GenerationFixtures.WORLD_TYPED))
	var total := 0
	for length in runs:
		total += length
	var mean_kilometres := float(total) / float(runs.size()) / float(KILOMETRE_SAMPLES)
	assert_true(mean_kilometres > MEAN_RUN_KILOMETRES_FLOOR,
			"a biome lasts %.2f km on average along the line" % mean_kilometres)


func test_every_biome_is_on_one_line_across_the_world() -> void:
	# The strongest form of "every biome is somewhere": all six of them within 800 km of
	# walking due east, on a line chosen for brick 065 rather than for this test.
	var seen: Dictionary = {}
	for id in _line_ids(GenerationFixtures.WORLD_TYPED):
		seen[id] = true
	for id in BiomeClassifier.IDS:
		assert_true(seen.has(id), "'%s' is on the line" % id)


func test_a_climate_band_is_at_least_hundreds_of_metres_wide() -> void:
	# The floor the fields put under a biome band, derived rather than measured: neither
	# climate axis can cross its whole range in under `minimum_climate_span_voxels()`, and
	# the closest two cuts on one axis are `0.3` apart. A floor on the *climatic* boundaries
	# only — the mountain rule reads a much finer field and cuts across them.
	var biomes := _classifier_for(GenerationFixtures.WORLD_TYPED)
	assert_almost_eq(BiomeClassifier.narrowest_climate_gap(), 0.3, 1e-12)
	var band := biomes.minimum_climate_band_voxels()
	assert_true(band > 1000.0,
			"a climate band is at least %.1f voxels wide" % band)
	assert_almost_eq(band, minf(biomes.temperature_field().minimum_climate_span_voxels(),
			biomes.humidity_field().minimum_climate_span_voxels()) * 0.3, 1e-9)
