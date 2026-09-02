class_name UndergroundMaterial
extends RefCounted
## What actually occupies a below-surface voxel once caves are carved into it:
## `CaveCarving`'s hollow answer combined with `SubsurfaceMaterial`'s material answer
## (backlog brick 079).
##
## `CaveCarving` (078) already clipped `CaveMask`'s hollow field to the voxels
## `TerracePass` puts underground, and stops there on purpose (§17.4 of its own class
## comment): a bool, not a block id, because deciding what a non-hollow underground voxel
## is *made of* was left to this brick. This file is exactly that combination and nothing
## more — no new noise field, no new salt, no new block, no new `BiomeDefinition` field.
## §16.2's own forward flag ("079 combines this mask with `SubsurfaceMaterial` as two
## independent inputs") is why the two passes stay two objects here rather than merging.
##
## ```gdscript
## var underground := UndergroundMaterial.for_world(hash, biomes, blocks)
## var block_id := underground.block_id_at_voxel(voxel)   # "" above the surface or in a cave
## ```
##
## ```text
## UndergroundMaterial.block_id_at_voxel(voxel) -> String
##         |
##         +-- CaveCarving.is_hollow_at(voxel)   -> ""   (air — the cave itself)
##         +-- otherwise                         -> SubsurfaceMaterial.block_id_at_voxel(voxel)
##                 ("" at/above the surface, topsoil/bedrock below it — 076, unchanged)
## ```
##
## ## Why "" for a carved voxel, not a new "cave" block
##
## `""` already means air on both sides of a block edit (`block_edit_delta.gd`'s own
## convention) and `SurfaceMaterial`/`SubsurfaceMaterial` already return it for "not this
## pass's question" in a context that also happens to be physically air (at or above the
## surface). This brick is the first to return it for a context that is air *because it was
## carved out* rather than because nothing underground has started yet — the same value,
## reused rather than given a second meaning, so a `VoxelGenerator` fill loop never needs to
## tell the two reasons apart.
##
## ## Why this stays a pure combination, not a third material decision
##
## `CaveCarving.is_hollow_at()` already answers hollow-or-not with everything it needs
## (`CaveMask` plus `TerracePass`'s surface height); `SubsurfaceMaterial.block_id_at_voxel()`
## already answers what solid ground is made of. Nothing about a cave wall needs a material
## distinct from the ground the cave sits inside of — the backlog row itself reads
## "underground material rules", not "cave lining material", and no consumer anywhere in the
## project asks for one. Inventing a cave-lining field here would be exactly the kind of
## field nothing reads yet that 067's argument has already ruled out five times over
## (§§12.3, 14.6, 15.2, 16.7's own listing). If a future brick wants cave walls to look
## different from open ground at the same depth, that is a new field on top of this one, not
## a reason to change what this brick returns today.
##
## ## Not a generation version bump
##
## The same boundary every Phase D brick since 062 has stated: no world has ever had a voxel
## written, so nothing this brick computes can contradict one. `UndergroundMaterial` adds no
## field, no salt, no constant — it composes two already-independent passes, neither of
## which this brick touches (`CaveCarving`'s and `SubsurfaceMaterial`'s own tests still pass
## unchanged). The moment some later brick's `VoxelGenerator` calls `block_id_at_voxel()` to
## fill a `VoxelBuffer`, every input both passes read becomes a pinned generation input, the
## same "first `VoxelBuffer` write" boundary §14.4/§15.5/§17.5 already named.
##
## ## Reference: none
##
## §16.5's finding applies unchanged: the reference has no carving mechanism and no
## discrete material system to combine one with, so there is nothing here to diverge from
## either.
##
## Contract: `docs/world-generation.md` §18.

var _carving: CaveCarving
var _subsurface: SubsurfaceMaterial


func _init(p_carving: CaveCarving, p_subsurface: SubsurfaceMaterial) -> void:
	_carving = p_carving
	_subsurface = p_subsurface


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds underground material selection to one world and one loaded content set, or returns
## null (logged) when the binding is missing or either pass underneath it cannot be built.
## **The supported entry point.**
##
## Builds its own `CaveCarving` and `SubsurfaceMaterial`, `TerracePass.for_world()`'s own
## reason (repeated at every layer of this chain): both are stateless and small, and a
## shared instance would be a second way for two passes to disagree about which world they
## are generating. All registry/hash validation is `SubsurfaceMaterial.for_world()`'s own —
## this file adds no check of its own because it adds no field of its own.
static func for_world(p_hash: GenerationHash, p_biomes: BiomeRegistry,
		p_blocks: BlockRegistry) -> UndergroundMaterial:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build underground material selection without a world binding"):
		return null
	var bound_carving := CaveCarving.for_world(p_hash)
	if bound_carving == null:
		return null
	var bound_subsurface := SubsurfaceMaterial.for_world(p_hash, p_biomes, p_blocks)
	if bound_subsurface == null:
		return null
	return UndergroundMaterial.new(bound_carving, bound_subsurface)


# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------

## The block id at `voxel`: `""` when `CaveCarving` says the voxel is hollow (a carved cave,
## or simply above ground — `is_hollow_at()` is false everywhere above the surface),
## otherwise `SubsurfaceMaterial`'s answer for the same voxel (`""` at/above the surface,
## topsoil or bedrock below it). The one function a `VoxelGenerator` fill loop actually
## needs for everything below a column's own surface voxel.
func block_id_at_voxel(voxel: Vector3i) -> String:
	if _carving.is_hollow_at(voxel):
		return ""
	return _subsurface.block_id_at_voxel(voxel)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

## The carving pass underneath, for a consumer that wants the raw hollow answer with no
## material attached. Read-only by convention: neither object this file holds is mutable.
func carving() -> CaveCarving:
	return _carving


## The subsurface pass underneath, for a consumer that wants the solid-ground material with
## no cave clip applied.
func subsurface() -> SubsurfaceMaterial:
	return _subsurface
