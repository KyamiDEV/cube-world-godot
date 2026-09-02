extends TestCase
## `world/biomes/biome_transition.gd` — how close a column sits to a different biome, and
## which one (brick 074).
##
## `BiomeClassifier.at()` answers one id, always, with no notion of a border — this file is
## about the second question this brick adds on top of the same three inputs: how far a
## column sits from a different answer, and which one it would be. `classify()` itself stays
## exactly as tested in `test_biome_classifier.gd`; nothing here re-asserts the partition.

## `BiomeClassifier.narrowest_climate_gap()` (`0.3`) halved.
const EXPECTED_TRANSITION_WIDTH := 0.15

## Resolution of the exhaustive grid over the unit cube — `test_biome_classifier.gd`'s
## reason: 21 steps per axis lands a sample exactly on every threshold as well as between
## them.
const GRID_STEPS := 21

## The digest of `neighbor_weight_at()` over `GenerationFixtures.columns()` for the `typed`
## world.
const PINNED_WEIGHT_SIGNATURE := "ab6dcc4542c8a2d1"


func _transition_for(name: String) -> BiomeTransition:
	return BiomeTransition.for_world(GenerationFixtures.hash_for(name))


# ---------------------------------------------------------------------------
# Binding
# ---------------------------------------------------------------------------

func test_requires_a_world_binding() -> void:
	assert_null(BiomeTransition.for_world(null))


func test_binds_to_every_fixture_world() -> void:
	for name in GenerationFixtures.world_names():
		assert_not_null(_transition_for(name), "world '%s' has a transition" % name)


# ---------------------------------------------------------------------------
# The width
# ---------------------------------------------------------------------------

func test_the_width_is_half_the_narrowest_climate_gap() -> void:
	# Asserted at runtime rather than trusted from the class comment: a call is not a const
	# expression (`generate_biome_catalog.gd`'s constraint, brick 067), so the derivation
	# cannot be written as one.
	assert_almost_eq(BiomeTransition.TRANSITION_WIDTH, EXPECTED_TRANSITION_WIDTH, 1e-12)
	assert_almost_eq(BiomeTransition.TRANSITION_WIDTH,
			BiomeClassifier.narrowest_climate_gap() * 0.5, 1e-12)
	assert_eq(BiomeTransition.self_check(), "")


# ---------------------------------------------------------------------------
# The pure form: no world attached
# ---------------------------------------------------------------------------

func test_a_boundary_always_exists() -> void:
	# Every one of the five thresholds flips `classify()`'s answer when nudged in isolation
	# (holding the other two inputs fixed) — flipping ruggedness across `RUGGEDNESS_MOUNTAIN`
	# either enters or leaves `MOUNTAIN`, and the other four all change which humidity or
	# temperature rule matches. So `nearest_boundary()` never comes back empty, anywhere on
	# the unit cube — the empty-dictionary case documented on it is defensive, not reachable.
	for it in GRID_STEPS:
		for ih in GRID_STEPS:
			for ir in GRID_STEPS:
				var t := float(it) / (GRID_STEPS - 1)
				var h := float(ih) / (GRID_STEPS - 1)
				var r := float(ir) / (GRID_STEPS - 1)
				var boundary := BiomeTransition.nearest_boundary(t, h, r)
				assert_false(boundary.is_empty(),
						"(%s, %s, %s) has a nearest boundary" % [t, h, r])
				var primary := BiomeClassifier.classify(t, h, r)
				assert_ne(boundary["neighbor"], primary,
						"(%s, %s, %s) the neighbor differs from the primary" % [t, h, r])
				assert_true(boundary["distance"] >= 0.0,
						"(%s, %s, %s) the distance is non-negative" % [t, h, r])


func test_the_neighbor_is_the_biome_just_past_the_boundary() -> void:
	# Desert, 0.05 below the arid cut: crossing it upward (humidity still under
	# `HUMIDITY_WOODED`) lands in grassland, not in whichever biome happens to be nearest in
	# id order.
	var desert := BiomeTransition.nearest_boundary(0.5, 0.15, 0.0)
	assert_eq(BiomeClassifier.classify(0.5, 0.15, 0.0), BiomeClassifier.DESERT)
	assert_eq(desert["neighbor"], BiomeClassifier.GRASSLAND)
	assert_almost_eq(desert["distance"], 0.05, 1e-12)

	# Forest, comfortably inside its humidity band (0.65, between `HUMIDITY_WOODED` and
	# `HUMIDITY_WETLAND`, away from both), 0.05 below the mountain cut: relief outranks
	# climate (§11.3), so the neighbor is `MOUNTAIN` even though a humidity cut sits closer
	# in id order.
	var forest := BiomeTransition.nearest_boundary(0.5, 0.65,
			BiomeClassifier.RUGGEDNESS_MOUNTAIN - 0.05)
	assert_eq(BiomeClassifier.classify(0.5, 0.65, BiomeClassifier.RUGGEDNESS_MOUNTAIN - 0.05),
			BiomeClassifier.FOREST)
	assert_eq(forest["neighbor"], BiomeClassifier.MOUNTAIN)
	assert_almost_eq(forest["distance"], 0.05, 1e-12)

	# Snow, 0.05 above the cold cut on the warm side: the only way out of `SNOW` at this
	# ruggedness is warming past `TEMPERATURE_COLD`, and the humidity here (0.5, exactly
	# `HUMIDITY_WOODED`) lands the departure in forest.
	var snow := BiomeTransition.nearest_boundary(BiomeClassifier.TEMPERATURE_COLD - 0.05,
			0.5, 0.0)
	assert_eq(BiomeClassifier.classify(BiomeClassifier.TEMPERATURE_COLD - 0.05, 0.5, 0.0),
			BiomeClassifier.SNOW)
	assert_eq(snow["neighbor"], BiomeClassifier.FOREST)
	assert_almost_eq(snow["distance"], 0.05, 1e-12)


func test_the_weight_is_a_half_on_the_boundary_and_zero_at_the_width() -> void:
	assert_almost_eq(BiomeTransition._weight_for_distance(0.0), 0.5, 1e-12)
	assert_almost_eq(
			BiomeTransition._weight_for_distance(BiomeTransition.TRANSITION_WIDTH), 0.0, 1e-12)
	var quarter := BiomeTransition._weight_for_distance(BiomeTransition.TRANSITION_WIDTH * 0.5)
	assert_true(quarter > 0.0 and quarter < 0.5,
			"the weight at half the width (%s) sits strictly between 0 and 0.5" % quarter)


func test_the_weight_never_exceeds_a_half() -> void:
	for step in GRID_STEPS:
		var distance := float(step) / (GRID_STEPS - 1) * BiomeTransition.TRANSITION_WIDTH * 2.0
		var weight := BiomeTransition._weight_for_distance(distance)
		assert_in_range(weight, 0.0, 0.5,
				"distance %s gives weight %s" % [distance, weight])


func test_the_two_sides_of_the_narrowest_band_meet_without_overlapping() -> void:
	# The humidity band between `HUMIDITY_ARID` (0.2) and `HUMIDITY_WOODED` (0.5) is the
	# narrowest gap `narrowest_climate_gap()` measures, 0.3 wide. Its midpoint is exactly
	# `TRANSITION_WIDTH` from each edge, so both blend zones reach zero exactly there rather
	# than overlapping into a three-way mix nothing asked for.
	var midpoint := BiomeClassifier.HUMIDITY_ARID + BiomeTransition.TRANSITION_WIDTH
	assert_almost_eq(midpoint, BiomeClassifier.HUMIDITY_WOODED - BiomeTransition.TRANSITION_WIDTH,
			1e-12, "the midpoint is equidistant from both cuts")
	var at_arid := BiomeTransition.nearest_boundary(0.5, BiomeClassifier.HUMIDITY_ARID, 0.0)
	assert_almost_eq(at_arid["distance"], 0.0, 1e-12)
	var at_wooded := BiomeTransition.nearest_boundary(0.5, BiomeClassifier.HUMIDITY_WOODED, 0.0)
	assert_almost_eq(at_wooded["distance"], 0.0, 1e-12)
	var boundary := BiomeTransition.nearest_boundary(0.5, midpoint, 0.0)
	assert_almost_eq(boundary["distance"], BiomeTransition.TRANSITION_WIDTH, 1e-12,
			"the midpoint sits exactly one width from its nearest cut")
	assert_almost_eq(BiomeTransition._weight_for_distance(boundary["distance"]), 0.0, 1e-12,
			"the blend has faded to zero by the time the two zones would otherwise meet")


func test_far_from_every_threshold_has_no_neighbor() -> void:
	# Deep desert: 0.2 from the arid cut (its own region's widest possible margin), 0.4 from
	# the cold cut, 0.707 from the mountain cut — every one of them past `TRANSITION_WIDTH`.
	var boundary := BiomeTransition.nearest_boundary(0.6, 0.0, 0.0)
	assert_true(boundary["distance"] >= BiomeTransition.TRANSITION_WIDTH,
			"the nearest boundary (%s) is still past the transition width" % boundary["distance"])
	assert_almost_eq(BiomeTransition._weight_for_distance(boundary["distance"]), 0.0, 1e-12)


func test_most_of_the_climate_cube_is_within_the_transition_width() -> void:
	# A measurement, not a target — and a surprising one worth stating plainly rather than
	# tuning away. `HUMIDITY_ARID`, `HUMIDITY_WOODED` and `HUMIDITY_WETLAND` sit exactly
	# `2 * TRANSITION_WIDTH` apart (`0.3`, `narrowest_climate_gap()`), so their three blend
	# zones tile the humidity axis edge to edge from `0.05` to `0.95` with no gap between
	# them — only the outer `0.05` at each end of the humidity axis is ever "pure". That is
	# a property of the **unit cube**, not of the world: a climate field only ever visits it
	# along an 8192-metre-per-cell path (§9.4), so this is not "73% of the world blends" —
	# `test_a_biome_is_a_place_a_player_walks_across` (`test_biome_classifier.gd`) is what
	# measures the world, at a 3-kilometre mean run. This test is what would catch
	# `TRANSITION_WIDTH` drifting wide enough to blend two humidity cuts into one continuous
	# smear, or narrow enough that the whole idea stops doing anything.
	var total := 0
	var blending := 0
	for it in GRID_STEPS:
		for ih in GRID_STEPS:
			for ir in GRID_STEPS:
				var t := float(it) / (GRID_STEPS - 1)
				var h := float(ih) / (GRID_STEPS - 1)
				var r := float(ir) / (GRID_STEPS - 1)
				total += 1
				var boundary := BiomeTransition.nearest_boundary(t, h, r)
				if boundary["distance"] < BiomeTransition.TRANSITION_WIDTH:
					blending += 1
	var share := float(blending) / float(total)
	assert_in_range(share, 0.65, 0.80,
			"%.4f of the climate cube sits within the transition width" % share)


# ---------------------------------------------------------------------------
# The bound instance
# ---------------------------------------------------------------------------

func test_blend_at_agrees_with_the_pure_functions() -> void:
	var transition := _transition_for(GenerationFixtures.WORLD_TYPED)
	var classifier := transition.classifier()
	for column in GenerationFixtures.columns():
		var blend := transition.blend_at(column)
		assert_eq(blend["primary"], classifier.at(column))
		assert_eq(blend["neighbor"], transition.neighbor_at(column))
		assert_almost_eq(blend["neighbor_weight"], transition.neighbor_weight_at(column), 1e-12)

		var sample := classifier.sample_at(column)
		var boundary := BiomeTransition.nearest_boundary(sample.x, sample.y, sample.z)
		if boundary["distance"] >= BiomeTransition.TRANSITION_WIDTH:
			assert_eq(blend["neighbor"], "")
			assert_almost_eq(blend["neighbor_weight"], 0.0, 1e-12)
		else:
			assert_eq(blend["neighbor"], boundary["neighbor"])


func test_a_voxel_reads_its_own_column() -> void:
	var transition := _transition_for(GenerationFixtures.WORLD_TYPED)
	for voxel in GenerationFixtures.voxels():
		var from_voxel := transition.blend_at_voxel(voxel)
		var from_column := transition.blend_at(GenerationGrid.voxel_to_column(voxel))
		assert_eq(from_voxel["primary"], from_column["primary"], "voxel %s" % voxel)
		assert_eq(from_voxel["neighbor"], from_column["neighbor"], "voxel %s" % voxel)
		assert_almost_eq(from_voxel["neighbor_weight"], from_column["neighbor_weight"], 1e-12)


# ---------------------------------------------------------------------------
# The shared determinism floor
# ---------------------------------------------------------------------------

func test_is_deterministic() -> void:
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory := func() -> Callable:
		var transition := BiomeTransition.for_world(hash)
		return func(column: Vector2i) -> float: return transition.neighbor_weight_at(column)
	assert_eq(GenerationFixtures.determinism_reason(factory, GenerationFixtures.columns()), "")


func test_is_seed_sensitive() -> void:
	var factory := func(hash: GenerationHash) -> Callable:
		var transition := BiomeTransition.for_world(hash)
		return func(column: Vector2i) -> String: return transition.neighbor_at(column)
	assert_eq(GenerationFixtures.seed_sensitivity_reason(factory, GenerationFixtures.columns()),
			"")


func test_the_weight_stays_in_range() -> void:
	var transition := _transition_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> float: return transition.neighbor_weight_at(column)
	assert_eq(GenerationFixtures.range_reason(sampler, GenerationFixtures.columns(), 0.0, 0.5), "")


func test_signature_is_pinned() -> void:
	var transition := _transition_for(GenerationFixtures.WORLD_TYPED)
	var sampler := func(column: Vector2i) -> float: return transition.neighbor_weight_at(column)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.columns()),
			PINNED_WEIGHT_SIGNATURE)
