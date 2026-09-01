class_name VoxelTerrainBuilder
extends RefCounted
## Builds a baseline `VoxelTerrain` node from a locked `BlockRegistry` (backlog brick 039).
##
## Scope is deliberately narrow: this owns only what no later Phase C brick already
## claims — collision policy, the placeholder generator, and (as of brick 040) the
## mesher, so the node produces real, textured voxels end-to-end and is testable now,
## without waiting on the rest of the stack.
##
## `stream` (048): an optional parameter, defaulting to `null` — every existing caller
## that doesn't pass one keeps the exact save-less behavior 039 established
## (`VoxelNode.stream`'s own doc: an unassigned stream makes the whole volume generate on
## demand). A caller that wants persistence builds one with `VoxelStreamBuilder.build()`
## (`world/persistence/voxel_stream_builder.gd`) and passes it through — this file makes
## no decision about *where* that stream's database lives; that's storage-layout policy,
## deferred to bricks 102-103 per `docs/persistence.md`.
##
## `max_view_distance` (042): `VoxelViewer` is a separate `Node3D`, not a `VoxelTerrain`
## property, so it is built by `voxel_viewer_builder.gd` instead of here — this file only
## owns the terrain-side clamp a `VoxelViewer` requests against
## (`VoxelTerrain.max_view_distance`'s own doc: "If a VoxelViewer requests more, it will
## be clamped"). Set to `DEFAULT_VIEW_DISTANCE`, the same constant
## `VoxelViewerBuilder.build()` uses for `VoxelViewer.view_distance`, so a baseline viewer
## is never silently clamped below what it asked for.
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
## `bounds` (050): `WorldBounds.aabb()` — the project's own authoritative world extent,
## replacing the Voxel Tools engine default (`docs/voxel-tools.md` §15). Confirmed against
## upstream `VoxelTerrain.xml`: `bounds` clips what an infinite generator will fill
## ("blocks will only generate within this region... everything outside will be left
## empty"), not edits — `block_edit_validator.gd` (045)'s own `OUT_OF_BOUNDS` check, which
## reads this same live `terrain.bounds` property, remains the actual edit-authority
## enforcement.
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
##
## `mesh_block_size` (052-054): an explicit optional parameter, `DEFAULT_MESH_BLOCK_SIZE`
## (16) unless a caller passes `32` — the only two values `VoxelTerrain.mesh_block_size`
## accepts (confirmed against upstream `VoxelTerrain.xml`, `godot_voxel` reference repo,
## tag `v1.7`). Brick 054 fixed the default at 16 as a deliberate, measured decision
## (ADR 0002): bricks 052/053 measured size 32 ~7-9% faster to cold-settle on a synthetic
## flat workload, but that one-time startup saving is outweighed by size 32's 8x per-edit
## re-mesh cost (32^3 vs 16^3 mesh cells) on the player-visible latency path in an
## edit-heavy game. The `32` path stays available per-terrain for a future static-terrain
## or heavy-view-distance context that is measured to benefit. An out-of-range value is
## rejected the same way an unlocked registry is: `Log.check` plus a null return, not
## silently clamped or passed through to the engine.

## Altitude of the placeholder ground plane, in voxel coordinates — `VoxelGeneratorFlat.
## height` operates directly in voxel space, not world units (`core/math/world_scale.gd`
## does not apply here).
const PLACEHOLDER_GROUND_HEIGHT := 4

## The one block kind the placeholder generator fills below `PLACEHOLDER_GROUND_HEIGHT`.
const PLACEHOLDER_BLOCK_ID := "block.stone"

## Shared with `voxel_viewer_builder.gd`'s `VoxelViewer.view_distance` (042) — the engine
## default for both properties already agrees (128), but the value is named here as a
## constant, not left as two independently-defaulted `128`s, so the "never silently
## clamped" invariant survives either default changing later.
const DEFAULT_VIEW_DISTANCE := 128

## The project default mesh-chunk edge length, in voxels. Also `VoxelTerrain.
## mesh_block_size`'s own engine default and the value bricks 039-051 ran under
## implicitly — but as of brick 054 this is a deliberate, measured choice, not an
## inherited default: size 16 keeps the per-edit re-mesh unit small (8x cheaper than
## size 32) on the player-visible latency path, at the cost of a one-time ~7-9% slower
## cold streaming settle. Full reasoning and revisit conditions: ADR 0002.
const DEFAULT_MESH_BLOCK_SIZE := 16

## The only two values `VoxelTerrain.mesh_block_size` accepts (052, confirmed against
## upstream `VoxelTerrain.xml`: "Values other than 16 and 32 are not supported.").
const VALID_MESH_BLOCK_SIZES: PackedInt32Array = [16, 32]


## Returns null (and logs why) when `registry` is not locked, does not contain
## `PLACEHOLDER_BLOCK_ID`, or `mesh_block_size` is not one of `VALID_MESH_BLOCK_SIZES` —
## all three are programmer/data errors, not runtime conditions a caller should silently
## paper over. `stream` (048) is assigned as given, `null` by default.
static func build(registry: BlockRegistry, stream: VoxelStream = null,
		mesh_block_size: int = DEFAULT_MESH_BLOCK_SIZE) -> VoxelTerrain:
	if not Log.check(registry.is_locked(), Log.CH_VOXEL,
			"block registry must be locked before building a VoxelTerrain"):
		return null

	if not Log.check(VALID_MESH_BLOCK_SIZES.has(mesh_block_size), Log.CH_VOXEL,
			"mesh_block_size must be 16 or 32", {"mesh_block_size": mesh_block_size}):
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
	terrain.stream = stream
	terrain.material_override = null
	terrain.generate_collisions = true
	terrain.max_view_distance = DEFAULT_VIEW_DISTANCE
	terrain.bounds = WorldBounds.aabb()
	terrain.mesh_block_size = mesh_block_size
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
