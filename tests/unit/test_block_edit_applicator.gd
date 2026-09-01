extends TestCase
## Covers world/terrain/block_edit_applicator.gd (brick 046).
##
## Every voxel-writing test needs a terrain that has actually meshed the area under the
## written position, same reasoning as `test_block_edit_validator.gd` (045) and
## `test_block_raycast_service.gd` (043) — `_ready_terrain()` below is the same
## poll-`is_area_meshed()` helper for the same reason. The one check that never touches
## voxel content (`INVALID_REGISTRY`) runs against a freshly built, un-meshed terrain
## instead, same split those two files use.

const _MAX_WAIT_FRAMES := 120
const _MESHED_AREA := AABB(Vector3(0, 0, 0), Vector3(16, 16, 16))
const _VIEWER_POSITION := Vector3(8, 20, 8)
const _TICK := 1000

# Ground fills y < PLACEHOLDER_GROUND_HEIGHT (4); the top solid voxel is one below that.
const _GROUND_POSITION := Vector3i(8, 3, 8)
const _AIR_POSITION := Vector3i(8, 10, 8)

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


## Builds a terrain and adds it to the tree, without waiting for meshing — enough for the
## one check that never reads/writes voxel content.
func _built_terrain(registry: BlockRegistry) -> VoxelTerrain:
	var terrain := track_node(VoxelTerrainBuilder.build(registry)) as VoxelTerrain
	get_tree().root.add_child(terrain)
	return terrain


## Like `_built_terrain()`, but also waits until the ground beneath the viewer has
## actually meshed — needed for any check that reads or writes voxel content. Every
## caller tracks the returned node itself (via `track_node`) since this helper also
## creates an untracked `VoxelViewer`.
func _ready_terrain(registry: BlockRegistry) -> VoxelTerrain:
	var terrain := track_node(VoxelTerrainBuilder.build(registry)) as VoxelTerrain
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


func _place(position: Vector3i, block_id: String) -> EditBlockCommand:
	return EditBlockCommand.new(EditBlockCommand.Kind.PLACE, position, Vector3.UP,
			block_id, _TICK)


func _remove(position: Vector3i) -> EditBlockCommand:
	return EditBlockCommand.new(EditBlockCommand.Kind.REMOVE, position, Vector3.UP,
			"", _TICK)


# ---------------------------------------------------------------------------
# Checks that do not need a meshed terrain
# ---------------------------------------------------------------------------

func test_rejects_an_unlocked_registry() -> void:
	var terrain := _built_terrain(_locked_registry_with_stone())
	var unlocked := BlockRegistry.new()
	unlocked.register_block(_stone_block())

	var applied := BlockEditApplicator.apply(_remove(_GROUND_POSITION), terrain, unlocked)

	assert_false(applied)


# ---------------------------------------------------------------------------
# Checks against real voxel content
# ---------------------------------------------------------------------------

func test_place_writes_the_network_index_plus_one() -> void:
	var registry := _locked_registry_with_stone()
	var terrain := await _ready_terrain(registry)
	var tool := terrain.get_voxel_tool()

	var applied := BlockEditApplicator.apply(
			_place(_AIR_POSITION, VoxelTerrainBuilder.PLACEHOLDER_BLOCK_ID), terrain, registry)

	assert_true(applied)
	assert_eq(tool.get_voxel(_AIR_POSITION),
			registry.network_index(VoxelTerrainBuilder.PLACEHOLDER_BLOCK_ID) + 1)


func test_remove_writes_air() -> void:
	var registry := _locked_registry_with_stone()
	var terrain := await _ready_terrain(registry)
	var tool := terrain.get_voxel_tool()

	var applied := BlockEditApplicator.apply(_remove(_GROUND_POSITION), terrain, registry)

	assert_true(applied)
	assert_eq(tool.get_voxel(_GROUND_POSITION), 0)


func test_rejects_placing_an_unregistered_block_and_leaves_the_voxel_untouched() -> void:
	var registry := _locked_registry_with_stone()
	var terrain := await _ready_terrain(registry)
	var tool := terrain.get_voxel_tool()

	var applied := BlockEditApplicator.apply(
			_place(_AIR_POSITION, "block.emerald"), terrain, registry)

	assert_false(applied)
	assert_eq(tool.get_voxel(_AIR_POSITION), 0)
