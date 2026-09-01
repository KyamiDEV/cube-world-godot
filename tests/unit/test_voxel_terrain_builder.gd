extends TestCase
## Covers world/terrain/voxel_terrain_builder.gd (brick 039).

func _block(id: String) -> BlockDefinition:
	var definition := BlockDefinition.new()
	definition.id = id
	definition.display_name = id
	definition.texture_top = "res://dummy_top.png"
	definition.texture_side = "res://dummy_side.png"
	definition.texture_bottom = "res://dummy_bottom.png"
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
	assert_null(terrain.mesher, "mesher is 040's responsibility, not this brick's")
	assert_null(terrain.stream, "no save format yet (048) — the generator covers the whole volume")
	assert_true(terrain.generate_collisions)


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
