extends TestCase
## Covers world/biomes/biome_registry.gd (brick 067).


func _definition(id: String, color: Color = Color8(10, 20, 30)) -> BiomeDefinition:
	var definition := BiomeDefinition.new()
	definition.id = id
	definition.display_name = StableId.leaf_of(id).capitalize()
	definition.debug_color = color
	definition.surface_block_id = "block.grass"
	definition.subsurface_block_id = "block.dirt"
	return definition


## A registry holding every classifier id, each with a colour far enough from the others.
func _complete() -> BiomeRegistry:
	var registry := BiomeRegistry.new()
	var step := 0
	for id in BiomeClassifier.IDS:
		# 0.283 apart between neighbours, comfortably clear of the 0.25 minimum.
		registry.register_biome(_definition(id, Color(step * 0.2, 1.0 - step * 0.2, 0.0)))
		step += 1
	return registry


# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

func test_registering_a_biome_makes_it_retrievable_and_typed() -> void:
	var registry := BiomeRegistry.new()
	assert_true(registry.register_biome(_definition(BiomeClassifier.FOREST)))
	assert_eq(registry.size(), 1)
	assert_true(registry.has_biome(BiomeClassifier.FOREST))
	var found := registry.get_biome(BiomeClassifier.FOREST)
	assert_not_null(found)
	assert_true(found is BiomeDefinition)
	assert_eq(found.id, BiomeClassifier.FOREST)


func test_an_invalid_definition_is_refused() -> void:
	var registry := BiomeRegistry.new()
	var definition := _definition(BiomeClassifier.FOREST)
	definition.display_name = ""
	assert_false(registry.register_biome(definition))
	assert_eq(registry.size(), 0)


func test_an_id_nothing_can_classify_is_refused() -> void:
	# The closed set is the classifier's. A record for a biome no column can ever be in is
	# dead content, and it is caught here rather than at the first lookup that misses.
	var registry := BiomeRegistry.new()
	assert_false(BiomeClassifier.is_biome_id("biome.coast"))
	assert_false(registry.register_biome(_definition("biome.coast")))
	assert_eq(registry.size(), 0)


func test_a_duplicate_id_is_refused() -> void:
	var registry := BiomeRegistry.new()
	assert_true(registry.register_biome(_definition(BiomeClassifier.DESERT)))
	assert_false(registry.register_biome(_definition(BiomeClassifier.DESERT)))
	assert_eq(registry.size(), 1)


func test_registering_after_lock_is_refused() -> void:
	var registry := BiomeRegistry.new()
	registry.lock()
	assert_true(registry.is_locked())
	assert_false(registry.register_biome(_definition(BiomeClassifier.SNOW)))


func test_an_alias_keeps_an_old_id_resolving() -> void:
	# Same reason `DefinitionRegistry` has aliases at all: a renamed biome still appears in
	# saves written before the rename.
	var registry := BiomeRegistry.new()
	registry.register_biome(_definition(BiomeClassifier.WETLAND))
	assert_true(registry.add_alias("biome.swamp", BiomeClassifier.WETLAND))
	assert_true(registry.lock())
	assert_eq(registry.resolve("biome.swamp"), BiomeClassifier.WETLAND)
	assert_eq(registry.get_biome("biome.swamp").id, BiomeClassifier.WETLAND)


# ---------------------------------------------------------------------------
# Coverage
# ---------------------------------------------------------------------------

func test_an_empty_registry_reports_every_missing_biome() -> void:
	var registry := BiomeRegistry.new()
	var reason := registry.coverage_reason()
	assert_ne(reason, "")
	for id in BiomeClassifier.IDS:
		assert_true(reason.contains(id), "%s must be named as missing: %s" % [id, reason])


func test_a_partial_registry_names_only_what_is_missing() -> void:
	var registry := BiomeRegistry.new()
	registry.register_biome(_definition(BiomeClassifier.GRASSLAND))
	var reason := registry.coverage_reason()
	assert_ne(reason, "")
	assert_false(reason.contains(BiomeClassifier.GRASSLAND), reason)
	assert_true(reason.contains(BiomeClassifier.FOREST), reason)


func test_a_complete_registry_covers_the_classifier() -> void:
	assert_eq(_complete().coverage_reason(), "")


func test_coverage_reports_an_id_nothing_can_classify() -> void:
	# The direction a live registry cannot reach, because `register_biome()` refuses it —
	# checked through the static form so the branch is actually exercised.
	var present := PackedStringArray(BiomeClassifier.IDS)
	present.append("biome.coast")
	var reason := BiomeRegistry.coverage_reason_for(present)
	assert_ne(reason, "")
	assert_true(reason.contains("biome.coast"), reason)


func test_coverage_of_exactly_the_classifier_ids_is_clean() -> void:
	assert_eq(BiomeRegistry.coverage_reason_for(BiomeClassifier.IDS), "")


func test_coverage_does_not_depend_on_order() -> void:
	var reversed_ids: PackedStringArray = []
	for i in range(BiomeClassifier.IDS.size() - 1, -1, -1):
		reversed_ids.append(BiomeClassifier.IDS[i])
	assert_eq(BiomeRegistry.coverage_reason_for(reversed_ids), "")


# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------

func test_two_biomes_sharing_a_debug_color_are_reported() -> void:
	var registry := BiomeRegistry.new()
	registry.register_biome(_definition(BiomeClassifier.FOREST, Color(0.2, 0.4, 0.2)))
	registry.register_biome(_definition(BiomeClassifier.WETLAND, Color(0.2, 0.4, 0.2)))
	var reason := registry.palette_reason()
	assert_ne(reason, "")
	assert_true(reason.contains(BiomeClassifier.FOREST), reason)
	assert_true(reason.contains(BiomeClassifier.WETLAND), reason)


func test_colors_just_far_enough_apart_are_accepted() -> void:
	var registry := BiomeRegistry.new()
	var apart := BiomeRegistry.MINIMUM_DEBUG_COLOR_DISTANCE + 0.01
	registry.register_biome(_definition(BiomeClassifier.FOREST, Color(0.0, 0.0, 0.0)))
	registry.register_biome(_definition(BiomeClassifier.WETLAND, Color(apart, 0.0, 0.0)))
	assert_eq(registry.palette_reason(), "")


func test_the_palette_check_is_order_independent() -> void:
	# `ids()` is sorted, so the pair reported for a clash does not depend on which of the
	# two was registered first — a load-order-dependent error message is a bad error.
	var first := BiomeRegistry.new()
	first.register_biome(_definition(BiomeClassifier.FOREST, Color(0.2, 0.4, 0.2)))
	first.register_biome(_definition(BiomeClassifier.WETLAND, Color(0.2, 0.4, 0.2)))
	var second := BiomeRegistry.new()
	second.register_biome(_definition(BiomeClassifier.WETLAND, Color(0.2, 0.4, 0.2)))
	second.register_biome(_definition(BiomeClassifier.FOREST, Color(0.2, 0.4, 0.2)))
	assert_eq(first.palette_reason(), second.palette_reason())


func test_color_distance_is_euclidean_and_ignores_alpha() -> void:
	assert_almost_eq(BiomeRegistry.color_distance(Color(0, 0, 0), Color(1, 0, 0)), 1.0)
	assert_almost_eq(BiomeRegistry.color_distance(Color(0, 0, 0), Color(0.6, 0.8, 0.0)), 1.0)
	assert_almost_eq(BiomeRegistry.color_distance(
			Color(0.1, 0.2, 0.3, 1.0), Color(0.1, 0.2, 0.3, 0.0)), 0.0)


# ---------------------------------------------------------------------------
# Self check
# ---------------------------------------------------------------------------

func test_self_check_passes_on_a_complete_distinct_catalog() -> void:
	assert_eq(_complete().self_check(), "")


func test_self_check_reports_coverage_before_palette() -> void:
	# Coverage first on purpose: a missing biome is the failure that breaks a world, and a
	# palette clash among the two that did load is noise on top of it.
	var registry := BiomeRegistry.new()
	registry.register_biome(_definition(BiomeClassifier.FOREST, Color(0.2, 0.4, 0.2)))
	registry.register_biome(_definition(BiomeClassifier.WETLAND, Color(0.2, 0.4, 0.2)))
	assert_eq(registry.self_check(), registry.coverage_reason())


# ---------------------------------------------------------------------------
# Network indices
# ---------------------------------------------------------------------------

func test_network_indices_round_trip_after_lock() -> void:
	var registry := _complete()
	assert_true(registry.lock())
	for id in registry.ids():
		var index := registry.network_index(id)
		assert_true(index >= 0, "%s has no index" % id)
		assert_eq(registry.id_from_network_index(index), id)


func test_network_indices_do_not_depend_on_registration_order() -> void:
	# `DefinitionRegistry` assigns them in sorted id order precisely so two processes that
	# loaded the same six files agree without exchanging a table.
	var forward := BiomeRegistry.new()
	for id in BiomeClassifier.IDS:
		forward.register_biome(_definition(id))
	forward.lock()

	var backward := BiomeRegistry.new()
	for i in range(BiomeClassifier.IDS.size() - 1, -1, -1):
		backward.register_biome(_definition(BiomeClassifier.IDS[i]))
	backward.lock()

	for id in BiomeClassifier.IDS:
		assert_eq(backward.network_index(id), forward.network_index(id))
	assert_eq(backward.content_hash(), forward.content_hash())


func test_an_out_of_range_network_index_yields_an_empty_id() -> void:
	var registry := _complete()
	registry.lock()
	assert_eq(registry.id_from_network_index(-1), "")
	assert_eq(registry.id_from_network_index(registry.size()), "")
