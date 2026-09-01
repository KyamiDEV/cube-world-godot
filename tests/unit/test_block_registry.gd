extends TestCase
## Covers world/terrain/block_registry.gd (brick 032).


func _grass() -> BlockDefinition:
	var definition := BlockDefinition.new()
	definition.id = "block.grass"
	definition.display_name = "Grass"
	definition.texture_top = "res://assets/textures/blocks/grass_top.png"
	definition.texture_side = "res://assets/textures/blocks/grass_side.png"
	definition.texture_bottom = "res://assets/textures/blocks/dirt.png"
	definition.footstep_tag = "grass"
	return definition


func _dirt() -> BlockDefinition:
	var definition := BlockDefinition.new()
	definition.id = "block.dirt"
	definition.display_name = "Dirt"
	definition.texture_top = "res://assets/textures/blocks/dirt.png"
	definition.texture_side = "res://assets/textures/blocks/dirt.png"
	definition.texture_bottom = "res://assets/textures/blocks/dirt.png"
	definition.footstep_tag = "dirt"
	return definition


func test_registers_a_valid_definition() -> void:
	var registry := BlockRegistry.new()
	var grass := _grass()
	assert_true(registry.register_block(grass))
	assert_eq(registry.get_block("block.grass"), grass)
	assert_eq(registry.size(), 1)


func test_rejects_a_definition_that_fails_its_own_validation() -> void:
	# The wrapped DefinitionRegistry only checks the id, which is well-formed here — the
	# rejection must come from BlockDefinition.validate() itself (missing display_name).
	var registry := BlockRegistry.new()
	var definition := BlockDefinition.new()
	definition.id = "block.grass"
	assert_false(registry.register_block(definition))
	assert_eq(registry.size(), 0)
	assert_null(registry.get_block("block.grass"))


func test_rejects_a_definition_from_another_domain() -> void:
	var registry := BlockRegistry.new()
	var definition := BlockDefinition.new()
	definition.id = "item.sword.iron"
	definition.display_name = "Iron Sword"
	assert_false(registry.register_block(definition))


func test_rejects_a_duplicate_id() -> void:
	var registry := BlockRegistry.new()
	assert_true(registry.register_block(_grass()))
	assert_false(registry.register_block(_grass()))
	assert_eq(registry.size(), 1)


func test_lock_assigns_network_indices_in_sorted_order() -> void:
	var registry := BlockRegistry.new()
	registry.register_block(_grass())
	registry.register_block(_dirt())
	assert_true(registry.lock())
	assert_true(registry.is_locked())
	# "block.dirt" < "block.grass" lexicographically.
	assert_eq(registry.network_index("block.dirt"), 0)
	assert_eq(registry.network_index("block.grass"), 1)
	assert_eq(registry.id_from_network_index(0), "block.dirt")
	assert_eq(registry.id_from_network_index(1), "block.grass")
	assert_eq(registry.id_from_network_index(2), "",
			"an out-of-range index must not resolve to anything")


func test_registering_after_lock_is_refused() -> void:
	var registry := BlockRegistry.new()
	registry.register_block(_grass())
	registry.lock()
	assert_false(registry.register_block(_dirt()))
	assert_eq(registry.size(), 1)


func test_alias_resolves_to_the_current_id() -> void:
	var registry := BlockRegistry.new()
	var grass := _grass()
	registry.register_block(grass)
	assert_true(registry.add_alias("block.turf", "block.grass"))
	assert_true(registry.lock())
	assert_eq(registry.resolve("block.turf"), "block.grass")
	assert_eq(registry.get_block("block.turf"), grass)
	assert_true(registry.has_block("block.turf"))


func test_ids_and_ids_under_are_sorted() -> void:
	var registry := BlockRegistry.new()
	registry.register_block(_grass())
	registry.register_block(_dirt())
	assert_eq(registry.ids(), PackedStringArray(["block.dirt", "block.grass"]))
	assert_eq(registry.ids_under("block"), PackedStringArray(["block.dirt", "block.grass"]))


func test_content_hash_is_stable_across_equivalent_registries() -> void:
	var a := BlockRegistry.new()
	var b := BlockRegistry.new()
	a.register_block(_grass())
	a.register_block(_dirt())
	b.register_block(_dirt())
	b.register_block(_grass())
	a.lock()
	b.lock()
	assert_eq(a.content_hash(), b.content_hash(),
			"content hash must not depend on registration order")


func test_clear_empties_and_unlocks() -> void:
	var registry := BlockRegistry.new()
	registry.register_block(_grass())
	registry.lock()
	registry.clear()
	assert_false(registry.is_locked())
	assert_eq(registry.size(), 0)
	assert_true(registry.register_block(_dirt()))
