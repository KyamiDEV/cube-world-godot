extends TestCase
## Covers core/ids/stable_id.gd (brick 016).


func test_accepts_well_formed_ids() -> void:
	for id in ["item.sword.iron", "creature.goblin", "skill.dash", "biome.grassland",
			"block.stone", "quest.village_bandits_01", "loot.chest.dungeon.rare",
			"ui.inventory"]:
		assert_true(StableId.is_valid(id), "%s is valid" % id)
		assert_eq(StableId.validate(id), "", "%s reports no problem" % id)


func test_rejects_malformed_ids_with_a_usable_reason() -> void:
	# The reason matters: "invalid id" alone tells a content author nothing.
	var cases := {
		"": "empty",
		"item": "domain",
		"Item.Sword": "lower case",
		"item..sword": "empty segment",
		"item.sword.": "empty segment",
		"item.2handed": "[a-z]",
		"item.sword iron": "[a-z]",
		"item.sword-iron": "[a-z]",
		"weapon.sword": "unknown domain",
		"item.a.b.c.d.e": "maximum",
	}
	for id in cases:
		assert_false(StableId.is_valid(id), "'%s' is rejected" % id)
		assert_has(StableId.validate(id), cases[id],
				"'%s' explains itself (%s)" % [id, StableId.validate(id)])


func test_every_domain_is_usable() -> void:
	for domain in StableId.DOMAINS:
		assert_true(StableId.is_valid(domain + ".thing"), "%s is a working domain" % domain)


func test_parses_the_parts_of_an_id() -> void:
	assert_eq(StableId.domain_of("item.sword.iron"), "item")
	assert_eq(StableId.name_of("item.sword.iron"), "sword.iron")
	assert_eq(StableId.leaf_of("item.sword.iron"), "iron")
	assert_eq(StableId.segments_of("item.sword.iron"),
			PackedStringArray(["item", "sword", "iron"]))


func test_parsing_a_malformed_id_does_not_crash() -> void:
	assert_eq(StableId.domain_of("nodots"), "", "no domain to report")
	assert_eq(StableId.name_of("nodots"), "")
	assert_eq(StableId.leaf_of("nodots"), "nodots")


func test_prefix_matching_is_segment_aware() -> void:
	assert_true(StableId.is_under("item.sword.iron", "item.sword"))
	assert_true(StableId.is_under("item.sword.iron", "item"))
	assert_true(StableId.is_under("item.sword", "item.sword"), "an id is under itself")
	assert_false(StableId.is_under("item.swordfish", "item.sword"),
			"a shared text prefix is not a shared segment prefix")
	assert_false(StableId.is_under("item.sword", "item.sword.iron"))


func test_normalise_repairs_authored_text() -> void:
	assert_eq(StableId.normalise("  Item / Sword-Iron  "), "item.sword_iron")
	assert_eq(StableId.normalise("item..sword"), "item.sword")
	assert_eq(StableId.normalise(".item.sword."), "item.sword")


func test_normalise_output_is_valid_for_reasonable_input() -> void:
	assert_true(StableId.is_valid(StableId.normalise("Creature / Goblin")))
