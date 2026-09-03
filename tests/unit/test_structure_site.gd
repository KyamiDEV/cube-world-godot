extends TestCase
## `world/structures/structure_site.gd` — the resolved-structure record (brick 091).
##
## A pure value object, so this file is about its geometry and its invariants only; how a site
## is *derived* from a placed candidate is `test_structure_generator.gd`'s.


const REGION := Vector2i(1, -2)


func _site(half_extent := 5, wall_height := 6, base_y := 24) -> StructureSite:
	var anchor := GenerationGrid.region_origin(REGION) + Vector2i(300, 700)
	return StructureSite.new(REGION, anchor, base_y, half_extent, wall_height, 0x1234ABCD)


# ---------------------------------------------------------------------------
# The footprint
# ---------------------------------------------------------------------------

func test_the_footprint_is_a_centred_odd_square() -> void:
	for half_extent in [1, 4, 8]:
		var site := _site(half_extent)
		assert_eq(site.footprint_side_voxels(), 2 * half_extent + 1, "half extent %d" % half_extent)
		assert_eq(site.footprint_side_voxels() % 2, 1, "side is odd (half extent %d)" % half_extent)
		assert_eq(site.footprint_min(), site.anchor_column - Vector2i(half_extent, half_extent))
		assert_eq(site.footprint_max(), site.anchor_column + Vector2i(half_extent, half_extent))
		assert_eq(site.footprint_max() - site.footprint_min(),
				Vector2i(site.footprint_side_voxels() - 1, site.footprint_side_voxels() - 1))


func test_distance_is_chebyshev_not_euclidean() -> void:
	var site := _site()
	var anchor := site.anchor_column
	assert_eq(site.distance_to_column(anchor), 0)
	assert_eq(site.distance_to_column(anchor + Vector2i(3, 0)), 3)
	assert_eq(site.distance_to_column(anchor + Vector2i(0, -3)), 3)
	# The corner of the square is at the same distance as the edge — the whole point of the
	# metric: the unit ball is the square the structure is actually made of.
	assert_eq(site.distance_to_column(anchor + Vector2i(3, 3)), 3)
	assert_eq(site.distance_to_column(anchor + Vector2i(-3, 2)), 3)


func test_contains_column_matches_the_footprint_box() -> void:
	var site := _site(4)
	var anchor := site.anchor_column
	for dx in range(-6, 7):
		for dz in range(-6, 7):
			var column := anchor + Vector2i(dx, dz)
			var inside := maxi(absi(dx), absi(dz)) <= 4
			assert_eq(site.contains_column(column), inside, "offset (%d, %d)" % [dx, dz])


func test_the_wall_ring_is_exactly_the_outermost_band() -> void:
	var site := _site(4)
	var anchor := site.anchor_column
	var wall_columns := 0
	for dx in range(-4, 5):
		for dz in range(-4, 5):
			var column := anchor + Vector2i(dx, dz)
			var on_ring := maxi(absi(dx), absi(dz)) == 4
			assert_eq(site.is_wall_column(column), on_ring, "offset (%d, %d)" % [dx, dz])
			if on_ring:
				wall_columns += 1
				assert_true(site.contains_column(column), "the ring is inside the footprint")
	# A ring of a 9x9 square: 9² − 7² = 32.
	assert_eq(wall_columns, 32)


func test_top_y_is_the_floor_plus_the_wall_height() -> void:
	var site := _site(5, 6, 24)
	assert_eq(site.top_y(), 30)


func test_metres_go_through_world_scale() -> void:
	var site := _site(4)
	assert_almost_eq(site.footprint_side_metres(),
			WorldScale.voxels_to_metres(float(site.footprint_side_voxels())))


# ---------------------------------------------------------------------------
# Streams
# ---------------------------------------------------------------------------

func test_rng_matches_the_seed_records_own_stream() -> void:
	# The site carries the sub-seed rather than a live stream precisely so that this holds:
	# a consumer holding either record forks the same parent.
	var site := _site()
	var seed_record := StructureSeed.new(REGION, site.anchor_column, site.structure_seed)
	assert_eq(site.rng().next_u64(), seed_record.rng().next_u64())
	assert_eq(site.rng().derive_named("x").next_u64(),
			seed_record.rng().derive_named("x").next_u64())


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

func test_a_coherent_record_validates() -> void:
	assert_eq(_site().validate(), "")


func test_validate_rejects_an_out_of_grid_region() -> void:
	var far := Vector2i(GenerationGrid.HALF_REGIONS_PER_AXIS, 0)
	var site := StructureSite.new(far, GenerationGrid.region_origin(far), 0, 4, 5, 1)
	assert_ne(site.validate(), "")


func test_validate_rejects_an_anchor_outside_its_region() -> void:
	var site := StructureSite.new(REGION, GenerationGrid.region_origin(REGION + Vector2i(1, 0)),
			0, 4, 5, 1)
	assert_ne(site.validate(), "")


func test_validate_rejects_non_positive_extents() -> void:
	assert_ne(_site(0, 5).validate(), "")
	assert_ne(_site(4, 0).validate(), "")


func test_validate_rejects_a_floor_off_the_terrace_grid() -> void:
	assert_ne(_site(4, 5, 25).validate(), "")
	# Negative terrace planes are still planes.
	assert_eq(_site(4, 5, -32).validate(), "")


func test_to_string_names_the_site() -> void:
	assert_true(str(_site()).begins_with("StructureSite("))
