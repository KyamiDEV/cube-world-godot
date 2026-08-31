extends TestCase
## Covers core/ids/definition_registry.gd (brick 016).

var _registry: DefinitionRegistry


func before_each() -> void:
	_registry = DefinitionRegistry.new("item")
	# The registry logs rejections as errors, which is right in production and noise
	# here: most of these tests deliberately feed it bad input.
	Log.set_channel_level(Log.CH_CORE, Log.Level.SILENT)


func after_each() -> void:
	Log.clear_channel_levels()


func _fill() -> void:
	_registry.register("item.sword.iron", {"damage": 5})
	_registry.register("item.sword.steel", {"damage": 8})
	_registry.register("item.potion.healing", {"heal": 20})


# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

func test_registers_and_returns_definitions() -> void:
	assert_true(_registry.register("item.sword.iron", {"damage": 5}))
	assert_true(_registry.has("item.sword.iron"))
	assert_eq(_registry.get_definition("item.sword.iron"), {"damage": 5})
	assert_eq(_registry.size(), 1)


func test_rejects_an_invalid_id() -> void:
	assert_false(_registry.register("Item.Sword", {}), "malformed ids do not enter")
	assert_eq(_registry.size(), 0)


func test_rejects_an_id_from_another_domain() -> void:
	# A creature in the item registry would break every index and lookup built on it.
	assert_false(_registry.register("creature.goblin", {}))
	assert_eq(_registry.size(), 0)


func test_rejects_a_duplicate_id() -> void:
	assert_true(_registry.register("item.sword.iron", {"damage": 5}))
	assert_false(_registry.register("item.sword.iron", {"damage": 999}),
			"a second registration is refused, not silently applied")
	assert_eq(_registry.get_definition("item.sword.iron"), {"damage": 5},
			"the first definition survives")


func test_unknown_ids_resolve_to_null_not_an_error_value() -> void:
	assert_null(_registry.get_definition("item.nothing"))
	assert_false(_registry.has("item.nothing"))


# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------

func test_alias_resolves_a_renamed_id() -> void:
	_fill()
	assert_true(_registry.add_alias("item.sword.plain", "item.sword.iron"))
	assert_true(_registry.has("item.sword.plain"), "an old save's id still resolves")
	assert_eq(_registry.get_definition("item.sword.plain"), {"damage": 5})
	assert_eq(_registry.resolve("item.sword.plain"), "item.sword.iron")


func test_alias_chains_resolve_and_cannot_loop() -> void:
	_fill()
	_registry.add_alias("item.sword.old", "item.sword.older")
	_registry.add_alias("item.sword.older", "item.sword.iron")
	assert_eq(_registry.resolve("item.sword.old"), "item.sword.iron", "chains follow through")

	var looping := DefinitionRegistry.new("item")
	looping.add_alias("item.a", "item.b")
	looping.add_alias("item.b", "item.a")
	# The assertion is that this returns at all rather than spinning forever.
	assert_has(["item.a", "item.b"], looping.resolve("item.a"))


func test_alias_cannot_shadow_a_live_definition() -> void:
	_fill()
	assert_false(_registry.add_alias("item.sword.iron", "item.sword.steel"),
			"a live id may not be redirected")
	assert_eq(_registry.get_definition("item.sword.iron"), {"damage": 5})


func test_a_registered_id_cannot_collide_with_an_existing_alias() -> void:
	_registry.add_alias("item.sword.plain", "item.sword.iron")
	assert_false(_registry.register("item.sword.plain", {"damage": 1}),
			"an alias name is taken")


func test_lock_reports_a_dangling_alias() -> void:
	_fill()
	_registry.add_alias("item.sword.plain", "item.sword.mythril")
	assert_false(_registry.lock(), "an alias pointing nowhere fails the lock")


func test_unknown_id_resolves_to_itself() -> void:
	assert_eq(_registry.resolve("item.unknown"), "item.unknown",
			"the caller sees the id it asked about")


# ---------------------------------------------------------------------------
# Locking
# ---------------------------------------------------------------------------

func test_locking_closes_the_registry() -> void:
	_fill()
	assert_true(_registry.lock())
	assert_true(_registry.is_locked())
	assert_false(_registry.register("item.sword.mythril", {}),
			"content cannot appear mid-session")
	assert_false(_registry.add_alias("item.x", "item.sword.iron"))
	assert_eq(_registry.size(), 3)


func test_locking_twice_is_harmless() -> void:
	_fill()
	assert_true(_registry.lock())
	assert_true(_registry.lock())


func test_clear_reopens_an_empty_registry() -> void:
	_fill()
	_registry.lock()
	_registry.clear()
	assert_eq(_registry.size(), 0)
	assert_false(_registry.is_locked())
	assert_true(_registry.register("item.sword.iron", {}))


# ---------------------------------------------------------------------------
# Iteration
# ---------------------------------------------------------------------------

func test_ids_are_sorted_not_insertion_ordered() -> void:
	# Iteration order must not depend on which file the loader read first.
	_registry.register("item.potion.healing", {})
	_registry.register("item.sword.iron", {})
	_registry.register("item.axe.stone", {})
	assert_eq(_registry.ids(),
			PackedStringArray(["item.axe.stone", "item.potion.healing", "item.sword.iron"]))


func test_ids_under_a_prefix_are_segment_aware() -> void:
	_fill()
	_registry.register("item.swordfish.raw", {})
	assert_eq(_registry.ids_under("item.sword"),
			PackedStringArray(["item.sword.iron", "item.sword.steel"]),
			"swordfish is not a sword")


# ---------------------------------------------------------------------------
# Network indices
# ---------------------------------------------------------------------------

func test_network_indices_are_unavailable_before_locking() -> void:
	_fill()
	assert_eq(_registry.network_index("item.sword.iron"), -1,
			"indices are only meaningful once the catalogue is closed")


func test_network_indices_are_dense_and_reversible() -> void:
	_fill()
	_registry.lock()
	var seen := {}
	for id in _registry.ids():
		var index := _registry.network_index(id)
		assert_in_range(index, 0, _registry.size() - 1)
		assert_false(seen.has(index), "index %d is used once" % index)
		seen[index] = true
		assert_eq(_registry.id_from_network_index(index), id, "the mapping inverts")


func test_network_indices_do_not_depend_on_registration_order() -> void:
	# Two peers that loaded the same content must agree without exchanging a table.
	var a := DefinitionRegistry.new("item")
	a.register("item.sword.iron", {})
	a.register("item.axe.stone", {})
	a.register("item.potion.healing", {})
	a.lock()

	var b := DefinitionRegistry.new("item")
	b.register("item.potion.healing", {})
	b.register("item.sword.iron", {})
	b.register("item.axe.stone", {})
	b.lock()

	for id in a.ids():
		assert_eq(a.network_index(id), b.network_index(id), "%s has the same index" % id)


func test_network_index_of_an_alias_matches_its_target() -> void:
	_fill()
	_registry.add_alias("item.sword.plain", "item.sword.iron")
	_registry.lock()
	assert_eq(_registry.network_index("item.sword.plain"),
			_registry.network_index("item.sword.iron"),
			"an old id travels as the current one")


func test_out_of_range_indices_are_rejected() -> void:
	# A packet from an incompatible peer must not index out of bounds.
	_fill()
	_registry.lock()
	assert_eq(_registry.id_from_network_index(-1), "")
	assert_eq(_registry.id_from_network_index(999), "")


func test_content_hash_detects_a_mismatch_between_peers() -> void:
	var a := DefinitionRegistry.new("item")
	a.register("item.sword.iron", {})
	a.register("item.axe.stone", {})
	a.lock()

	var same := DefinitionRegistry.new("item")
	same.register("item.axe.stone", {})
	same.register("item.sword.iron", {})
	same.lock()
	assert_eq(a.content_hash(), same.content_hash(),
			"same content in a different order agrees")

	var extra := DefinitionRegistry.new("item")
	extra.register("item.sword.iron", {})
	extra.register("item.axe.stone", {})
	extra.register("item.potion.healing", {})
	extra.lock()
	assert_ne(a.content_hash(), extra.content_hash(), "extra content is detected")


func test_content_hash_distinguishes_domains() -> void:
	var items := DefinitionRegistry.new("item")
	items.register("item.sword.iron", {})
	items.lock()

	var blocks := DefinitionRegistry.new("block")
	blocks.register("block.sword", {})  # same leaf, different domain
	blocks.lock()
	assert_ne(items.content_hash(), blocks.content_hash())
