extends TestCase
## Integration test for the voxel save/load path (backlog brick 049) — first file under
## tests/integration/, per tests/README.md's own "multi-system and network tests"
## description: this exercises three already-unit-tested pieces together
## (`VoxelStreamBuilder`, 048; `VoxelTerrainBuilder`'s `stream` parameter, 048; and
## `BlockEditApplicator`, 046) through a real `VoxelStreamSQLite` file on disk, which none
## of their own unit tests do.
##
## Flow: build a terrain against a real on-disk stream, apply one edit, force-save and
## wait for it to complete (`VoxelTerrain.save_modified_blocks()` returns a
## `VoxelSaveCompletionTracker`; saving is asynchronous per its own doc), fully tear the
## terrain down (not via `track_node`, which only frees after the whole test method
## returns — the next stream build in this same test needs the first `VoxelStreamSQLite`'s
## connection actually released first), then rebuild a fresh terrain against the same
## database path and confirm: the edited voxel survived, and a voxel the edit never
## touched still comes from the placeholder generator, not the stream
## (`save_generator_output = false`, 048 — only deltas are ever saved).

const _MAX_WAIT_FRAMES := 120
const _MESHED_AREA := AABB(Vector3(0, 0, 0), Vector3(16, 16, 16))
const _VIEWER_POSITION := Vector3(8, 20, 8)
const _TICK := 1000

# Ground fills y < PLACEHOLDER_GROUND_HEIGHT (4); the top solid voxel is one below that.
const _EDITED_POSITION := Vector3i(8, 3, 8)
const _UNTOUCHED_GROUND_POSITION := Vector3i(0, 3, 0)

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


func _db_path(name: String) -> String:
	var path := "user://%s.sqlite" % name
	_temp_paths.append(path)
	return path


## Builds a terrain+viewer against `stream`, adds both to the tree, and waits until the
## ground beneath the viewer has actually meshed — same poll-`is_area_meshed()` pattern
## `test_block_raycast_service.gd`/`test_block_edit_applicator.gd` (043/046) use for the
## same reason: a raycast/voxel-tool read is only reliable once the area has meshed.
## Returns `[terrain, viewer]`; on timeout it still returns both (after `fail()`) so the
## caller has something to tear down rather than leaking nodes into the tree.
func _ready_terrain(registry: BlockRegistry, stream: VoxelStream) -> Array:
	var terrain := VoxelTerrainBuilder.build(registry, stream) as VoxelTerrain
	var viewer := VoxelViewerBuilder.build() as VoxelViewer
	viewer.position = _VIEWER_POSITION
	get_tree().root.add_child(terrain)
	get_tree().root.add_child(viewer)

	for _i in range(_MAX_WAIT_FRAMES):
		if terrain.is_area_meshed(_MESHED_AREA):
			return [terrain, viewer]
		await wait_frames(1)

	fail("terrain area never finished meshing within %d frames" % _MAX_WAIT_FRAMES)
	return [terrain, viewer]


## Forces every modified block to be written to `terrain`'s stream and waits for the
## returned `VoxelSaveCompletionTracker` to report done. Saving is asynchronous
## (`VoxelTerrain.save_modified_blocks()`'s own doc: "the save may complete only a short
## time after you call this method") — a caller that tore the terrain down right after
## editing could otherwise race the actual disk write.
func _save_and_wait(terrain: VoxelTerrain) -> void:
	var tracker := terrain.save_modified_blocks()
	for _i in range(_MAX_WAIT_FRAMES):
		if tracker.is_complete():
			return
		await wait_frames(1)
	fail("save_modified_blocks() never completed within %d frames" % _MAX_WAIT_FRAMES)


## Removes `terrain`/`viewer` from the tree and frees them immediately, not via
## `track_node` (which only frees after the whole test method returns, too late for a
## second stream build against the same database path within this same test).
func _teardown(terrain: VoxelTerrain, viewer: VoxelViewer) -> void:
	get_tree().root.remove_child(terrain)
	get_tree().root.remove_child(viewer)
	terrain.free()
	viewer.free()


# ---------------------------------------------------------------------------

func test_an_edit_survives_teardown_and_rebuild_against_the_same_stream() -> void:
	var registry := _locked_registry_with_stone()
	var db_path := _db_path("test_voxel_load_save_edit_survives")

	var first_stream := VoxelStreamBuilder.build(db_path)
	var first := await _ready_terrain(registry, first_stream)
	var first_terrain: VoxelTerrain = first[0]
	var first_viewer: VoxelViewer = first[1]

	var remove_command := EditBlockCommand.new(EditBlockCommand.Kind.REMOVE,
			_EDITED_POSITION, Vector3.UP, "", _TICK)
	var applied := BlockEditApplicator.apply(remove_command, first_terrain, registry)
	if not assert_true(applied, "the edit itself must succeed before this test means anything"):
		_teardown(first_terrain, first_viewer)
		return

	await _save_and_wait(first_terrain)
	_teardown(first_terrain, first_viewer)
	# Let the freed VoxelStreamSQLite's connection actually release the db file before a
	# second stream opens the same path.
	await wait_frames(2)

	var second_stream := VoxelStreamBuilder.build(db_path)
	var second := await _ready_terrain(registry, second_stream)
	var second_terrain: VoxelTerrain = second[0]
	var second_viewer: VoxelViewer = second[1]
	var tool := second_terrain.get_voxel_tool()

	assert_eq(tool.get_voxel(_EDITED_POSITION), 0,
			"049: the REMOVE edit was saved as a delta (048) and must survive reload")
	assert_eq(tool.get_voxel(_UNTOUCHED_GROUND_POSITION),
			registry.network_index(VoxelTerrainBuilder.PLACEHOLDER_BLOCK_ID) + 1,
			"049: an untouched block was never saved (save_generator_output = false, 048) — "
			+ "it must still come from the placeholder generator, not a stale stream entry")

	_teardown(second_terrain, second_viewer)
