class_name BlockyLibraryBuilder
extends RefCounted
## Builds a `VoxelBlockyLibrary` from a locked `BlockRegistry` (backlog brick 037).
##
## `BlockDefinition` (031–036) is a flat per-kind schema with no attribute/state
## variants — no rotation, no connected-state, no on/off. `VoxelBlockyType` /
## `VoxelBlockyTypeLibrary` exist in Voxel Tools 1.7 for exactly that kind of
## variant-driven modelling (`docs/voxel-tools.md` §5 flags this as a decision
## bricks 031–038 must make deliberately). Since nothing in the schema needs
## variants, this builder targets the plain `VoxelBlockyLibrary` +
## `VoxelBlockyModelCube` pair CLAUDE.md §1 already names — revisit only if a
## later block kind genuinely needs per-voxel state (e.g. rotation-aware stairs).
##
## Voxel value 0 is "air" by convention (Voxel Tools does not reserve it
## automatically). `BlockRegistry.network_index()` starts at 0 for its own
## purposes (packets, save deltas) and must not be redefined here, so this
## builder inserts an explicit `VoxelBlockyModelEmpty` at library index 0 and
## then appends one model per registered block in `registry.ids()` order
## (sorted == network-index order once locked, `DefinitionRegistry.lock()`).
## `VoxelBlockyLibrary.add_model()` assigns indices by call order, so the result
## is always `library index == network_index(id) + 1` — any code writing raw
## voxel values (block edit application, 044–046) must apply that +1 offset.
##
## Texture resolution: `VoxelBlockyModelCube.set_tile()` addresses one shared
## atlas per model — an empty/missing texture file degrades that one block to
## an untextured placeholder (`VoxelBlockyModelEmpty`) rather than failing the
## whole build, same "one entry missing, not a crash" pattern as
## `BlockRegistry.register_block()`.
##
## Baked ambient occlusion (brick 040, `matrix-world.md` Q1): `VoxelMesherBlocky`
## always computes AO into cube-edge vertex colors; a model's material only needs
## `vertex_color_use_as_albedo = true` to display it. That built-in behavior is the
## equivalent of the reference's `ChunkBuffer_sampleVoxelColorAO` blend — no custom
## shader was needed, so this file's per-block `StandardMaterial3D` just opts in.

## Fixed 3-tile-wide per-block atlas: top, the four side faces (shared), bottom.
## A block whose faces already share one texture path just repeats it three
## times — no dedup logic, since a few duplicated pixels per block kind is not
## worth the complexity this early (`CLAUDE.md` §8: profile before optimizing).
const _ATLAS_SIZE_IN_TILES := Vector2i(3, 1)
const _TILE_TOP := Vector2i(0, 0)
const _TILE_SIDE := Vector2i(1, 0)
const _TILE_BOTTOM := Vector2i(2, 0)

## Local-space full-voxel box, per `VoxelBlockyModel.collision_aabbs`'s own unit
## (0..1 per axis) — unrelated to `core/math/world_scale.gd`'s metre conversion.
const _FULL_CUBE_AABB := AABB(Vector3.ZERO, Vector3.ONE)

## Physics layer bit a solid block occupies. A bare `1`, not a `WorldScale`-style
## shared constant yet — nothing else references a block collision layer until a
## later brick (block raycast/edit, 043+) needs to filter by it.
const _SOLID_COLLISION_MASK := 1


## Returns null (and logs why) if `registry` is not locked — network indices, and
## therefore library indices, are only well-defined after `lock()`.
static func build(registry: BlockRegistry) -> VoxelBlockyLibrary:
	if not Log.check(registry.is_locked(), Log.CH_VOXEL,
			"block registry must be locked before building a VoxelBlockyLibrary"):
		return null

	var library := VoxelBlockyLibrary.new()
	library.add_model(VoxelBlockyModelEmpty.new())  # index 0 = air, by convention

	for id in registry.ids():
		library.add_model(_build_model(registry.get_block(id)))

	return library


static func _build_model(definition: BlockDefinition) -> VoxelBlockyModel:
	var atlas := _build_atlas(definition)
	if atlas == null:
		return VoxelBlockyModelEmpty.new()

	var model := VoxelBlockyModelCube.new()
	model.resource_name = definition.id
	model.atlas_size_in_tiles = _ATLAS_SIZE_IN_TILES
	model.set_tile(VoxelBlockyModel.SIDE_POSITIVE_Y, _TILE_TOP)
	model.set_tile(VoxelBlockyModel.SIDE_NEGATIVE_Y, _TILE_BOTTOM)
	model.set_tile(VoxelBlockyModel.SIDE_NEGATIVE_X, _TILE_SIDE)
	model.set_tile(VoxelBlockyModel.SIDE_POSITIVE_X, _TILE_SIDE)
	model.set_tile(VoxelBlockyModel.SIDE_NEGATIVE_Z, _TILE_SIDE)
	model.set_tile(VoxelBlockyModel.SIDE_POSITIVE_Z, _TILE_SIDE)

	var material := StandardMaterial3D.new()
	material.albedo_texture = atlas
	# Nearest filtering keeps block edges crisp instead of mip-smearing the atlas seams.
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# VoxelMesherBlocky always bakes ambient occlusion into cube-edge vertex colors; a
	# material only has to opt in to *using* that vertex color as albedo tint for it to
	# show (godot_voxel doc/source/blocky_terrain.md, read at brick 040). This is the
	# resolution of matrix-world.md Q1 (ChunkBuffer_sampleVoxelColorAO): the mesher's
	# built-in baked AO is the equivalent, no custom shader needed.
	material.vertex_color_use_as_albedo = true
	model.set_material_override(0, material)

	# `transparent` (033) is the reference-facing name; VoxelBlockyModel's own flag
	# is phrased the other way around (whether this face set hides a neighbour).
	model.culls_neighbors = not definition.transparent
	model.collision_mask = _SOLID_COLLISION_MASK if definition.is_solid else 0
	model.collision_aabbs = [_FULL_CUBE_AABB] if definition.is_solid else []

	return model


## Packs `definition`'s three face textures into one small atlas. Returns null (and
## logs why) when a face texture fails to load or the three don't share one size —
## a texture atlas needs uniform tiles.
static func _build_atlas(definition: BlockDefinition) -> ImageTexture:
	var top := _load_image(definition.id, "texture_top", definition.texture_top)
	var side := _load_image(definition.id, "texture_side", definition.texture_side)
	var bottom := _load_image(definition.id, "texture_bottom", definition.texture_bottom)
	if top == null or side == null or bottom == null:
		return null

	var tile_size := top.get_size()
	if side.get_size() != tile_size or bottom.get_size() != tile_size:
		Log.error(Log.CH_VOXEL, "block face textures must share one size", {
			"id": definition.id,
			"texture_top": tile_size,
			"texture_side": side.get_size(),
			"texture_bottom": bottom.get_size(),
		})
		return null

	var atlas_image := Image.create(
			tile_size.x * _ATLAS_SIZE_IN_TILES.x, tile_size.y, false, Image.FORMAT_RGBA8)
	var full_tile := Rect2i(Vector2i.ZERO, tile_size)
	atlas_image.blit_rect(top, full_tile, Vector2i(tile_size.x * _TILE_TOP.x, 0))
	atlas_image.blit_rect(side, full_tile, Vector2i(tile_size.x * _TILE_SIDE.x, 0))
	atlas_image.blit_rect(bottom, full_tile, Vector2i(tile_size.x * _TILE_BOTTOM.x, 0))
	return ImageTexture.create_from_image(atlas_image)


static func _load_image(id: String, field: String, path: String) -> Image:
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		Log.error(Log.CH_VOXEL, "failed to load block face texture",
				{"id": id, "field": field, "path": path, "error": err})
		return null
	# Uniform format before blit_rect — source PNGs may differ (RGB vs RGBA, indexed).
	image.convert(Image.FORMAT_RGBA8)
	return image
