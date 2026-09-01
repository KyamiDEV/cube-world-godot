extends TestCase
## Covers world/terrain/block_definition.gd (brick 031).


func _valid() -> BlockDefinition:
	var definition := BlockDefinition.new()
	definition.id = "block.grass"
	definition.display_name = "Grass"
	definition.texture_top = "res://assets/textures/blocks/grass_top.png"
	definition.texture_side = "res://assets/textures/blocks/grass_side.png"
	definition.texture_bottom = "res://assets/textures/blocks/dirt.png"
	definition.footstep_tag = "grass"
	return definition


func test_a_well_formed_definition_is_valid() -> void:
	var definition := _valid()
	assert_eq(definition.validate(), "")
	assert_true(definition.is_valid())


func test_default_definition_is_invalid() -> void:
	var definition := BlockDefinition.new()
	assert_ne(definition.validate(), "")
	assert_false(definition.is_valid())


func test_rejects_a_malformed_id() -> void:
	var definition := _valid()
	definition.id = "Block.Grass"
	assert_ne(definition.validate(), "", "malformed ids are rejected")
	assert_eq(definition.validate(), StableId.validate("Block.Grass"),
			"the reason matches StableId's own, not a reworded copy")


func test_rejects_an_id_from_another_domain() -> void:
	var definition := _valid()
	definition.id = "item.sword.iron"
	assert_ne(definition.validate(), "")
	assert_false(definition.is_valid())


func test_rejects_a_missing_display_name() -> void:
	var definition := _valid()
	definition.display_name = ""
	assert_eq(definition.validate(), "display_name is empty")


func test_rejects_a_missing_texture_top() -> void:
	var definition := _valid()
	definition.texture_top = ""
	assert_eq(definition.validate(), "texture_top is empty")


func test_rejects_a_missing_texture_side() -> void:
	var definition := _valid()
	definition.texture_side = ""
	assert_eq(definition.validate(), "texture_side is empty")


func test_rejects_a_missing_texture_bottom() -> void:
	var definition := _valid()
	definition.texture_bottom = ""
	assert_eq(definition.validate(), "texture_bottom is empty")


func test_transparent_defaults_to_false() -> void:
	var definition := _valid()
	assert_false(definition.transparent, "VoxelBlockyModel's own default is opaque")


func test_is_solid_defaults_to_true() -> void:
	var definition := _valid()
	assert_true(definition.is_solid, "most reference blocks are walkable/solid")


func test_is_solid_can_be_set_false_and_stays_valid() -> void:
	var definition := _valid()
	definition.is_solid = false
	assert_true(definition.is_valid(), "collision is engine-integration, not a validity rule")


func test_destructible_defaults_to_true() -> void:
	var definition := _valid()
	assert_true(definition.destructible, "most reference blocks are minable")


func test_destructible_can_be_set_false_and_stays_valid() -> void:
	var definition := _valid()
	definition.destructible = false
	assert_true(definition.is_valid(), "permanence is engine-integration, not a validity rule")


func test_hardness_defaults_to_one() -> void:
	var definition := _valid()
	assert_eq(definition.hardness, 1.0)


func test_rejects_zero_hardness() -> void:
	var definition := _valid()
	definition.hardness = 0.0
	assert_eq(definition.validate(), "hardness must be greater than 0")


func test_rejects_negative_hardness() -> void:
	var definition := _valid()
	definition.hardness = -1.0
	assert_eq(definition.validate(), "hardness must be greater than 0")


func test_drop_item_id_defaults_to_empty_and_stays_valid() -> void:
	var definition := _valid()
	assert_eq(definition.drop_item_id, "")
	assert_true(definition.is_valid(), "empty drop_item_id means no drop")


func test_accepts_a_well_formed_drop_item_id() -> void:
	var definition := _valid()
	definition.drop_item_id = "item.dirt"
	assert_true(definition.is_valid())


func test_rejects_a_malformed_drop_item_id() -> void:
	var definition := _valid()
	definition.drop_item_id = "Item.Dirt"
	assert_ne(definition.validate(), "")
	assert_true(definition.validate().begins_with("drop_item_id: "),
			"the reason is prefixed so it's clear which field failed")


func test_rejects_a_drop_item_id_from_another_domain() -> void:
	var definition := _valid()
	definition.drop_item_id = "block.dirt"
	assert_eq(definition.validate(),
			"drop_item_id must be in the 'item' domain, got 'block.dirt'")


func test_rejects_a_missing_footstep_tag() -> void:
	var definition := _valid()
	definition.footstep_tag = ""
	assert_eq(definition.validate(), "footstep_tag is empty")


func test_registers_into_a_block_registry() -> void:
	# End-to-end with DefinitionRegistry (brick 016) — the registry only checks the id,
	# so a valid-but-unvalidated-by-the-registry definition still needs its own check.
	var registry := DefinitionRegistry.new("block")
	var definition := _valid()
	assert_true(definition.is_valid())
	assert_true(registry.register(definition.id, definition))
	assert_eq(registry.get_definition("block.grass"), definition)
