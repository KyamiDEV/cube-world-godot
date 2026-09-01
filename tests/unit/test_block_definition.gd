extends TestCase
## Covers world/terrain/block_definition.gd (brick 031).


func _valid() -> BlockDefinition:
	var definition := BlockDefinition.new()
	definition.id = "block.grass"
	definition.display_name = "Grass"
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


func test_registers_into_a_block_registry() -> void:
	# End-to-end with DefinitionRegistry (brick 016) — the registry only checks the id,
	# so a valid-but-unvalidated-by-the-registry definition still needs its own check.
	var registry := DefinitionRegistry.new("block")
	var definition := _valid()
	assert_true(definition.is_valid())
	assert_true(registry.register(definition.id, definition))
	assert_eq(registry.get_definition("block.grass"), definition)
