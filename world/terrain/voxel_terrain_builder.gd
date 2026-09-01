class_name VoxelTerrainBuilder
extends RefCounted
## Builds a baseline `VoxelTerrain` node from a locked `BlockRegistry` (backlog brick 039).
##
## Scope is deliberately narrow: this owns only what no later Phase C brick already
## claims — collision policy and a placeholder generator, so the node produces real
## voxels end-to-end and is testable now, without waiting on the rest of the stack.
## `mesher` (040, `BlockyLibraryBuilder`'s output), terrain materials (041) and
## `VoxelViewer` interest streaming (042) are left untouched here; a caller composes
## all four onto the same node once each exists. `stream` is explicitly left null —
## persistence is brick 048, and `VoxelNode.stream`'s own doc says an unassigned
## stream makes the whole volume generate on demand, which is exactly what a save-less
## baseline needs.
##
## The generator is an explicit, temporary placeholder: a flat plane of one registered
## block ID, not real world generation (Phase D, bricks 056-067, deterministic
## noise/height/climate fields per `docs/reference/matrix-world.md`). Phase D replaces
## `terrain.generator` outright when it lands; it does not extend this file.
##
## Voxel value convention (`blocky_library_builder.gd`, 037): every voxel value is
## `BlockRegistry.network_index(id) + 1`, with `0` reserved for air. The placeholder
## generator below applies that same offset so its output already matches whatever
## the 040 mesher will assign to that value — no separate "generator epoch" to keep in
## sync.

## Altitude of the placeholder ground plane, in voxel coordinates — `VoxelGeneratorFlat.
## height` operates directly in voxel space, not world units (`core/math/world_scale.gd`
## does not apply here).
const PLACEHOLDER_GROUND_HEIGHT := 4

## The one block kind the placeholder generator fills below `PLACEHOLDER_GROUND_HEIGHT`.
const PLACEHOLDER_BLOCK_ID := "block.stone"


## Returns null (and logs why) when `registry` is not locked, or does not contain
## `PLACEHOLDER_BLOCK_ID` — both are programmer/data errors, not runtime conditions a
## caller should silently paper over.
static func build(registry: BlockRegistry) -> VoxelTerrain:
	if not Log.check(registry.is_locked(), Log.CH_VOXEL,
			"block registry must be locked before building a VoxelTerrain"):
		return null

	var generator := _build_placeholder_generator(registry)
	if generator == null:
		return null

	var terrain := VoxelTerrain.new()
	terrain.generator = generator
	terrain.stream = null
	terrain.generate_collisions = true
	return terrain


static func _build_placeholder_generator(registry: BlockRegistry) -> VoxelGeneratorFlat:
	if not Log.check(registry.has_block(PLACEHOLDER_BLOCK_ID), Log.CH_VOXEL,
			"placeholder generator block is not registered",
			{"id": PLACEHOLDER_BLOCK_ID}):
		return null

	var generator := VoxelGeneratorFlat.new()
	generator.channel = VoxelBuffer.CHANNEL_TYPE
	generator.voxel_type = registry.network_index(PLACEHOLDER_BLOCK_ID) + 1
	generator.height = PLACEHOLDER_GROUND_HEIGHT
	return generator
