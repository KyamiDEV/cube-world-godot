extends TestCase
## Integration test for the first real terrain the project generates (backlog brick 091b).
##
## `test_world_generator.gd` proves what `fill_buffer()` puts in a `VoxelBuffer`. It cannot
## prove the one thing this brick actually exists for: that **Voxel Tools calls it**.
## `_generate_block()` is a virtual only the engine invokes, on its own worker threads, and
## every Phase D brick since 062 has ended its docs with "the moment some later brick's
## `VoxelGenerator` writes a `VoxelBuffer`". This file is where that stops being a forward
## reference — a real `VoxelTerrain` built by `VoxelTerrainBuilder.build_world()`, streamed
## until the ground around the origin has meshed, and read back through `VoxelTool` to confirm
## the voxels in the live volume are the ones `WorldGenerator` says belong there.
##
## `test_voxel_load_save.gd`'s own patterns are reused rather than re-invented: poll
## `is_area_meshed()` for readiness, tear the terrain down explicitly rather than via
## `track_node`.
##
## **View distance is deliberately tiny.** Generation is per-column GDScript noise and costs
## roughly a third of a second per 16³ chunk at this brick (`docs/performance-budget.md` §4);
## the project default of 128 would ask for thousands of chunks and take the better part of an
## hour. 16 is the smallest distance that still streams the sampled column, and the cost of
## that choice — this test says nothing about streaming behaviour at a playable view distance —
## is a Phase E/L question (096-101, 257-258), not this brick's.

## Waited in wall-clock milliseconds, not frames: a headless frame costs almost nothing, so a
## frame budget large enough for real generation work would be an unreadable number, and one
## that reads reasonable expires in under a second.
const _MAX_WAIT_MSEC := 180000
const _VIEW_DISTANCE := 16
const _SAMPLED_COLUMN := Vector2i(0, 0)

var _terrain: VoxelTerrain
var _viewer: VoxelViewer


func after_each() -> void:
	if _terrain != null:
		get_tree().root.remove_child(_terrain)
		_terrain.free()
		_terrain = null
	if _viewer != null:
		get_tree().root.remove_child(_viewer)
		_viewer.free()
		_viewer = null


func _world_seed() -> WorldSeed:
	return GenerationFixtures.world(GenerationFixtures.WORLD_TYPED)


## Builds the real world terrain, clamps it to `_VIEW_DISTANCE`, drops a viewer on the sampled
## column's own ground and waits for that ground to mesh. Returns the generator, or null after
## `fail()` when the terrain never settled.
func _ready_world() -> WorldGenerator:
	var blocks := BlockSet.load_default()
	_terrain = VoxelTerrainBuilder.build_world(_world_seed(), blocks, BiomeCatalog.load_default())
	if _terrain == null:
		fail("VoxelTerrainBuilder.build_world() returned null")
		return null
	var generator := _terrain.generator as WorldGenerator
	_terrain.max_view_distance = _VIEW_DISTANCE

	var ground_y := generator.column_at(_SAMPLED_COLUMN).ground_y
	_viewer = VoxelViewerBuilder.build() as VoxelViewer
	_viewer.view_distance = _VIEW_DISTANCE
	_viewer.position = Vector3(_SAMPLED_COLUMN.x, ground_y, _SAMPLED_COLUMN.y)
	get_tree().root.add_child(_terrain)
	get_tree().root.add_child(_viewer)

	var area := AABB(Vector3(_SAMPLED_COLUMN.x - 4, ground_y - 8, _SAMPLED_COLUMN.y - 4),
			Vector3(8, 16, 8))
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < _MAX_WAIT_MSEC:
		if _terrain.is_area_meshed(area):
			return generator
		await wait_frames(1)
	fail("the world never finished meshing %s within %d ms" % [area, _MAX_WAIT_MSEC])
	return null


# ---------------------------------------------------------------------------
#
# One test, not three: streaming a real world costs seconds even at `_VIEW_DISTANCE`, and
# every assertion below is about the same settled volume.

func test_the_engine_generates_the_world_the_content_query_describes() -> void:
	var generator := await _ready_world()
	if generator == null:
		return
	var blocks := generator.blocks()
	var tool := _terrain.get_voxel_tool()
	var ground_y := generator.column_at(_SAMPLED_COLUMN).ground_y

	# The surface voxel, the topsoil under it and the air above it — three different branches of
	# `block_id_in_column()`, all read back out of a live streaming volume.
	for y in range(ground_y - 4, ground_y + 3):
		var voxel := Vector3i(_SAMPLED_COLUMN.x, y, _SAMPLED_COLUMN.y)
		assert_eq(tool.get_voxel(voxel),
				generator.voxel_value_of(generator.block_id_at_voxel(voxel)),
				"the streamed volume disagrees with WorldGenerator at %s" % voxel)

	# The blunt version of the same claim, stated so a regression that generates an empty (or
	# entirely solid) world fails loudly rather than by an equality that happens to hold.
	var surface := tool.get_voxel(Vector3i(_SAMPLED_COLUMN.x, ground_y, _SAMPLED_COLUMN.y))
	assert_ne(surface, WorldGenerator.AIR_VOXEL_VALUE, "the surface voxel must be solid")
	assert_eq(tool.get_voxel(Vector3i(_SAMPLED_COLUMN.x, ground_y + 2, _SAMPLED_COLUMN.y)),
			WorldGenerator.AIR_VOXEL_VALUE, "two voxels above the ground must be sky")

	# The +1 convention end to end: whatever the generator wrote must resolve back to a real
	# `BlockDefinition` through the same registry the `VoxelBlockyLibrary` was built from,
	# otherwise the world streams as untextured or invisible geometry.
	assert_true(surface > 0 and surface <= blocks.size(),
			"voxel value %d is out of range" % surface)
	assert_true(blocks.has_block(blocks.id_from_network_index(surface - 1)),
			"voxel value %d resolves to no registered block" % surface)
