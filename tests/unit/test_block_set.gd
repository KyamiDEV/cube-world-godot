extends TestCase
## Covers world/terrain/block_set.gd (brick 038).


func test_load_default_returns_a_locked_registry_with_grass_dirt_stone() -> void:
	var registry := BlockSet.load_default()
	assert_true(registry.is_locked())
	assert_eq(registry.size(), 3)
	assert_true(registry.has_block("block.grass"))
	assert_true(registry.has_block("block.dirt"))
	assert_true(registry.has_block("block.stone"))


func test_default_blocks_have_matching_footstep_tags() -> void:
	var registry := BlockSet.load_default()
	assert_eq(registry.get_block("block.grass").footstep_tag, "grass")
	assert_eq(registry.get_block("block.dirt").footstep_tag, "dirt")
	assert_eq(registry.get_block("block.stone").footstep_tag, "stone")


func test_default_blocks_are_each_individually_valid() -> void:
	var registry := BlockSet.load_default()
	for id in registry.ids():
		assert_true(registry.get_block(id).is_valid(), "%s must validate" % id)


func test_default_set_builds_a_real_blocky_library_with_no_placeholders() -> void:
	# Closes the loop end to end: the real texture assets this brick authored must
	# actually load, not just the synthetic PNGs blocky_library_builder's own tests
	# generate at runtime.
	var registry := BlockSet.load_default()
	var library := BlockyLibraryBuilder.build(registry)
	assert_not_null(library)
	assert_eq(library.get_models().size(), 4, "air + grass + dirt + stone")
	for i in range(1, library.get_models().size()):
		assert_false(library.get_model(i) is VoxelBlockyModelEmpty,
				"model %d degraded to a placeholder" % i)


func test_missing_directory_returns_an_empty_locked_registry() -> void:
	var registry := BlockSet.load_default("res://does_not_exist/")
	assert_true(registry.is_locked())
	assert_eq(registry.size(), 0)
