class_name VoxelTerrainBuilder
extends RefCounted
## Builds a baseline `VoxelTerrain` node from a locked `BlockRegistry` (backlog brick 039).
##
## Scope is deliberately narrow: this owns only what no later Phase C brick already
## claims — collision policy, the placeholder generator, and (as of brick 040) the
## mesher, so the node produces real, textured voxels end-to-end and is testable now,
## without waiting on the rest of the stack. `VoxelViewer` interest streaming (042) is
## left untouched here; a caller composes it onto the same node once it exists. `stream`
## is explicitly left null — persistence is brick 048, and `VoxelNode.stream`'s own doc
## says an unassigned stream makes the whole volume generate on demand, which is exactly
## what a save-less baseline needs.
##
## `material_override` (041): explicitly left null, not just unset. `VoxelTerrain.
## material_override`, when set, overrides *every* per-model material in the mesher's
## library (godot_voxel doc/source/blocky_terrain.md's own override-order list) — it
## would blow away the per-block texture atlas + baked-AO material 037/040 already build
## per `VoxelBlockyModel`. There is no terrain-wide look (a shared shader, a global tint)
## this project needs yet, so a null override is the correct baseline, not a placeholder
## waiting to be filled in. Revisit only if a future brick needs one material behavior
## applied uniformly across every block kind (e.g. a triplanar snow shader) — see
## `docs/voxel-tools.md` §8.
##
## `mesher` (040): a `VoxelMesherBlocky` wrapping the same registry's
## `BlockyLibraryBuilder.build()` output (037). Built from the same `registry` argument
## as the generator below, so the two can never disagree about which block ids exist.
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

	var mesher := _build_mesher(registry)
	if mesher == null:
		return null

	var terrain := VoxelTerrain.new()
	terrain.generator = generator
	terrain.mesher = mesher
	terrain.stream = null
	terrain.material_override = null
	terrain.generate_collisions = true
	return terrain


## Returns null when `BlockyLibraryBuilder.build()` does (it already logs its own
## reason — an unlocked registry here, since a per-block degrade never fails the whole
## library).
static func _build_mesher(registry: BlockRegistry) -> VoxelMesherBlocky:
	var library := BlockyLibraryBuilder.build(registry)
	if library == null:
		return null

	var mesher := VoxelMesherBlocky.new()
	mesher.library = library
	return mesher


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
