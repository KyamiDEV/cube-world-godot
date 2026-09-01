extends TestCase
## Covers world/terrain/voxel_terrain_builder.gd (bricks 039-042, 048, 050, 052-054).

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
	assert_null(terrain.stream, "048: stream defaults to null when the caller passes none")
	assert_null(terrain.material_override,
			"041: a terrain-wide override would replace every per-block atlas material")
	assert_true(terrain.generate_collisions)
	assert_eq(terrain.max_view_distance, VoxelTerrainBuilder.DEFAULT_VIEW_DISTANCE,
			"042: never silently clamps a baseline VoxelViewer below what it requests")
	assert_eq(terrain.bounds, WorldBounds.aabb(),
			"050: the project's own authoritative extent, not the engine's unbounded default")
	assert_eq(terrain.mesh_block_size, VoxelTerrainBuilder.DEFAULT_MESH_BLOCK_SIZE,
			"052: build() applies the project default mesh block size")
	assert_eq(VoxelTerrainBuilder.DEFAULT_MESH_BLOCK_SIZE, 16,
			"054: fixed at 16 as a deliberate measured decision (ADR 0002), not 32")


func test_rejects_an_invalid_mesh_block_size() -> void:
	var registry := _registry_with_stone()
	assert_null(VoxelTerrainBuilder.build(registry, null, 8))
	assert_null(VoxelTerrainBuilder.build(registry, null, 64))


func test_builds_with_an_explicit_mesh_block_size_of_32() -> void:
	var registry := _registry_with_stone()
	var terrain := track_node(VoxelTerrainBuilder.build(registry, null, 32))

	assert_not_null(terrain)
	assert_eq(terrain.mesh_block_size, 32)


func test_builds_with_a_stream_when_one_is_passed() -> void:
	var registry := _registry_with_stone()
	var db_path := "user://test_voxel_terrain_builder_stream.sqlite"
	_temp_paths.append(db_path)
	var stream := VoxelStreamBuilder.build(db_path)

	var terrain := track_node(VoxelTerrainBuilder.build(registry, stream))

	assert_eq(terrain.stream, stream, "048: a passed-in stream is wired through unchanged")


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
