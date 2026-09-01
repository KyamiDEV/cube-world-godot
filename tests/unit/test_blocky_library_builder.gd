extends TestCase
## Covers world/terrain/blocky_library_builder.gd (brick 037).

var _temp_paths: PackedStringArray = []


func after_each() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		for path in _temp_paths:
			dir.remove(path.trim_prefix("user://"))
	_temp_paths.clear()


func _write_texture(name: String, color: Color, size: Vector2i = Vector2i(2, 2)) -> String:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var path := "user://%s.png" % name
	image.save_png(path)
	_temp_paths.append(path)
	return path


func _block(id: String, top: Color, side: Color, bottom: Color,
		size: Vector2i = Vector2i(2, 2)) -> BlockDefinition:
	var definition := BlockDefinition.new()
	definition.id = id
	definition.display_name = id
	definition.texture_top = _write_texture(id + "_top", top, size)
	definition.texture_side = _write_texture(id + "_side", side, size)
	definition.texture_bottom = _write_texture(id + "_bottom", bottom, size)
	definition.footstep_tag = "stone"
	return definition


func _uniform_block(id: String, color: Color = Color.WHITE) -> BlockDefinition:
	return _block(id, color, color, color)


# ---------------------------------------------------------------------------

func test_rejects_an_unlocked_registry() -> void:
	var registry := BlockRegistry.new()
	registry.register_block(_uniform_block("block.stone"))
	assert_null(BlockyLibraryBuilder.build(registry))


func test_air_is_the_only_model_for_an_empty_registry() -> void:
	var registry := BlockRegistry.new()
	registry.lock()
	var library := BlockyLibraryBuilder.build(registry)
	assert_not_null(library)
	assert_eq(library.get_models().size(), 1)
	assert_true(library.get_model(0) is VoxelBlockyModelEmpty)


func test_model_indices_are_network_index_plus_one() -> void:
	var registry := BlockRegistry.new()
	registry.register_block(_uniform_block("block.stone"))
	registry.register_block(_uniform_block("block.dirt"))
	registry.lock()
	var library := BlockyLibraryBuilder.build(registry)

	assert_eq(registry.network_index("block.dirt"), 0, "block.dirt sorts first")
	assert_eq(registry.network_index("block.stone"), 1)
	assert_eq(library.get_models().size(), 3, "air + 2 blocks")
	assert_eq(library.get_model(1).resource_name, "block.dirt")
	assert_eq(library.get_model(2).resource_name, "block.stone")


func test_solid_opaque_block_has_collision_and_culls_neighbors() -> void:
	var registry := BlockRegistry.new()
	var stone := _uniform_block("block.stone")
	stone.is_solid = true
	stone.transparent = false
	registry.register_block(stone)
	registry.lock()
	var model: VoxelBlockyModel = BlockyLibraryBuilder.build(registry).get_model(1)

	assert_true(model.culls_neighbors)
	assert_eq(model.collision_mask, 1)
	assert_eq(model.collision_aabbs.size(), 1)


func test_non_solid_transparent_block_has_no_collision_and_never_culls() -> void:
	var registry := BlockRegistry.new()
	var leaves := _uniform_block("block.leaves")
	leaves.is_solid = false
	leaves.transparent = true
	registry.register_block(leaves)
	registry.lock()
	var model: VoxelBlockyModel = BlockyLibraryBuilder.build(registry).get_model(1)

	assert_false(model.culls_neighbors)
	assert_eq(model.collision_mask, 0)
	assert_eq(model.collision_aabbs.size(), 0)


func test_atlas_packs_distinct_top_side_bottom_textures() -> void:
	# 8-bit-exact colors: a PNG round trip quantizes float color to 8 bits per
	# channel, so an arbitrary float like 0.5 would not compare equal after
	# save/load. Color8's byte values survive that round trip exactly.
	var top_color := Color8(0, 255, 0)
	var side_color := Color8(128, 64, 0)
	var bottom_color := Color8(76, 38, 0)
	var registry := BlockRegistry.new()
	var grass := _block("block.grass", top_color, side_color, bottom_color)
	registry.register_block(grass)
	registry.lock()
	var model: VoxelBlockyModelCube = BlockyLibraryBuilder.build(registry).get_model(1)

	var material: StandardMaterial3D = model.get_material_override(0)
	assert_not_null(material)
	var atlas: Image = material.albedo_texture.get_image()
	assert_eq(atlas.get_size(), Vector2i(6, 2), "3 tiles of 2x2 side by side")
	assert_eq(atlas.get_pixel(0, 0), top_color, "top tile")
	assert_eq(atlas.get_pixel(2, 0), side_color, "side tile")
	assert_eq(atlas.get_pixel(4, 0), bottom_color, "bottom tile")


func test_missing_texture_degrades_that_block_to_empty_without_failing_the_build() -> void:
	var registry := BlockRegistry.new()
	var broken := _uniform_block("block.broken")
	broken.texture_top = "res://does_not_exist.png"
	registry.register_block(broken)
	registry.register_block(_uniform_block("block.stone"))
	registry.lock()
	var library := BlockyLibraryBuilder.build(registry)

	assert_not_null(library)
	assert_eq(library.get_models().size(), 3)
	# "block.broken" < "block.stone" lexicographically -> index 1.
	assert_true(library.get_model(1) is VoxelBlockyModelEmpty)
	assert_eq(library.get_model(2).resource_name, "block.stone")


func test_mismatched_face_sizes_degrade_to_empty() -> void:
	var registry := BlockRegistry.new()
	var odd := _block("block.odd", Color.WHITE, Color.WHITE, Color.WHITE)
	odd.texture_top = _write_texture("block.odd_top_big", Color.WHITE, Vector2i(4, 4))
	registry.register_block(odd)
	registry.lock()
	var library := BlockyLibraryBuilder.build(registry)

	assert_true(library.get_model(1) is VoxelBlockyModelEmpty)
