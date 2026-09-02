extends TestCase
## Covers world/biomes/biome_catalog.gd and the six records in `data/biomes/` (brick 067).


func test_load_default_returns_a_locked_registry_holding_every_biome() -> void:
	var registry := BiomeCatalog.load_default()
	assert_true(registry.is_locked())
	assert_eq(registry.size(), BiomeClassifier.IDS.size())
	for id in BiomeClassifier.IDS:
		assert_true(registry.has_biome(id), "%s has no record" % id)


func test_the_shipped_catalog_passes_its_own_self_check() -> void:
	# The whole point of the brick in one assertion: the catalog covers exactly the closed
	# set the classifier can answer with, and no two biomes look alike on a debug map.
	assert_eq(BiomeCatalog.load_default().self_check(), "")


func test_every_shipped_record_is_individually_valid() -> void:
	var registry := BiomeCatalog.load_default()
	for id in registry.ids():
		var definition := registry.get_biome(id)
		assert_eq(definition.validate(), "", "%s must validate" % id)
		assert_eq(definition.id, id, "%s is filed under the wrong id" % id)
		assert_false(definition.display_name.is_empty(), "%s has no display name" % id)


func test_display_names_are_distinct() -> void:
	# Not a key — but two biomes sharing a label make every UI and log line ambiguous.
	var registry := BiomeCatalog.load_default()
	var seen: Dictionary = {}
	for id in registry.ids():
		var name := registry.get_biome(id).display_name
		assert_false(seen.has(name), "'%s' is used by both %s and %s" % [name, seen.get(name, ""), id])
		seen[name] = id


func test_the_debug_palette_keeps_a_real_margin() -> void:
	# `palette_reason()` only asserts the threshold; this records how much room the shipped
	# palette actually has, so a future recolour that scrapes past the check is visible.
	var registry := BiomeCatalog.load_default()
	var ids := registry.ids()
	var closest := 2.0
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			closest = minf(closest, BiomeRegistry.color_distance(
					registry.get_biome(ids[i]).debug_color,
					registry.get_biome(ids[j]).debug_color))
	assert_true(closest >= BiomeRegistry.MINIMUM_DEBUG_COLOR_DISTANCE,
			"closest pair is %s apart" % closest)
	assert_in_range(closest, 0.27, 0.30)


func test_every_classified_column_resolves_to_a_record() -> void:
	# Closes the loop end to end, the way `test_block_set` does for the blocky library:
	# run the real classifier over the fixture columns of every fixture world and look each
	# answer up in the real catalog. This is the failure the whole coverage check exists to
	# prevent, asserted against actual classifications rather than against the id list.
	var registry := BiomeCatalog.load_default()
	var columns := GenerationFixtures.columns()
	var answered: Dictionary = {}
	for name in GenerationFixtures.world_names():
		var world_hash := GenerationFixtures.hash_for(name)
		assert_not_null(world_hash, "%s must build" % name)
		var biomes := BiomeClassifier.for_world(world_hash)
		assert_not_null(biomes, "%s must classify" % name)
		for column in columns:
			var id := biomes.at(column)
			assert_true(registry.has_biome(id),
					"%s at %s classified as %s, which the catalog has no record for" % [
							name, column, id])
			answered[id] = true
	assert_true(answered.size() >= 2,
			"the fixture columns must exercise more than one biome (saw %d)" % answered.size())


func test_the_file_name_of_a_record_is_its_name_segment() -> void:
	assert_eq(BiomeCatalog.file_name_for(BiomeClassifier.GRASSLAND), "grassland.tres")
	assert_eq(BiomeCatalog.file_name_for(BiomeClassifier.WETLAND), "wetland.tres")


func test_every_record_lives_where_file_name_for_says() -> void:
	# The generator writes through `file_name_for()` and this reads through it, so the two
	# cannot drift; what is asserted here is that the files are actually on disk under
	# those names rather than found by a directory scan that would accept any name.
	for id in BiomeClassifier.IDS:
		var path := BiomeCatalog.DEFAULT_DIR.path_join(BiomeCatalog.file_name_for(id))
		assert_true(ResourceLoader.exists(path), "%s is missing" % path)
		var definition: Resource = ResourceLoader.load(path)
		assert_true(definition is BiomeDefinition, "%s is not a BiomeDefinition" % path)
		assert_eq((definition as BiomeDefinition).id, id)


func test_a_missing_directory_returns_an_empty_locked_registry() -> void:
	# Same degrade contract as `BlockSet`: the load never crashes. Verification is off
	# because the catalog being empty is the case under test, not a regression to report.
	var registry := BiomeCatalog.load_default("res://does_not_exist/", false)
	assert_true(registry.is_locked())
	assert_eq(registry.size(), 0)
	assert_ne(registry.coverage_reason(), "")


func test_network_indices_are_assigned_and_reversible() -> void:
	# A biome id reaches the wire as an index (`docs/ids-and-registries.md`), and the
	# catalog is locked at load, so the mapping exists from the moment it is loaded.
	var registry := BiomeCatalog.load_default()
	for id in BiomeClassifier.IDS:
		var index := registry.network_index(id)
		assert_true(index >= 0, "%s has no network index" % id)
		assert_eq(registry.id_from_network_index(index), id)
	assert_eq(registry.id_from_network_index(BiomeClassifier.IDS.size()), "")


# ---------------------------------------------------------------------------
# vegetation_density (brick 087)
# ---------------------------------------------------------------------------

func test_the_three_bare_biomes_ship_zero_vegetation_density() -> void:
	# Desert, snow and mountain must read as bare — `TreeMask.spacing_at()`'s own
	# short-circuit depends on this being exactly zero, not merely small.
	var registry := BiomeCatalog.load_default()
	for id in [BiomeClassifier.DESERT, BiomeClassifier.SNOW, BiomeClassifier.MOUNTAIN]:
		assert_eq(registry.get_biome(id).vegetation_density, 0.0, "%s must be bare" % id)


func test_vegetation_density_orders_forest_above_wetland_above_grassland() -> void:
	# The property the whole field exists for: a forest reads visibly denser than a wetland,
	# a wetland denser than open grassland — `biome_catalog_generator.gd`'s own stated intent,
	# checked here rather than only claimed in a comment.
	var registry := BiomeCatalog.load_default()
	var forest := registry.get_biome(BiomeClassifier.FOREST).vegetation_density
	var wetland := registry.get_biome(BiomeClassifier.WETLAND).vegetation_density
	var grassland := registry.get_biome(BiomeClassifier.GRASSLAND).vegetation_density
	assert_true(forest > wetland, "forest (%s) must be denser than wetland (%s)" % [forest, wetland])
	assert_true(wetland > grassland,
			"wetland (%s) must be denser than grassland (%s)" % [wetland, grassland])
	assert_true(grassland > 0.0, "grassland must still grow some trees")


func test_loading_twice_gives_the_same_content_hash() -> void:
	# Two peers loading the same six files must agree on their indices without exchanging
	# a table; within one process this is the cheapest check that the load is not
	# order-dependent.
	assert_eq(BiomeCatalog.load_default().content_hash(),
			BiomeCatalog.load_default().content_hash())
