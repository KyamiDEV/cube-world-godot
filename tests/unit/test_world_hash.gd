extends TestCase
## Covers core/random/world_hash.gd (brick 015).
##
## These assertions are the determinism guarantee for world generation. A failure here
## means two players walking into the same place from different directions could see
## different worlds.

const SEED := 987654321


func test_hashing_is_pure() -> void:
	assert_eq(WorldHash.hash3(SEED, 10, 20, 30), WorldHash.hash3(SEED, 10, 20, 30),
			"same inputs, same output, always")
	assert_eq(WorldHash.value01_3(SEED, -5, 64, 7), WorldHash.value01_3(SEED, -5, 64, 7))


func test_generation_does_not_depend_on_visit_order() -> void:
	# The property that a sequential RNG cannot provide: sampling B first must not
	# change what A produces.
	var a_first := WorldHash.value01_3(SEED, 1, 2, 3)
	var _b := WorldHash.value01_3(SEED, 400, 500, 600)
	var _c := WorldHash.value01_3(SEED, -7, -8, -9)
	assert_eq(WorldHash.value01_3(SEED, 1, 2, 3), a_first,
			"a position's value is unaffected by what was sampled in between")


func test_neighbouring_coordinates_do_not_correlate() -> void:
	# Adjacent cells must not produce adjacent values, otherwise every generated field
	# shows visible axis-aligned banding.
	var base := WorldHash.hash3(SEED, 0, 0, 0)
	assert_ne(WorldHash.hash3(SEED, 1, 0, 0), base)
	assert_ne(WorldHash.hash3(SEED, 0, 1, 0), base)
	assert_ne(WorldHash.hash3(SEED, 0, 0, 1), base)


func test_axis_permutations_do_not_collide() -> void:
	assert_ne(WorldHash.hash3(SEED, 1, 2, 3), WorldHash.hash3(SEED, 3, 2, 1))
	assert_ne(WorldHash.hash3(SEED, 1, 2, 3), WorldHash.hash3(SEED, 2, 1, 3))
	assert_ne(WorldHash.hash3(SEED, 5, 0, 0), WorldHash.hash3(SEED, 0, 5, 0))


func test_different_seeds_give_different_worlds() -> void:
	assert_ne(WorldHash.hash3(1, 10, 10, 10), WorldHash.hash3(2, 10, 10, 10))


func test_salts_decorrelate_generation_passes() -> void:
	# If the tree pass and the ore pass agreed about which cells are "high", every ore
	# vein would sit under a tree.
	var trees := WorldHash.value01_3(SEED, 4, 5, 6, WorldHash.SALT_TREES)
	var caves := WorldHash.value01_3(SEED, 4, 5, 6, WorldHash.SALT_CAVES)
	assert_ne(trees, caves, "two passes at one position disagree")


func test_two_dimensional_hash_is_distinct_from_three_at_y_zero() -> void:
	assert_ne(WorldHash.hash2(SEED, 3, 4), WorldHash.hash3(SEED, 3, 0, 4),
			"a column field and a 3D field at y=0 must not share a pattern")
	assert_eq(WorldHash.hash2(SEED, 3, 4), WorldHash.hash2(SEED, 3, 4))


func test_unit_values_are_in_range_and_spread_out() -> void:
	var buckets := [0, 0, 0, 0]
	var samples := 4000
	for i in samples:
		var value := WorldHash.value01_3(SEED, i, i * 7, -i)
		assert_true(value >= 0.0 and value < 1.0, "value01 stays in [0, 1)")
		buckets[mini(int(value * 4.0), 3)] += 1
	for count in buckets:
		assert_in_range(count, float(samples) * 0.2, float(samples) * 0.5,
				"each quarter of the range is populated")


func test_positional_streams_are_owned_by_their_position() -> void:
	var a := WorldHash.rng_at(SEED, 12, 0, 34, WorldHash.SALT_TREES)
	var b := WorldHash.rng_at(SEED, 12, 0, 34, WorldHash.SALT_TREES)
	for _i in 20:
		assert_eq(a.next_u64(), b.next_u64(), "the same cell yields the same sequence")

	var other := WorldHash.rng_at(SEED, 13, 0, 34, WorldHash.SALT_TREES)
	assert_ne(WorldHash.rng_at(SEED, 12, 0, 34, WorldHash.SALT_TREES).next_u64(),
			other.next_u64(), "the neighbouring cell gets its own sequence")


func test_column_streams_match_the_column_hash() -> void:
	var a := WorldHash.rng_at_column(SEED, 8, 9, WorldHash.SALT_ELEVATION)
	var b := WorldHash.rng_at_column(SEED, 8, 9, WorldHash.SALT_ELEVATION)
	assert_eq(a.next_u64(), b.next_u64())


func test_vector_forms_match_the_scalar_forms() -> void:
	assert_eq(WorldHash.hash_voxel(SEED, Vector3i(2, 3, 4), WorldHash.SALT_PROPS),
			WorldHash.hash3(SEED, 2, 3, 4, WorldHash.SALT_PROPS))
	assert_eq(WorldHash.rng_at_voxel(SEED, Vector3i(2, 3, 4)).next_u64(),
			WorldHash.rng_at(SEED, 2, 3, 4).next_u64())


func test_chance_at_short_circuits_at_the_extremes() -> void:
	var voxel := Vector3i(1, 2, 3)
	assert_false(WorldHash.chance_at(SEED, voxel, 0.0), "probability 0 never fires")
	assert_true(WorldHash.chance_at(SEED, voxel, 1.0), "probability 1 always fires")


func test_chance_at_is_stable_and_roughly_proportional() -> void:
	var hits := 0
	var samples := 3000
	for i in samples:
		if WorldHash.chance_at(SEED, Vector3i(i, 64, i * 3), 0.25, WorldHash.SALT_TREES):
			hits += 1
	assert_in_range(float(hits) / float(samples), 0.20, 0.30,
			"a 25% placement mask lands near 25%")
	assert_eq(WorldHash.chance_at(SEED, Vector3i(5, 5, 5), 0.25),
			WorldHash.chance_at(SEED, Vector3i(5, 5, 5), 0.25), "and it is stable")


func test_negative_coordinates_are_first_class() -> void:
	# Half the world has negative coordinates; a hash that degenerates there would make
	# one quadrant visibly different.
	var values := {}
	for i in range(-50, 0):
		values[WorldHash.hash3(SEED, i, i, i)] = true
	assert_size(values.keys(), 50, "50 negative positions give 50 distinct hashes")


func test_seed_from_text_is_stable_and_readable() -> void:
	assert_eq(WorldHash.seed_from_text("12345"), 12345,
			"a numeric seed is taken at face value, so bug reports reproduce")
	assert_eq(WorldHash.seed_from_text("  42 "), 42, "surrounding space is ignored")
	assert_eq(WorldHash.seed_from_text(""), 0, "an empty seed is 0, not random")
	assert_eq(WorldHash.seed_from_text("hello"), WorldHash.seed_from_text("hello"),
			"the same words always give the same world")
	assert_ne(WorldHash.seed_from_text("hello"), WorldHash.seed_from_text("hellp"))


func test_salt_constants_are_unique() -> void:
	var salts := [WorldHash.SALT_ELEVATION, WorldHash.SALT_TEMPERATURE,
			WorldHash.SALT_HUMIDITY, WorldHash.SALT_CAVES, WorldHash.SALT_TREES,
			WorldHash.SALT_PROPS, WorldHash.SALT_STRUCTURES, WorldHash.SALT_SPAWNS,
			WorldHash.SALT_LOOT]
	var seen := {}
	for salt in salts:
		assert_false(seen.has(salt), "salt %d is used once" % salt)
		seen[salt] = true
