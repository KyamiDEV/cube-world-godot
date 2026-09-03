extends TestCase
## `world/generation/world_column.gd` — the per-chunk column cache (brick 091b).
##
## A value record with no noise behind it, so everything here is built by hand rather than
## sampled from a world: what `WorldGenerator` actually produces is `test_world_generator.gd`'s
## question. What is specific to this file is the two-surface split (`ground_y` for depth,
## `terrace_y` for caves), the `top_y()` early-out bound, and `validate()`'s refusal of a record
## no pass could have produced.


func _site(anchor: Vector2i = Vector2i(0, 0), base_y: int = 64, half_extent: int = 5,
		wall_height: int = 6) -> StructureSite:
	return StructureSite.new(GenerationGrid.column_to_region(anchor), anchor, base_y,
			half_extent, wall_height, 0x5EED)


# ---------------------------------------------------------------------------
# Fields
# ---------------------------------------------------------------------------

func test_keeps_what_it_was_given() -> void:
	var plan := WorldColumn.new(Vector2i(3, -7), 48, 56)
	assert_eq(plan.column, Vector2i(3, -7))
	assert_eq(plan.ground_y, 48)
	assert_eq(plan.terrace_y, 56)
	assert_null(plan.site)


func test_has_no_structure_by_default() -> void:
	assert_false(WorldColumn.new(Vector2i(0, 0), 0, 0).has_structure())


func test_has_a_structure_when_a_site_covers_it() -> void:
	assert_true(WorldColumn.new(Vector2i(0, 0), 64, 64, _site()).has_structure())


# ---------------------------------------------------------------------------
# Derived
# ---------------------------------------------------------------------------

func test_depth_is_measured_from_the_real_ground_not_the_terrace_plane() -> void:
	# A river column: the channel cut one riser out of it (§20.5), so the voxel directly under
	# the *carved* bed is depth 1 — asking against `terrace_y` would call it depth 9 and hand
	# back bedrock where topsoil belongs.
	var plan := WorldColumn.new(Vector2i(0, 0), 48, 56)
	assert_eq(plan.depth_at(47), 1)
	assert_eq(plan.depth_at(48), 0)
	assert_eq(plan.depth_at(49), -1)


func test_ground_shift_signs_the_move() -> void:
	assert_eq(WorldColumn.new(Vector2i(0, 0), 48, 56).ground_shift(), -8, "carved")
	assert_eq(WorldColumn.new(Vector2i(0, 0), 64, 64).ground_shift(), 0, "untouched")
	assert_eq(WorldColumn.new(Vector2i(0, 0), 72, 64, _site()).ground_shift(), 8, "filled")


func test_top_y_is_the_ground_where_no_structure_stands() -> void:
	assert_eq(WorldColumn.new(Vector2i(0, 0), 48, 56).top_y(), 48)


func test_top_y_reaches_the_wall_crown_under_a_structure() -> void:
	# base 64 + wall 6 = 70, above the ground the column would otherwise stop at.
	var plan := WorldColumn.new(Vector2i(0, 0), 64, 64, _site())
	assert_eq(plan.top_y(), 70)


func test_top_y_never_falls_below_the_ground() -> void:
	# A pad filled well above its own site's crown: the bound must still cover the terrain.
	var plan := WorldColumn.new(Vector2i(0, 0), 200, 64, _site())
	assert_eq(plan.top_y(), 200)


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

func test_accepts_an_untouched_column() -> void:
	assert_eq(WorldColumn.new(Vector2i(12, -12), 64, 64).validate(), "")


func test_accepts_a_column_carved_by_a_river_and_a_lake() -> void:
	var deepest := RiverPass.CARVE_DEPTH_VOXELS + LakePass.CARVE_DEPTH_VOXELS
	assert_eq(WorldColumn.new(Vector2i(0, 0), 64 - deepest, 64).validate(), "")


func test_rejects_a_ground_height_off_the_terrace_grid() -> void:
	assert_ne(WorldColumn.new(Vector2i(0, 0), 63, 64).validate(), "")


func test_rejects_a_terrace_height_off_the_terrace_grid() -> void:
	assert_ne(WorldColumn.new(Vector2i(0, 0), 64, 63).validate(), "")


func test_rejects_ground_that_rose_with_no_structure_to_raise_it() -> void:
	# Nothing but a building pad ever fills; rivers and lakes only cut (§20.5/§21).
	assert_ne(WorldColumn.new(Vector2i(0, 0), 72, 64).validate(), "")


func test_rejects_a_cut_deeper_than_a_river_and_a_lake_together() -> void:
	var too_deep := (RiverPass.CARVE_DEPTH_VOXELS + LakePass.CARVE_DEPTH_VOXELS
			+ TerracePass.TERRACE_HEIGHT_VOXELS)
	assert_ne(WorldColumn.new(Vector2i(0, 0), 64 - too_deep, 64).validate(), "")


func test_accepts_any_move_under_a_structure_pad() -> void:
	# A pad levels in both directions (§30.4), so the river/lake bound above does not apply.
	assert_eq(WorldColumn.new(Vector2i(0, 0), 72, 64, _site()).validate(), "")


func test_rejects_a_site_whose_pad_does_not_reach_this_column() -> void:
	var far := Vector2i(500, 0)
	assert_ne(WorldColumn.new(far, 64, 64, _site()).validate(), "")


func test_accepts_a_site_at_the_outer_edge_of_its_pad() -> void:
	var site := _site()
	var edge := site.anchor_column + Vector2i(
			site.half_extent_voxels + StructureGenerator.GROUND_PAD_VOXELS, 0)
	assert_eq(WorldColumn.new(edge, 64, 64, site).validate(), "")


func test_to_string_names_the_column_and_both_surfaces() -> void:
	var text := str(WorldColumn.new(Vector2i(3, -7), 48, 56))
	assert_true(text.contains("48") and text.contains("56"), text)
