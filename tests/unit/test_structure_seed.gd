extends TestCase
## `world/structures/structure_seed.gd` — the per-region structure seed record (brick 089).
##
## `test_structure_seed_field.gd` covers how these are selected. This file covers only the
## record's own behaviour: the owned stream, the invariant `validate()` guards, and that
## the three fields are held as handed in.


func _seed(region := Vector2i(3, -5), anchor := Vector2i(3 * 1024 + 10, -5 * 1024 + 20),
		value := 123456789) -> StructureSeed:
	return StructureSeed.new(region, anchor, value)


func test_holds_its_fields() -> void:
	var s := _seed()
	assert_eq(s.region, Vector2i(3, -5))
	assert_eq(s.anchor_column, Vector2i(3 * 1024 + 10, -5 * 1024 + 20))
	assert_eq(s.structure_seed, 123456789)


func test_rng_is_reproducible_and_owned() -> void:
	var s := _seed()
	var a := s.rng()
	var b := s.rng()
	# Two fresh streams from the same record produce the same sequence...
	for i in 8:
		assert_eq(a.next_u64(), b.next_u64(), "draw %d" % i)
	# ...and the record does not keep a stream of its own that a caller could exhaust.
	var c := s.rng()
	assert_eq(c.next_u64(), s.rng().next_u64())


func test_two_different_seeds_give_different_streams() -> void:
	var first := _seed(Vector2i(0, 0), Vector2i(1, 1), 1).rng().next_u64()
	var second := _seed(Vector2i(0, 0), Vector2i(1, 1), 2).rng().next_u64()
	assert_ne(first, second)


func test_validate_accepts_an_anchor_inside_its_region() -> void:
	assert_eq(_seed().validate(), "")
	# Region origin and the far corner of the region both count as inside.
	assert_eq(_seed(Vector2i(0, 0), Vector2i(0, 0)).validate(), "")
	assert_eq(_seed(Vector2i(0, 0), Vector2i(1023, 1023)).validate(), "")


func test_validate_rejects_an_anchor_in_the_wrong_region() -> void:
	var strayed := _seed(Vector2i(0, 0), Vector2i(1024, 0))  # first column of region (1, 0)
	assert_ne(strayed.validate(), "")


func test_validate_rejects_a_region_outside_the_grid() -> void:
	var region := Vector2i(GenerationGrid.HALF_REGIONS_PER_AXIS, 0)
	assert_false(GenerationGrid.is_region_in_world(region))
	assert_ne(StructureSeed.new(region, GenerationGrid.region_origin(region), 0).validate(), "")


func test_to_string_names_the_region_and_anchor() -> void:
	var text := str(_seed(Vector2i(3, -5), Vector2i(7, 8), 42))
	assert_true(text.contains("3") and text.contains("-5") and text.contains("42"), text)
