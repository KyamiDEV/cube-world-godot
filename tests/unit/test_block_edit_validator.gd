extends TestCase
## Covers world/terrain/block_edit_validator.gd (brick 045).
##
## Voxel-content checks (`TARGET_OCCUPIED`/`TARGET_IS_AIR`/`NOT_DESTRUCTIBLE`) need a
## terrain that has actually meshed the area under the checked position, same as
## `test_block_raycast_service.gd` (043) — `_ready_terrain()` below is the same
## poll-`is_area_meshed()` helper for the same reason. Checks that never touch voxel
## content (`INVALID_REGISTRY`, `OUT_OF_BOUNDS`, `UNKNOWN_BLOCK`) run against a freshly
## built, un-meshed terrain instead, same split `test_block_raycast_service.gd` uses.

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


func _stone_block(destructible: bool = true) -> BlockDefinition:
	var definition := BlockDefinition.new()
	definition.id = VoxelTerrainBuilder.PLACEHOLDER_BLOCK_ID
	definition.display_name = "Stone"
	definition.texture_top = _write_texture("stone_top")
	definition.texture_side = _write_texture("stone_side")
	definition.texture_bottom = _write_texture("stone_bottom")
	definition.footstep_tag = "stone"
	definition.destructible = destructible
	return definition


func _locked_registry_with_stone(destructible: bool = true) -> BlockRegistry:
	var registry := BlockRegistry.new()
	registry.register_block(_stone_block(destructible))
	registry.lock()
	return registry


## Builds a terrain and adds it to the tree, without waiting for meshing — enough for
## checks that never read voxel content, but still real enough that `get_voxel_tool()`
## returns a usable tool (untested whether that needs tree membership, so this stays on
## the safe side rather than assume it does not).
func _built_terrain(registry: BlockRegistry) -> VoxelTerrain:
	var terrain := track_node(VoxelTerrainBuilder.build(registry)) as VoxelTerrain
	get_tree().root.add_child(terrain)
	return terrain


## Like `_built_terrain()`, but also waits until the ground beneath the viewer has
## actually meshed — needed for any check that reads voxel content. Every caller tracks
## the returned node itself (via `track_node`) since this helper also creates an
## untracked `VoxelViewer`.
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

	var verdict := BlockEditValidator.validate(_remove(_GROUND_POSITION), terrain, unlocked)

	assert_eq(verdict, BlockEditValidator.Verdict.INVALID_REGISTRY)


func test_rejects_a_position_outside_bounds() -> void:
	var registry := _locked_registry_with_stone()
	var terrain := _built_terrain(registry)
	terrain.bounds = AABB(Vector3(0, 0, 0), Vector3(16, 16, 16))

	var verdict := BlockEditValidator.validate(_remove(Vector3i(1000, 0, 0)), terrain, registry)

	assert_eq(verdict, BlockEditValidator.Verdict.OUT_OF_BOUNDS)


func test_rejects_placing_an_unregistered_block() -> void:
	var registry := _locked_registry_with_stone()
	var terrain := _built_terrain(registry)

	var verdict := BlockEditValidator.validate(
			_place(_AIR_POSITION, "block.emerald"), terrain, registry)

	assert_eq(verdict, BlockEditValidator.Verdict.UNKNOWN_BLOCK)


# ---------------------------------------------------------------------------
# Checks against real voxel content
# ---------------------------------------------------------------------------

func test_accepts_placing_on_an_air_voxel() -> void:
	var registry := _locked_registry_with_stone()
	var terrain := await _ready_terrain(registry)

	var verdict := BlockEditValidator.validate(
			_place(_AIR_POSITION, VoxelTerrainBuilder.PLACEHOLDER_BLOCK_ID), terrain, registry)

	assert_eq(verdict, BlockEditValidator.Verdict.ACCEPT)


func test_rejects_placing_on_an_occupied_voxel() -> void:
	var registry := _locked_registry_with_stone()
	var terrain := await _ready_terrain(registry)

	var verdict := BlockEditValidator.validate(
			_place(_GROUND_POSITION, VoxelTerrainBuilder.PLACEHOLDER_BLOCK_ID), terrain, registry)

	assert_eq(verdict, BlockEditValidator.Verdict.TARGET_OCCUPIED)


func test_accepts_removing_a_destructible_block() -> void:
	var registry := _locked_registry_with_stone(true)
	var terrain := await _ready_terrain(registry)

	var verdict := BlockEditValidator.validate(_remove(_GROUND_POSITION), terrain, registry)

	assert_eq(verdict, BlockEditValidator.Verdict.ACCEPT)


func test_rejects_removing_a_non_destructible_block() -> void:
	var registry := _locked_registry_with_stone(false)
	var terrain := await _ready_terrain(registry)

	var verdict := BlockEditValidator.validate(_remove(_GROUND_POSITION), terrain, registry)

	assert_eq(verdict, BlockEditValidator.Verdict.NOT_DESTRUCTIBLE)


func test_rejects_removing_air() -> void:
	var registry := _locked_registry_with_stone()
	var terrain := await _ready_terrain(registry)

	var verdict := BlockEditValidator.validate(_remove(_AIR_POSITION), terrain, registry)

	assert_eq(verdict, BlockEditValidator.Verdict.TARGET_IS_AIR)


# ---------------------------------------------------------------------------
# verdict_name()
# ---------------------------------------------------------------------------

func test_verdict_name_matches_the_enum() -> void:
	assert_eq(BlockEditValidator.verdict_name(BlockEditValidator.Verdict.ACCEPT), "ACCEPT")
	assert_eq(BlockEditValidator.verdict_name(BlockEditValidator.Verdict.NOT_DESTRUCTIBLE),
			"NOT_DESTRUCTIBLE")
