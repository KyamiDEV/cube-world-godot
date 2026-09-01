extends TestCase
## Covers world/terrain/world_bounds.gd (brick 050).

func test_aabb_is_symmetric_around_the_origin() -> void:
	var box := WorldBounds.aabb()

	assert_eq(box.position, Vector3(
			-WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS,
			-WorldBounds.HALF_EXTENT_VERTICAL_VOXELS,
			-WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS))
	assert_eq(box.end, Vector3(
			WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS,
			WorldBounds.HALF_EXTENT_VERTICAL_VOXELS,
			WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS))


func test_vertical_extent_is_smaller_than_horizontal() -> void:
	assert_true(WorldBounds.HALF_EXTENT_VERTICAL_VOXELS < WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS)


func test_contains_the_origin_and_points_just_inside_each_face() -> void:
	assert_true(WorldBounds.contains(Vector3i.ZERO))
	assert_true(WorldBounds.contains(Vector3i(
			WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS - 1,
			WorldBounds.HALF_EXTENT_VERTICAL_VOXELS - 1,
			-WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS)))


func test_rejects_points_outside_each_axis() -> void:
	# `AABB.has_point()` is inclusive at both faces, so "outside" means one voxel past the
	# extent, not exactly on it (the exact face is covered by the "just inside" test above).
	assert_false(WorldBounds.contains(Vector3i(WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS + 1, 0, 0)))
	assert_false(WorldBounds.contains(Vector3i(0, WorldBounds.HALF_EXTENT_VERTICAL_VOXELS + 1, 0)))
	assert_false(WorldBounds.contains(Vector3i(0, 0, -WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS - 1)))


func test_two_calls_to_aabb_agree() -> void:
	assert_eq(WorldBounds.aabb(), WorldBounds.aabb())
