extends TestCase
## Covers world/terrain/voxel_terrain_metrics.gd (brick 051).

const _MAX_WAIT_FRAMES := 120
const _MESHED_AREA := AABB(Vector3(0, 0, 0), Vector3(16, 16, 16))
const _VIEWER_POSITION := Vector3(8, 20, 8)

var _temp_paths: PackedStringArray = []
var _log: Node
var _saved_default: int
var _saved_channels: Dictionary


func before_each() -> void:
	_log = get_tree().root.get_node("Log")
	_saved_default = _log.get_level("__unset__")
	_saved_channels = _log._channel_levels.duplicate()
	# Guarantee CH_VOXEL DEBUG lines are captured regardless of the runner's own default.
	_log.set_channel_level(Log.CH_VOXEL, _log.Level.TRACE)


func after_each() -> void:
	# The autoload is shared process-wide; leaking overrides/capture would make the next
	# test order-dependent (same pattern test_log.gd uses).
	_log.set_default_level(_saved_default)
	_log.clear_channel_levels()
	for channel in _saved_channels:
		_log.set_channel_level(channel, _saved_channels[channel])
	_log.take_capture()

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


## Same `_ready_terrain()` pattern as test_block_raycast_service.gd (043)/
## test_voxel_load_save.gd (049): `get_statistics()` needs the terrain actually processing
## in the tree, not just constructed.
func _ready_terrain() -> VoxelTerrain:
	var terrain := track_node(VoxelTerrainBuilder.build(_locked_registry_with_stone())) as VoxelTerrain
	var viewer := track_node(VoxelViewerBuilder.build()) as VoxelViewer
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

func test_terrain_snapshot_of_a_null_terrain_is_empty() -> void:
	assert_true(VoxelTerrainMetrics.terrain_snapshot(null).is_empty())


func test_terrain_snapshot_contains_every_documented_key() -> void:
	var terrain := await _ready_terrain()
	var stats := VoxelTerrainMetrics.terrain_snapshot(terrain)

	assert_has(stats, VoxelTerrainMetrics.KEY_TIME_DETECT_REQUIRED_BLOCKS)
	assert_has(stats, VoxelTerrainMetrics.KEY_TIME_REQUEST_BLOCKS_TO_LOAD)
	assert_has(stats, VoxelTerrainMetrics.KEY_TIME_PROCESS_LOAD_RESPONSES)
	assert_has(stats, VoxelTerrainMetrics.KEY_TIME_REQUEST_BLOCKS_TO_UPDATE)
	assert_has(stats, VoxelTerrainMetrics.KEY_DROPPED_BLOCK_LOADS)
	assert_has(stats, VoxelTerrainMetrics.KEY_DROPPED_BLOCK_MESHES)
	assert_has(stats, VoxelTerrainMetrics.KEY_UPDATED_BLOCKS)
	# Locks in the doc/code discrepancy this brick found (voxel_terrain_metrics.gd's own
	# header note): the engine's real dictionary has 7 keys, not the 9 doc/classes/
	# VoxelTerrain.xml describes.
	assert_size(stats, 7)


func test_engine_snapshot_contains_every_documented_top_level_key() -> void:
	var stats := VoxelTerrainMetrics.engine_snapshot()

	assert_has(stats, VoxelTerrainMetrics.KEY_THREAD_POOLS)
	assert_has(stats, VoxelTerrainMetrics.KEY_TASKS)
	assert_has(stats, VoxelTerrainMetrics.KEY_MEMORY_POOLS)


func test_log_terrain_snapshot_emits_nothing_for_a_null_terrain() -> void:
	_log.start_capture()
	VoxelTerrainMetrics.log_terrain_snapshot(null)
	var records: Array = _log.take_capture()

	# Only the terrain_snapshot() null-check error line, no statistics line.
	for record in records:
		assert_ne(record["message"], "voxel terrain statistics")


func test_log_terrain_snapshot_emits_one_line_carrying_the_statistics() -> void:
	var terrain := await _ready_terrain()
	_log.start_capture()
	VoxelTerrainMetrics.log_terrain_snapshot(terrain)
	var records: Array = _log.take_capture()

	var matching: Array = records.filter(
			func(r): return r["message"] == "voxel terrain statistics")
	assert_size(matching, 1)
	if matching.size() == 1:
		var context: Dictionary = matching[0]["context"]
		assert_has(context, VoxelTerrainMetrics.KEY_UPDATED_BLOCKS)
