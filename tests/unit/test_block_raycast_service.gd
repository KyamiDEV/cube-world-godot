extends TestCase
## Covers world/terrain/block_raycast_service.gd and block_raycast_hit.gd (brick 043).
##
## `raycast()` only finds a real hit once the terrain has actually meshed the area under
## it, which — even against the placeholder `VoxelGeneratorFlat` (039), no stream, no
## async persistence involved — still needs the terrain in the SceneTree with a
## `VoxelViewer` nearby and a few real frames for Voxel Tools' worker threads to catch up
## (confirmed empirically: not reachable synchronously, `try_set_block_data()` alone does
## not work outside the tree either). `_ready_terrain()` below polls `is_area_meshed()`
## per frame instead of a fixed frame count, so the test does not flake if worker timing
## varies.

const _MAX_WAIT_FRAMES := 120
const _MESHED_AREA := AABB(Vector3(0, 0, 0), Vector3(16, 16, 16))
const _VIEWER_POSITION := Vector3(8, 20, 8)

var _temp_paths: PackedStringArray = []


func after_each() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		for path in _temp_paths:
			dir.remove(path.trim_prefix("user://"))
	_temp_paths.clear()


func _write_texture(name: String) -> String:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var path := "user://%s.png" % name
	image.save_png(path)
	_temp_paths.append(path)
	return path


func _stone_block() -> BlockDefinition:
	var definition := BlockDefinition.new()
	definition.id = VoxelTerrainBuilder.PLACEHOLDER_BLOCK_ID
	definition.display_name = "Stone"
	definition.texture_top = _write_texture("stone_top")
	definition.texture_side = _write_texture("stone_side")
	definition.texture_bottom = _write_texture("stone_bottom")
	definition.footstep_tag = "stone"
	return definition


func _locked_registry_with_stone() -> BlockRegistry:
	var registry := BlockRegistry.new()
	registry.register_block(_stone_block())
	registry.lock()
	return registry


## Builds a terrain, adds it (and a viewer) to the tree, and waits until the ground
## beneath the viewer has actually meshed. Every caller tracks the returned node itself
## (via `track_node`) since this helper also creates an untracked `VoxelViewer`.
func _ready_terrain(registry: BlockRegistry) -> VoxelTerrain:
	var terrain := track_node(VoxelTerrainBuilder.build(registry)) as VoxelTerrain
	var viewer := track_node(VoxelViewerBuilder.build()) as VoxelViewer
	# `position`, not `global_position`, and set before add_child(): the viewer has no
	# parent transform yet to make those different, and Node3D's global_position setter
	# logs a harmless-but-noisy "not inside tree" error if called before add_child().
	viewer.position = _VIEWER_POSITION
	get_tree().root.add_child(terrain)
	get_tree().root.add_child(viewer)

	for _i in range(_MAX_WAIT_FRAMES):
		if terrain.is_area_meshed(_MESHED_AREA):
			return terrain
		await wait_frames(1)

	fail("terrain area never finished meshing within %d frames" % _MAX_WAIT_FRAMES)
	return terrain


# ---------------------------------------------------------------------------

func test_rejects_an_unlocked_registry() -> void:
	var terrain := track_node(VoxelTerrainBuilder.build(_locked_registry_with_stone()))
	var unlocked := BlockRegistry.new()
	unlocked.register_block(_stone_block())

	assert_null(BlockRaycastService.cast(terrain, unlocked, Vector3.ZERO, Vector3.DOWN))


func test_rejects_a_zero_direction() -> void:
	var registry := _locked_registry_with_stone()
	var terrain := track_node(VoxelTerrainBuilder.build(registry))

	assert_null(BlockRaycastService.cast(terrain, registry, Vector3.ZERO, Vector3.ZERO))


func test_cast_resolves_a_hit_on_the_placeholder_ground() -> void:
	var registry := _locked_registry_with_stone()
	var terrain := await _ready_terrain(registry)

	# _VIEWER_POSITION.y (20) to the ground (height 4) is farther than
	# BlockRaycastService.DEFAULT_MAX_DISTANCE (10) reaches — pass an explicit distance
	# long enough for this test's own viewer height, same as any real caller with a
	# taller-than-default reach would.
	var hit := BlockRaycastService.cast(terrain, registry, _VIEWER_POSITION, Vector3.DOWN, 20.0)

	assert_not_null(hit)
	if hit == null:
		return
	assert_eq(hit.block_id, VoxelTerrainBuilder.PLACEHOLDER_BLOCK_ID)
	# The ground fills y < PLACEHOLDER_GROUND_HEIGHT, so the top solid voxel is one below it.
	var expected_hit_y := VoxelTerrainBuilder.PLACEHOLDER_GROUND_HEIGHT - 1
	assert_eq(hit.hit_position, Vector3i(8, expected_hit_y, 8))
	assert_eq(hit.placement_position, Vector3i(8, expected_hit_y + 1, 8),
			"the voxel just above the hit one — where a placed block would go")
	assert_almost_eq(hit.distance, _VIEWER_POSITION.y - VoxelTerrainBuilder.PLACEHOLDER_GROUND_HEIGHT, 0.5)


func test_cast_returns_null_when_nothing_is_hit() -> void:
	var registry := _locked_registry_with_stone()
	var terrain := await _ready_terrain(registry)

	# Straight up from inside open air: nothing above the viewer within reach.
	var hit := BlockRaycastService.cast(terrain, registry, _VIEWER_POSITION, Vector3.UP, 5.0)

	assert_null(hit)
