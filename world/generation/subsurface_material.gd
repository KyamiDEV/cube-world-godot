class_name SubsurfaceMaterial
extends RefCounted
## What lies under a column's surface block: a topsoil layer down to a fixed depth, then
## bedrock (backlog brick 076).
##
## `SurfaceMaterial` (075) already answers what covers the very top of a column;
## `TerracePass` (063) already answers how high that top sits, and its risers are up to one
## terrace tall — so a cliff face genuinely exposes whatever is under the topsoil, this is
## not a hypothetical question. This file is the one place those two meet with the third
## piece, `BiomeDefinition.subsurface_block_id`, to answer what a column looks like *under*
## its own surface, down to where every column becomes the same bedrock regardless of biome.
##
## ```gdscript
## var subsurface := SubsurfaceMaterial.for_world(hash, biomes, blocks)
## var block_id := subsurface.block_id_at_voxel(voxel)   # "" at or above the surface
## ```
##
## ## Why this reads the surface's *pick*, not the biome's classification
##
## A column near a biome edge already dithers its surface block between the primary and the
## neighbor (075, §14.1) — a per-**column** coin flip, not a per-voxel one. If this file
## rolled its own independent coin for the layer underneath, part of the dithered band would
## put a neighbor's grass over the primary's dirt: two different biomes' ground stacked in
## one column, which is not a blend, it is a seam. `SurfaceMaterial.biome_id_at()` is the
## column's material decision already made; this file reads it rather than re-deriving it,
## so a column's dirt always matches its own grass. No new salt, for the same reason —
## appending one here would be a second dither stacked on the first, not a second decision.
##
## ## Two layers only: topsoil, then bedrock
##
## | Depth below the surface voxel | Block |
## |---|---|
## | `1 .. SUBSURFACE_DEPTH_VOXELS` | the winning biome's `subsurface_block_id` |
## | deeper | `DEEP_BLOCK_ID` (`block.stone`) — every biome's floor |
##
## A third, biome-varying bedrock layer is exactly the kind of field nothing yet fills
## (067's argument, applied a third time): nothing in this project reads bedrock composition
## today, so inventing per-biome bedrock would be a record no consumer asks for. `block.stone`
## is not a new block either — 038 already shipped it, and it is already what a mountain's
## own surface reads as (075, §14.2).
##
## `SUBSURFACE_DEPTH_VOXELS` is derived, not chosen: half of `TerracePass.
## TERRACE_HEIGHT_VOXELS`, the same "half, not the whole" shape `BiomeTransition.
## TRANSITION_WIDTH` already used against a different constant (§13.2). A topsoil shallower
## than a full riser (`TerracePass.max_riser_voxels()` is exactly one terrace) means a cliff
## that crosses a whole shelf shows bedrock beneath the soil partway down its face — the
## legible "this is rock, not a flowerbed" result a full-terrace topsoil would not give. Not
## a const expression for the same reason `TRANSITION_WIDTH` isn't — `TerracePass.
## TERRACE_HEIGHT_VOXELS` is a real constant reference, but the derivation is still asserted
## in `self_check()` and in the test file rather than trusted from a comment, matching the
## project's one existing precedent for a derived depth/width constant.
##
## ## Not a generation version bump — same boundary as 075's
##
## §14.4's argument, unchanged and for the same reason: no world has ever had a voxel
## written, so nothing here can contradict one. The new pieces are
## `BiomeDefinition.subsurface_block_id` (a record field, §12.6's stated exception) and
## `SUBSURFACE_DEPTH_VOXELS` (a pure constant — no hash, no salt, no noise layer). The moment
## some later brick's `VoxelGenerator` calls `block_id_at_voxel()` to fill a `VoxelBuffer`,
## both join `SALT_SURFACE_MATERIAL` and every `surface_block_id` on the list §14.4 already
## opened — and, transitively, `SurfaceMaterial.biome_id_at()`'s own inputs, since this file
## reads them rather than recomputing them.
##
## ## Reference: none
##
## §12.5/§13.5/§14.5's finding, a fourth time: the original has no discrete biome and no
## discrete surface material, so it has no discrete subsurface either —
## `Terrain_computeBiomeColor` never reads more than one voxel deep in the first place.
## Nothing to diverge from, only the same choice already on record: a discrete id for
## everything the blocky ground needs, one layer further down than 075 went.
##
## Contract: `docs/world-generation.md` §15.

## Depth of the topsoil layer below the surface voxel, in voxels — 4 voxels = 2 m, half of
## `TerracePass.TERRACE_HEIGHT_VOXELS`. See the class comment for why. Asserted in
## `self_check()` rather than trusted from the comment alone.
const SUBSURFACE_DEPTH_VOXELS := 4

## The block every column's bedrock is made of, regardless of biome. See the class comment
## for why this is a constant and not a per-biome field.
const DEEP_BLOCK_ID := "block.stone"

var _surface: SurfaceMaterial
var _terrace: TerracePass
var _biomes: BiomeRegistry


func _init(p_surface: SurfaceMaterial, p_terrace: TerracePass, p_biomes: BiomeRegistry) -> void:
	_surface = p_surface
	_terrace = p_terrace
	_biomes = p_biomes


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds subsurface material selection to one world and one loaded content set, or returns
## null (logged) when any piece cannot be built or is incoherent. **The supported entry
## point.**
##
## Builds its own `SurfaceMaterial` and `TerracePass` for the reason every pass in this
## chain builds its own dependencies (`TerracePass.for_world()`'s own reason): the objects
## are stateless and small, and a shared instance would be a second way for two passes to
## disagree about which world they are generating. `SurfaceMaterial.for_world()` already
## validates `biomes`/`blocks` locking, `biomes.self_check()` and every `surface_block_id`;
## this adds the one check that is 076's own, `subsurface_block_reason_for()`.
static func for_world(p_hash: GenerationHash, p_biomes: BiomeRegistry,
		p_blocks: BlockRegistry) -> SubsurfaceMaterial:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build subsurface material selection without a world binding"):
		return null
	var block_problem := subsurface_block_reason_for(p_biomes, p_blocks)
	if not Log.check(block_problem.is_empty(), Log.CH_GEN,
			"biome catalog names a subsurface block the block registry has no record for",
			{"reason": block_problem}):
		return null
	var bound_surface := SurfaceMaterial.for_world(p_hash, p_biomes, p_blocks)
	if bound_surface == null:
		return null
	var bound_terrace := TerracePass.for_world(p_hash)
	if bound_terrace == null:
		return null
	return SubsurfaceMaterial.new(bound_surface, bound_terrace, p_biomes)


## Empty string when every registered biome's `subsurface_block_id` names a block `blocks`
## actually has and `blocks` also has `DEEP_BLOCK_ID`, otherwise the reason.
## `SurfaceMaterial.surface_block_reason_for()`'s exact shape, one field over — a `biomes`
## or `blocks` that is null or unlocked is not this function's question, the same way it is
## not that one's; a caller with either in doubt uses `for_world()`.
##
## Static and taking both registries, for the same reachability reason
## `SurfaceMaterial.surface_block_reason_for()` is: a live `SubsurfaceMaterial` can only ever
## be built from a catalog that already passed this, so the failing branch needs its own
## caller to be reachable at all.
static func subsurface_block_reason_for(p_biomes: BiomeRegistry, p_blocks: BlockRegistry) -> String:
	for id in p_biomes.ids():
		var definition := p_biomes.get_biome(id)
		if not p_blocks.has_block(definition.subsurface_block_id):
			return "%s names subsurface block '%s', which the block registry has no record for" % [
					id, definition.subsurface_block_id]
	if not p_blocks.has_block(DEEP_BLOCK_ID):
		return "block registry has no record for '%s', the fixed bedrock block" % DEEP_BLOCK_ID
	return ""


# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------

## The block id at `y` in `column`'s ground: `""` at or above the surface voxel (not this
## file's question — see `SurfaceMaterial`), the winning biome's `subsurface_block_id` for
## the topsoil depth beneath it, `DEEP_BLOCK_ID` deeper than that. Never empty below the
## surface once `for_world()` accepted the registries it was built from, the same guarantee
## `SurfaceMaterial.block_id_at()` documents.
func block_id_at(column: Vector2i, y: int) -> String:
	var depth := _terrace.surface_y(column) - y
	if depth <= 0:
		return ""
	if depth > SUBSURFACE_DEPTH_VOXELS:
		return DEEP_BLOCK_ID

	var id := _surface.biome_id_at(column)
	var biome: BiomeDefinition = _biomes.get_biome(id)
	if biome == null:
		Log.error(Log.CH_GEN, "subsurface material: winning biome has no record",
				{"id": id, "column": column})
		return DEEP_BLOCK_ID
	return biome.subsurface_block_id


## The same answer at a voxel: the column form does the work, `voxel.y` supplies the depth.
func block_id_at_voxel(voxel: Vector3i) -> String:
	return block_id_at(GenerationGrid.voxel_to_column(voxel), voxel.y)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

## The surface pass underneath, for a consumer that also wants the top block or the raw
## blend. Read-only by convention.
func surface() -> SurfaceMaterial:
	return _surface


## The terrace pass underneath, for a consumer that wants the surface height directly.
func terrace() -> TerracePass:
	return _terrace


## The biome catalog underneath, for a consumer that wants a record directly.
func biomes() -> BiomeRegistry:
	return _biomes


## Empty string when `SUBSURFACE_DEPTH_VOXELS` still is what the class comment says it is,
## otherwise the reason. Same shape and purpose as `BiomeTransition.self_check()`.
static func self_check() -> String:
	@warning_ignore("integer_division")
	var expected := TerracePass.TERRACE_HEIGHT_VOXELS / 2
	if SUBSURFACE_DEPTH_VOXELS != expected:
		return ("SUBSURFACE_DEPTH_VOXELS %d no longer matches half of TERRACE_HEIGHT_VOXELS "
				+ "(%d)") % [SUBSURFACE_DEPTH_VOXELS, expected]
	return ""
