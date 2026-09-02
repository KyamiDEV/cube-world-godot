class_name SurfaceMaterial
extends RefCounted
## Which block covers the ground at a column (backlog brick 075).
##
## `BiomeDefinition.surface_block_id` (075's field, one per biome) says *what* a biome's
## ground looks like; `BiomeTransition` (074) already says *how close* a column sits to a
## different biome and *which one*. This file is the one place those two meet: a per-column
## block id, blended across a biome edge instead of hard-cut, for whichever brick first
## builds a `VoxelGenerator` from it.
##
## ```gdscript
## var surface := SurfaceMaterial.for_world(hash, biomes, blocks)
## var block_id := surface.block_id_at(column)   # e.g. "block.sand"
## ```
##
## ## Blocky ground cannot fade, so it dithers
##
## A `VoxelBlockyModel` cube is one block or another, never a mix, so "blend the material"
## cannot mean what it means for `debug_color` or a terrain tint (Phase J). What it means
## here is a **stochastic dither**: at a column with `neighbor_weight` (074, `[0, 0.5]`),
## a deterministic per-column roll in `[0, 1)` picks the neighbor's block when the roll
## falls under the weight and the primary's otherwise. At `neighbor_weight = 0` the roll
## can never win — every column is the primary, same as no blend at all — and at the
## boundary itself (`0.5`) the two materials are chosen with equal odds, so a strip of
## columns near an edge salt-and-peppers between two blocks rather than snapping cleanly
## from one to the other. This is the discrete-world equivalent of the "tint that does not
## jump" §13.5 already named as the one place this project reads like the reference's own
## continuous blend.
##
## The roll is `GenerationHash.value01_column(column, WorldHash.SALT_SURFACE_MATERIAL)` —
## its own salt, appended rather than reusing one of 074's or 066's, so a later pass that
## also dithers near a biome edge (086's decoration masks, say) cannot correlate with this
## one by accident (`WorldHash`'s own salt-per-pass rule).
##
## `biome_id_at()` exposes the winning side of that roll on its own, not just the block it
## resolves to — `SubsurfaceMaterial` (076) is the reason: what lies under a column's ground
## has to agree with what lies on top of it, so 076 reads this decision rather than rolling
## a second, independent one.
##
## ## The block mapping, and why it is not one block per biome
##
## Only three block kinds existed before this brick (038: grass, dirt, stone). Six biomes
## need six honest grounds, but not six *new* ones — a field nothing fills is worse than a
## record that grows (067's argument, applied here to blocks instead of biome fields):
##
## | Biome | Block | Why |
## |---|---|---|
## | `grassland` | `block.grass` | the reference case grass was authored for |
## | `forest` | `block.grass` | still grassy ground between trees; canopy and litter are 086–088's vegetation, not a different ground block |
## | `desert` | `block.sand` | **new** — no existing block is an honest desert floor |
## | `snow` | `block.snow` | **new** — same reason, for a snowfield |
## | `mountain` | `block.stone` | `RUGGEDNESS_MOUNTAIN` (066) already means "bare rock wins over relief"; the ground it describes already reads as stone |
## | `wetland` | `block.dirt` | swamp/marsh ground is honestly mud, and `block.dirt` is that texture already |
##
## `tools/generators/generate_surface_blocks.gd` writes the two new block kinds
## (`block.sand`, `block.snow`) with the same speckled-placeholder-PNG technique
## `generate_block_set.gd` used for the first three — no Blender/bpy asset pass, same as
## brick 075's backlog row marks the Blender MCP requirement "not needed by default".
##
## ## Not a generation version bump — and the point where that argument runs out
##
## §12.6's and §13.6's argument, and the last brick that gets to make it for free: **no
## world has ever had a voxel written from any Phase D pass**, so nothing this brick
## computes can contradict a world a player has already explored. `BiomeTransition.
## neighbor_weight_at()` is unchanged and still the same input; the new pieces are
## `BiomeDefinition.surface_block_id` (a record field, §12.6's own exception) and
## `WorldHash.SALT_SURFACE_MATERIAL` (an appended salt with no prior user, `SALT_HUMIDITY`'s
## own precedent from brick 065).
##
## That stops being free the moment some later brick's `VoxelGenerator` actually calls
## `block_id_at()` to fill a `VoxelBuffer`. From then on, every input this file reads —
## `SALT_SURFACE_MATERIAL`, every `surface_block_id`, `BiomeTransition.TRANSITION_WIDTH`
## (already generation-adjacent as of §13.6's own flag) — is baked into every world
## generated with it, and changing any of them is a version bump
## (`docs/world-generation.md` §2.1) exactly as `BiomeClassifier`'s thresholds already are.
## `docs/world-generation.md` §14.4 is where that boundary is recorded rather than assumed.
##
## ## Reference: none
##
## §12.5 and §13.5's finding a third time: the original has no discrete biome and so no
## discrete *material* either — `Terrain_computeBiomeColor` blends climate noise straight
## into terrain and vegetation RGBA, continuously, with no block or tile lookup anywhere.
## There is no material-selection mechanism in either binary to diverge from, only the same
## divergence already on record: a discrete id and a discrete block for everything that
## needs one, dithered rather than tinted because the ground here is blocky and theirs was
## not.
##
## Contract: `docs/world-generation.md` §14.

var _hash: GenerationHash
var _transition: BiomeTransition
var _biomes: BiomeRegistry


func _init(p_hash: GenerationHash, p_transition: BiomeTransition, p_biomes: BiomeRegistry) -> void:
	_hash = p_hash
	_transition = p_transition
	_biomes = p_biomes


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds surface material selection to one world and one loaded content set, or returns
## null (logged) when any of the three cannot be built or is incoherent. **The supported
## entry point.**
##
## `biomes` and `blocks` must both be locked — network indices, and therefore a stable
## catalog, are only well-defined after `lock()` (`BlockRegistry`/`BiomeRegistry`'s own
## contract). `biomes` must also pass its own `self_check()` and every `surface_block_id`
## in it must actually name a block `blocks` has, or `block_id_at()` would be built on a
## catalog with a hole in it — the same "broken world" failure `BiomeRegistry.
## coverage_reason()` exists to catch one level up, applied here to the block a biome
## points at instead of the biome itself.
static func for_world(p_hash: GenerationHash, p_biomes: BiomeRegistry,
		p_blocks: BlockRegistry) -> SurfaceMaterial:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build surface material selection without a world binding"):
		return null
	if not Log.check(p_biomes != null and p_biomes.is_locked(), Log.CH_GEN,
			"surface material selection needs a locked biome registry"):
		return null
	if not Log.check(p_blocks != null and p_blocks.is_locked(), Log.CH_GEN,
			"surface material selection needs a locked block registry"):
		return null
	var registry_problem := p_biomes.self_check()
	if not Log.check(registry_problem.is_empty(), Log.CH_GEN,
			"biome catalog is incomplete or incoherent", {"reason": registry_problem}):
		return null
	var block_problem := surface_block_reason_for(p_biomes, p_blocks)
	if not Log.check(block_problem.is_empty(), Log.CH_GEN,
			"biome catalog names a surface block the block registry has no record for",
			{"reason": block_problem}):
		return null
	var bound_transition := BiomeTransition.for_world(p_hash)
	if bound_transition == null:
		return null
	return SurfaceMaterial.new(p_hash, bound_transition, p_biomes)


## Empty string when every registered biome's `surface_block_id` names a block `blocks`
## actually has, otherwise the reason. The cross-domain half of `BiomeRegistry.
## coverage_reason()`'s pattern (067): a typo in a biome's block id is the same shape of
## bug — a column that resolves to a block nothing can look up — and it is worth catching
## once over the whole catalog rather than only where a column happens to sample it.
##
## Static and taking both registries, for the same reachability reason
## `BiomeRegistry.coverage_reason_for()` is static and list-taking: a live `SurfaceMaterial`
## can only ever be built from a catalog that already passed this, so the failing branch
## needs its own caller to be reachable at all — a content-authoring tool, or this test file.
static func surface_block_reason_for(p_biomes: BiomeRegistry, p_blocks: BlockRegistry) -> String:
	for id in p_biomes.ids():
		var definition := p_biomes.get_biome(id)
		if not p_blocks.has_block(definition.surface_block_id):
			return "%s names surface block '%s', which the block registry has no record for" % [
					id, definition.surface_block_id]
	return ""


# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------

## The block id covering the ground at `column`: the primary biome's `surface_block_id`
## away from every edge, dithered against a neighbor's near one. See the class comment for
## why a dither, not a blend. Never empty once `for_world()` accepted the registries it was
## built from — every id `blend_at()` can name has a record, and every record's block
## resolves, both checked once at construction rather than trusted per call.
func block_id_at(column: Vector2i) -> String:
	var id := biome_id_at(column)
	var biome: BiomeDefinition = _biomes.get_biome(id)
	if biome == null:
		Log.error(Log.CH_GEN, "surface material: winning biome has no record",
				{"id": id, "column": column})
		return ""
	return biome.surface_block_id


## The biome id material selection settles on at `column`: the primary away from every edge,
## the dithered neighbor near one — the same roll `block_id_at()` uses, exposed on its own
## because it is a decision other material passes want too. `SubsurfaceMaterial` (076) reads
## this rather than rolling its own independent dither, so a column's subsurface material
## always agrees with whichever biome this roll already picked for the surface above it.
func biome_id_at(column: Vector2i) -> String:
	var blend := _transition.blend_at(column)
	var neighbor_id: String = blend["neighbor"]
	var weight: float = blend["neighbor_weight"]
	if neighbor_id.is_empty() or weight <= 0.0:
		return blend["primary"]
	var roll := _hash.value01_column(column, WorldHash.SALT_SURFACE_MATERIAL)
	return neighbor_id if roll < weight else blend["primary"]


## The same answer at a voxel. Y is dropped, exactly as `BiomeTransition.blend_at_voxel()`
## and `BiomeClassifier.at_voxel()` drop it: ground material is a property of the column.
func block_id_at_voxel(voxel: Vector3i) -> String:
	return block_id_at(GenerationGrid.voxel_to_column(voxel))


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

## The transition underneath, for a debug probe or a consumer that also wants the raw
## primary/neighbor/weight triple. Read-only by convention.
func transition() -> BiomeTransition:
	return _transition


## The biome catalog underneath, for a consumer that wants a record directly.
func biomes() -> BiomeRegistry:
	return _biomes
