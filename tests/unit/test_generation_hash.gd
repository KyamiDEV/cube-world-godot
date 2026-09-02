extends TestCase
## Covers world/generation/generation_hash.gd (brick 058).
##
## `test_world_hash.gd` already proves the primitive is pure, order-free and
## seed-sensitive. What is tested here is the generation layer's own three additions: the
## world binding, the version refusal, and the space tag that keeps two coordinate grids
## carrying the same numbers from being the same place.

const SEED_VALUE := 987654321

var _hash: GenerationHash


func before_each() -> void:
	_hash = GenerationHash.for_world(WorldSeed.from_value(SEED_VALUE))


# ---------------------------------------------------------------------------
# Binding to a world
# ---------------------------------------------------------------------------

func test_for_world_binds_to_the_seed_it_was_given() -> void:
	assert_not_null(_hash)
	assert_eq(_hash.seed_value(), SEED_VALUE)
	assert_eq(_hash.world_seed.generation_version, GenerationVersion.CURRENT)


func test_two_bindings_to_the_same_world_agree() -> void:
	# The property everything downstream rests on: a server and a client that built their
	# own binding from the same seed generate the same world.
	var other := GenerationHash.for_world(WorldSeed.from_value(SEED_VALUE))
	assert_eq(other.value01_column(Vector2i(12, -34), WorldHash.SALT_ELEVATION),
			_hash.value01_column(Vector2i(12, -34), WorldHash.SALT_ELEVATION))


func test_different_seeds_are_different_worlds() -> void:
	var other := GenerationHash.for_world(WorldSeed.from_value(SEED_VALUE + 1))
	assert_ne(other.value01_column(Vector2i(12, -34), WorldHash.SALT_ELEVATION),
			_hash.value01_column(Vector2i(12, -34), WorldHash.SALT_ELEVATION))


func test_a_world_this_build_cannot_reproduce_is_refused() -> void:
	# A retired or future algorithm must not be generated approximately. The refusal
	# names the version, so the failure is a bug report rather than a deleted save.
	var future := WorldSeed.new(SEED_VALUE, "", GenerationVersion.CURRENT + 1)
	var reason := GenerationHash.refuse_reason(future)
	assert_ne(reason, "")
	assert_has(reason, str(GenerationVersion.CURRENT + 1))
	assert_null(GenerationHash.for_world(future))


func test_an_incoherent_seed_configuration_is_refused() -> void:
	# WorldSeed.validate()'s round-trip rule, enforced at the point the seed becomes
	# numbers: text that no longer hashes to its own value would mean the seed a player
	# is shown creates a different world than the one they are looking at.
	var drifted := WorldSeed.new(SEED_VALUE, "not-the-text-this-came-from")
	assert_ne(GenerationHash.refuse_reason(drifted), "")
	assert_null(GenerationHash.for_world(drifted))


func test_no_seed_configuration_is_refused_rather_than_crashing() -> void:
	assert_ne(GenerationHash.refuse_reason(null), "")
	assert_null(GenerationHash.for_world(null))


func test_a_current_world_is_accepted() -> void:
	assert_eq(GenerationHash.refuse_reason(WorldSeed.from_text("cube")), "")


# ---------------------------------------------------------------------------
# The space tag
# ---------------------------------------------------------------------------

func test_the_same_numbers_in_different_spaces_are_different_places() -> void:
	# The reason the tag exists: chunk (3, 0, 5) and voxel (3, 0, 5) are not the same
	# place, and a per-chunk pass sharing a salt with a per-voxel pass must not agree
	# cell for cell with it.
	var salt := WorldHash.SALT_STRUCTURES
	assert_ne(_hash.hash_voxel(Vector3i(3, 0, 5), salt),
			_hash.hash_chunk(Vector3i(3, 0, 5), salt))
	assert_ne(_hash.hash_column(Vector2i(3, 5), salt),
			_hash.hash_chunk_column(Vector2i(3, 5), salt))
	assert_ne(_hash.hash_column(Vector2i(3, 5), salt),
			_hash.hash_region(Vector2i(3, 5), salt))
	assert_ne(_hash.hash_chunk_column(Vector2i(3, 5), salt),
			_hash.hash_region(Vector2i(3, 5), salt))


func test_every_space_pair_is_distinct_at_the_origin() -> void:
	# The origin is where a weak tag would collapse: every coordinate term is zero, so
	# only the tag separates the spaces.
	var seen: Array[int] = []
	for space in [GenerationHash.Space.VOXEL, GenerationHash.Space.CHUNK]:
		seen.append(_hash.hash3_in(space, 0, 0, 0))
	for space in [GenerationHash.Space.COLUMN, GenerationHash.Space.CHUNK_COLUMN,
			GenerationHash.Space.REGION, GenerationHash.Space.DECORATION_CELL]:
		seen.append(_hash.hash2_in(space, 0, 0))
	var unique := {}
	for value in seen:
		unique[value] = true
	assert_size(unique, seen.size(), "each space hashes the origin to its own value")


func test_voxel_space_is_a_pass_through_to_the_primitive() -> void:
	# Space.VOXEL is 0 so the tagging costs the base case nothing — and so that a world
	# generated through this layer matches one generated through WorldHash directly.
	assert_eq(GenerationHash.salt_in(GenerationHash.Space.VOXEL, WorldHash.SALT_CAVES),
			WorldHash.SALT_CAVES)
	assert_eq(_hash.hash_voxel(Vector3i(7, -8, 9), WorldHash.SALT_CAVES),
			WorldHash.hash3(SEED_VALUE, 7, -8, 9, WorldHash.SALT_CAVES))


func test_no_declared_salt_can_reach_into_the_next_space() -> void:
	# The mechanical guard on `space * SPACE_SALT_STRIDE + salt`: a salt as large as the
	# stride would land in the next space's block and silently un-tag two grids. Checked
	# over the whole constant list so adding a salt in WorldHash cannot skip the check.
	var constants: Dictionary = load("res://core/random/world_hash.gd").get_script_constant_map()
	var checked := 0
	for key in constants:
		if not str(key).begins_with("SALT_"):
			continue
		var salt: int = constants[key]
		checked += 1
		assert_in_range(float(salt), 0.0, float(GenerationHash.SPACE_SALT_STRIDE - 1),
				"%s fits inside one space's salt block" % key)
	assert_true(checked >= 9, "found the declared salts (found %d)" % checked)


func test_salts_still_decorrelate_passes_inside_one_space() -> void:
	var column := Vector2i(4, 6)
	assert_ne(_hash.value01_column(column, WorldHash.SALT_TEMPERATURE),
			_hash.value01_column(column, WorldHash.SALT_HUMIDITY),
			"two fields at one column disagree")


# ---------------------------------------------------------------------------
# Determinism
# ---------------------------------------------------------------------------

func test_sampling_is_free_of_visit_order() -> void:
	var first := _hash.value01_chunk(Vector3i(1, 2, 3), WorldHash.SALT_STRUCTURES)
	var _elsewhere := _hash.value01_chunk(Vector3i(-40, 5, 600), WorldHash.SALT_STRUCTURES)
	var _again := _hash.value01_voxel(Vector3i(1, 2, 3))
	assert_eq(_hash.value01_chunk(Vector3i(1, 2, 3), WorldHash.SALT_STRUCTURES), first,
			"a coordinate's value is unaffected by what was sampled in between")


func test_unit_values_stay_in_range() -> void:
	for i in range(64):
		assert_in_range(_hash.value01_voxel(Vector3i(i, -i, i * 7)), 0.0, 0.999999999)
		assert_in_range(_hash.value01_region(Vector2i(-i, i)), 0.0, 0.999999999)


func test_negative_coordinates_are_ordinary() -> void:
	# Half the world is negative; nothing may special-case it.
	assert_ne(_hash.value01_column(Vector2i(-7, -9)), _hash.value01_column(Vector2i(7, 9)))
	assert_eq(_hash.value01_column(Vector2i(-7, -9)), _hash.value01_column(Vector2i(-7, -9)))


# ---------------------------------------------------------------------------
# Placement masks
# ---------------------------------------------------------------------------

func test_a_disabled_mask_costs_nothing_and_never_fires() -> void:
	assert_false(_hash.chance_voxel(Vector3i(1, 2, 3), 0.0, WorldHash.SALT_TREES))
	assert_true(_hash.chance_voxel(Vector3i(1, 2, 3), 1.0, WorldHash.SALT_TREES))
	assert_false(_hash.chance_column(Vector2i(1, 2), -1.0))
	assert_true(_hash.chance_region(Vector2i(1, 2), 2.0))


func test_a_mask_fires_at_roughly_its_probability() -> void:
	# Not a distribution proof — a smoke test that the mask is neither always-on nor
	# always-off, which is how a broken salt or a stuck hash actually presents.
	var hits := 0
	for x in range(100):
		for z in range(100):
			if _hash.chance_column(Vector2i(x - 50, z - 50), 0.25, WorldHash.SALT_TREES):
				hits += 1
	assert_in_range(float(hits) / 10000.0, 0.20, 0.30,
			"a 25%% mask fires near a quarter of the time (%d / 10000)" % hits)


func test_a_mask_agrees_with_its_own_unit_value() -> void:
	var voxel := Vector3i(11, 12, 13)
	var sample := _hash.value01_voxel(voxel, WorldHash.SALT_PROPS)
	assert_eq(_hash.chance_voxel(voxel, sample + 0.001, WorldHash.SALT_PROPS), true)
	assert_eq(_hash.chance_voxel(voxel, sample, WorldHash.SALT_PROPS), false,
			"the threshold is exclusive, matching DeterministicRng.next_bool()")


# ---------------------------------------------------------------------------
# Position-owned streams
# ---------------------------------------------------------------------------

func test_a_positions_stream_is_owned_by_that_position() -> void:
	var a := _hash.rng_region(Vector2i(2, -3), WorldHash.SALT_STRUCTURES)
	var drawn := [a.next_int(0, 999), a.next_int(0, 999), a.next_int(0, 999)]

	# Draw a different number of values from a neighbour first: a shared stream would
	# shift, a position-owned one cannot.
	var neighbour := _hash.rng_region(Vector2i(3, -3), WorldHash.SALT_STRUCTURES)
	neighbour.next_int(0, 999)

	var again := _hash.rng_region(Vector2i(2, -3), WorldHash.SALT_STRUCTURES)
	assert_eq([again.next_int(0, 999), again.next_int(0, 999), again.next_int(0, 999)],
			drawn)


func test_a_decoration_cells_stream_is_owned_by_that_cell() -> void:
	var a := _hash.rng_decoration_cell(Vector2i(2, -3), WorldHash.SALT_TREES)
	var drawn := [a.next_int(0, 999), a.next_int(0, 999)]

	var neighbour := _hash.rng_decoration_cell(Vector2i(3, -3), WorldHash.SALT_TREES)
	neighbour.next_int(0, 999)

	var again := _hash.rng_decoration_cell(Vector2i(2, -3), WorldHash.SALT_TREES)
	assert_eq([again.next_int(0, 999), again.next_int(0, 999)], drawn)


func test_streams_at_different_spaces_and_salts_are_independent() -> void:
	var by_chunk := _hash.rng_chunk(Vector3i(1, 0, 1), WorldHash.SALT_STRUCTURES)
	var by_voxel := _hash.rng_voxel(Vector3i(1, 0, 1), WorldHash.SALT_STRUCTURES)
	var by_column := _hash.rng_column(Vector2i(1, 1), WorldHash.SALT_STRUCTURES)
	var other_salt := _hash.rng_chunk(Vector3i(1, 0, 1), WorldHash.SALT_SPAWNS)
	var first: Array[int] = [by_chunk.next_int(0, 1 << 30), by_voxel.next_int(0, 1 << 30),
			by_column.next_int(0, 1 << 30), other_salt.next_int(0, 1 << 30)]
	var unique := {}
	for value in first:
		unique[value] = true
	assert_size(unique, first.size(), "four streams, four different first draws")
