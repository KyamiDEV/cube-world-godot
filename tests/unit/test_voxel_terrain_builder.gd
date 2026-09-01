extends TestCase
## Covers world/terrain/voxel_terrain_builder.gd (bricks 039-040).

var _temp_paths: PackedStringArray = []


func after_each() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		for path in _temp_paths:
			dir.remove(path.trim_prefix("user://"))
	_temp_paths.clear()


func _write_texture(name: String) -> String:
	# A real, loadable 2x2 PNG — since 040, VoxelTerrainBuilder.build() also builds the
	# mesher (BlockyLibraryBuilder), which loads each face texture for real
	# (blocky_library_builder.gd's own tests use this same user:// pattern).
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var path := "user://%s.png" % name
	image.save_png(path)
	_temp_paths.append(path)
	return path


func _block(id: String) -> BlockDefinition:
	var definition := BlockDefinition.new()
	definition.id = id
	definition.display_name = id
	definition.texture_top = _write_texture(id + "_top")
	definition.texture_side = _write_texture(id + "_side")
	definition.texture_bottom = _write_texture(id + "_bottom")
	definition.footstep_tag = "stone"
	return definition


func _registry_with_stone() -> BlockRegistry:
	var registry := BlockRegistry.new()
	registry.register_block(_block("block.dirt"))
	registry.register_block(_block(VoxelTerrainBuilder.PLACEHOLDER_BLOCK_ID))
	registry.lock()
	return registry


# ---------------------------------------------------------------------------

func test_rejects_an_unlocked_registry() -> void:
	var registry := BlockRegistry.new()
	registry.register_block(_block(VoxelTerrainBuilder.PLACEHOLDER_BLOCK_ID))
	assert_null(VoxelTerrainBuilder.build(registry))


func test_rejects_a_registry_missing_the_placeholder_block() -> void:
	var registry := BlockRegistry.new()
	registry.register_block(_block("block.dirt"))
	registry.lock()
	assert_null(VoxelTerrainBuilder.build(registry))


func test_builds_a_configured_voxel_terrain() -> void:
	var registry := _registry_with_stone()
	var terrain := track_node(VoxelTerrainBuilder.build(registry))

	assert_not_null(terrain)
	assert_true(terrain is VoxelTerrain)
	assert_not_null(terrain.mesher, "040: a VoxelMesherBlocky, not left null anymore")
	assert_true(terrain.mesher is VoxelMesherBlocky)
	assert_null(terrain.stream, "no save format yet (048) — the generator covers the whole volume")
	assert_true(terrain.generate_collisions)


func test_mesher_library_matches_the_registry() -> void:
	var registry := _registry_with_stone()
	var terrain := track_node(VoxelTerrainBuilder.build(registry))

	var mesher: VoxelMesherBlocky = terrain.mesher
	var library: VoxelBlockyLibrary = mesher.library
	assert_not_null(library)
	# air (index 0) + block.dirt + block.stone, same +1 offset the generator uses.
	assert_eq(library.get_models().size(), 3)
	assert_eq(library.get_model(registry.network_index(VoxelTerrainBuilder.PLACEHOLDER_BLOCK_ID) + 1)
			.resource_name, VoxelTerrainBuilder.PLACEHOLDER_BLOCK_ID)


func test_placeholder_generator_uses_registry_network_index_plus_one() -> void:
	var registry := _registry_with_stone()
	var terrain := track_node(VoxelTerrainBuilder.build(registry))

	# "block.dirt" < "block.stone" lexicographically, so stone is network index 1.
	assert_eq(registry.network_index(VoxelTerrainBuilder.PLACEHOLDER_BLOCK_ID), 1)

	var generator: VoxelGeneratorFlat = terrain.generator
	assert_not_null(generator)
	assert_true(generator is VoxelGeneratorFlat)
	assert_eq(generator.channel, VoxelBuffer.CHANNEL_TYPE)
	assert_eq(generator.voxel_type, 2, "network index 1 + the air offset")
	assert_eq(generator.height, float(VoxelTerrainBuilder.PLACEHOLDER_GROUND_HEIGHT))
