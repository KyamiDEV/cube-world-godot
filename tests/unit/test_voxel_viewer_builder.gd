extends TestCase
## Covers world/terrain/voxel_viewer_builder.gd (brick 042).


func test_builds_a_viewer_with_baseline_properties() -> void:
	var viewer := track_node(VoxelViewerBuilder.build())

	assert_not_null(viewer)
	assert_true(viewer is VoxelViewer)
	assert_true(viewer.requires_visuals)
	assert_true(viewer.requires_collisions)


func test_view_distance_matches_the_terrain_max_view_distance() -> void:
	var viewer := track_node(VoxelViewerBuilder.build())

	assert_eq(viewer.view_distance, VoxelTerrainBuilder.DEFAULT_VIEW_DISTANCE,
			"a baseline viewer must never request more than VoxelTerrain allows, or it is silently clamped")
