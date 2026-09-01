extends TestCase
## Covers world/generation/generation_grid.gd (brick 058).
##
## Most of these assertions are about negative coordinates. Truncating integer division
## is right for half the world and wrong for the other half, and the wrongness is
## invisible until a player walks west of the origin.


# ---------------------------------------------------------------------------
# The constants agree with each other
# ---------------------------------------------------------------------------

func test_region_size_is_consistent_in_both_units() -> void:
	assert_eq(GenerationGrid.REGION_SIZE_CHUNKS * GenerationGrid.CHUNK_SIZE_VOXELS,
			GenerationGrid.REGION_SIZE_VOXELS,
			"a region measured in chunks and in voxels is the same region")


func test_the_region_grid_covers_exactly_the_world_bounds() -> void:
	# The derivation REGION_SIZE_VOXELS was chosen for: a change to either the world
	# extent or the region size must be a deliberate one, not a silent re-shape of the
	# macro-placement grid.
	var world_width := WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS * 2
	assert_eq(GenerationGrid.REGIONS_PER_AXIS * GenerationGrid.REGION_SIZE_VOXELS,
			world_width)
	assert_eq(GenerationGrid.HALF_REGIONS_PER_AXIS * 2, GenerationGrid.REGIONS_PER_AXIS)


func test_chunk_size_matches_the_voxel_data_block_size() -> void:
	# Voxel Tools hands a generator one 16-cube data block at a time. A generation grid
	# of any other size would straddle block boundaries on every fill.
	assert_eq(GenerationGrid.CHUNK_SIZE_VOXELS, 16)


# ---------------------------------------------------------------------------
# Integer floor arithmetic
# ---------------------------------------------------------------------------

func test_floor_div_rounds_towards_negative_infinity() -> void:
	assert_eq(GenerationGrid.floor_div(0, 16), 0)
	assert_eq(GenerationGrid.floor_div(15, 16), 0)
	assert_eq(GenerationGrid.floor_div(16, 16), 1)
	# The case plain `/` gets wrong: -1 / 16 is 0 in GDScript.
	assert_eq(GenerationGrid.floor_div(-1, 16), -1)
	assert_eq(GenerationGrid.floor_div(-16, 16), -1)
	assert_eq(GenerationGrid.floor_div(-17, 16), -2)


func test_floor_div_is_exact_beyond_double_precision() -> void:
	# An `int(floor(float(a) / b))` implementation would round here; this one must not.
	var huge := (1 << 55) + 1
	assert_eq(GenerationGrid.floor_div(huge, 1), huge)
	assert_eq(GenerationGrid.floor_div(huge * 16 + 15, 16), huge)
	assert_eq(GenerationGrid.floor_div(-huge * 16 - 1, 16), -huge - 1)


func test_floor_mod_is_never_negative() -> void:
	assert_eq(GenerationGrid.floor_mod(0, 16), 0)
	assert_eq(GenerationGrid.floor_mod(17, 16), 1)
	assert_eq(GenerationGrid.floor_mod(-1, 16), 15)
	assert_eq(GenerationGrid.floor_mod(-16, 16), 0)


func test_div_and_mod_reconstruct_the_original_coordinate() -> void:
	for value in [-1025, -257, -16, -1, 0, 1, 15, 16, 4097]:
		var cell := GenerationGrid.floor_div(value, GenerationGrid.CHUNK_SIZE_VOXELS)
		var local := GenerationGrid.floor_mod(value, GenerationGrid.CHUNK_SIZE_VOXELS)
		assert_eq(cell * GenerationGrid.CHUNK_SIZE_VOXELS + local, value,
				"cell origin plus local offset is the coordinate itself (%d)" % value)


# ---------------------------------------------------------------------------
# Voxel <-> chunk
# ---------------------------------------------------------------------------

func test_voxel_to_chunk_is_symmetric_around_the_origin() -> void:
	assert_eq(GenerationGrid.voxel_to_chunk(Vector3i(0, 0, 0)), Vector3i(0, 0, 0))
	assert_eq(GenerationGrid.voxel_to_chunk(Vector3i(15, 15, 15)), Vector3i(0, 0, 0))
	assert_eq(GenerationGrid.voxel_to_chunk(Vector3i(16, 16, 16)), Vector3i(1, 1, 1))
	# Voxel -1 belongs to chunk -1, not chunk 0. Truncation gets this wrong on every axis
	# at once, which is how it hides: the world stays plausible, just doubled at x = 0.
	assert_eq(GenerationGrid.voxel_to_chunk(Vector3i(-1, -1, -1)), Vector3i(-1, -1, -1))
	assert_eq(GenerationGrid.voxel_to_chunk(Vector3i(-16, -16, -16)), Vector3i(-1, -1, -1))
	assert_eq(GenerationGrid.voxel_to_chunk(Vector3i(-17, -17, -17)), Vector3i(-2, -2, -2))


func test_no_two_neighbouring_voxels_share_a_chunk_across_the_origin() -> void:
	assert_ne(GenerationGrid.voxel_to_chunk(Vector3i(-1, 0, 0)),
			GenerationGrid.voxel_to_chunk(Vector3i(0, 0, 0)),
			"the cells either side of x = 0 are in different chunks")


func test_chunk_origin_and_local_position_round_trip() -> void:
	for voxel in [Vector3i(0, 0, 0), Vector3i(-1, -1, -1), Vector3i(37, -4, 1000),
			Vector3i(-1025, 2047, -16)]:
		var chunk := GenerationGrid.voxel_to_chunk(voxel)
		var local := GenerationGrid.voxel_in_chunk(voxel)
		assert_eq(GenerationGrid.chunk_origin(chunk) + local, voxel,
				"chunk origin plus local offset is the voxel (%s)" % voxel)


func test_local_position_stays_inside_the_chunk() -> void:
	for voxel in [Vector3i(-1, -1, -1), Vector3i(-16, -17, -33), Vector3i(15, 16, 17)]:
		var local := GenerationGrid.voxel_in_chunk(voxel)
		for axis in [local.x, local.y, local.z]:
			assert_in_range(float(axis), 0.0, float(GenerationGrid.CHUNK_SIZE_VOXELS - 1),
					"local axis of %s is inside the chunk" % voxel)


# ---------------------------------------------------------------------------
# Columns
# ---------------------------------------------------------------------------

func test_a_column_drops_y_rather_than_zeroing_it() -> void:
	assert_eq(GenerationGrid.voxel_to_column(Vector3i(3, 99, 4)), Vector2i(3, 4))
	assert_eq(GenerationGrid.voxel_to_column(Vector3i(3, -99, 4)), Vector2i(3, 4),
			"every voxel in a column shares the column, whatever its height")


func test_chunk_column_conversions_agree_with_the_three_dimensional_ones() -> void:
	var voxel := Vector3i(-33, 500, 17)
	var chunk := GenerationGrid.voxel_to_chunk(voxel)
	assert_eq(GenerationGrid.chunk_to_chunk_column(chunk),
			GenerationGrid.column_to_chunk_column(GenerationGrid.voxel_to_column(voxel)),
			"a voxel's chunk column is the same whichever route reaches it")


func test_chunk_column_origin_and_local_position_round_trip() -> void:
	for column in [Vector2i(0, 0), Vector2i(-1, -1), Vector2i(37, -1000)]:
		var chunk_column := GenerationGrid.column_to_chunk_column(column)
		assert_eq(GenerationGrid.chunk_column_origin(chunk_column)
				+ GenerationGrid.column_in_chunk_column(column), column)


# ---------------------------------------------------------------------------
# Regions
# ---------------------------------------------------------------------------

func test_region_conversions_agree_whichever_space_they_start_from() -> void:
	var voxel := Vector3i(-1025, -300, 3000)
	var region := GenerationGrid.voxel_to_region(voxel)
	assert_eq(region, Vector2i(-2, 2))
	assert_eq(GenerationGrid.column_to_region(GenerationGrid.voxel_to_column(voxel)), region)
	assert_eq(GenerationGrid.chunk_to_region(GenerationGrid.voxel_to_chunk(voxel)), region,
			"dividing by chunks then regions lands where dividing by voxels does")


func test_region_origin_and_local_position_round_trip() -> void:
	for column in [Vector2i(0, 0), Vector2i(-1, -1), Vector2i(-1025, 3000)]:
		var region := GenerationGrid.column_to_region(column)
		assert_eq(GenerationGrid.region_origin(region)
				+ GenerationGrid.column_in_region(column), column)


func test_the_region_grid_is_signed_and_centred_on_the_origin() -> void:
	# Unlike the reference's 0..1023 grid (region-coordinate-hashing.md claim 1), ours has
	# no corner to count from.
	assert_true(GenerationGrid.is_region_in_world(Vector2i(0, 0)))
	assert_true(GenerationGrid.is_region_in_world(Vector2i(-512, -512)))
	assert_true(GenerationGrid.is_region_in_world(Vector2i(511, 511)))
	assert_false(GenerationGrid.is_region_in_world(Vector2i(512, 0)))
	assert_false(GenerationGrid.is_region_in_world(Vector2i(0, -513)))


func test_every_voxel_inside_the_world_has_a_region_except_the_maximum_face() -> void:
	var half := WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS
	assert_true(GenerationGrid.is_region_in_world(
			GenerationGrid.voxel_to_region(Vector3i(-half, 0, -half))))
	assert_true(GenerationGrid.is_region_in_world(
			GenerationGrid.voxel_to_region(Vector3i(half - 1, 0, half - 1))))
	# The documented half-open boundary: AABB.has_point() includes the maximum face, the
	# region grid does not.
	assert_true(WorldBounds.contains(Vector3i(half, 0, 0)))
	assert_false(GenerationGrid.is_region_in_world(
			GenerationGrid.voxel_to_region(Vector3i(half, 0, 0))))
