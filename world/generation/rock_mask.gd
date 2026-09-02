class_name RockMask
extends RefCounted
## Which columns host a scattered rock or prop, and how densely per biome (backlog brick 088).
##
## `TreeMask` (087) one pass over: `DecorationMask` (086) already answers "is there room for
## any decoration here" as a pure function of a column's coordinates, deliberately blind to
## biome; this brick spends its own `BiomeDefinition` field (`prop_density`) and its own
## reserved salt (`WorldHash.SALT_PROPS`) to turn that into "does a rock stand here", exactly
## as 087 spent `vegetation_density` and `SALT_TREES`. Nothing is added to `DecorationMask`;
## this is a second consumer of it, not an extension.
##
## ```gdscript
## var rocks := RockMask.for_world(hash, biomes, blocks)
## if rocks.is_rock_at(column):
##     _place_rock(column)
## ```
##
## ## Density comes from the biome the ground already agreed on
##
## `BiomeDefinition.prop_density` is read through `SurfaceMaterial.biome_id_at(column)` — the
## same dithered biome pick `SubsurfaceMaterial` (076) and `TreeMask` (087) already read,
## never `BiomeClassifier.at()` directly — so a column's rock density always agrees with
## whichever biome's ground it is actually standing on, including the salt-and-pepper columns
## near a biome edge. `TreeMask`'s own reasoning, unchanged.
##
## ## Two differences from `TreeMask`, both deliberate
##
## **1. No snow exclusion.** `TreeMask` reads `SnowlineMaterial.is_snow_covered_at()` and
## refuses a snow-capped column: a real treeline stops below a cold summit. A rock line does
## not — boulders, scree and outcrops sit on and above the snow, and a snow-capped peak
## strewn with rock is the shape this pass is for. So `RockMask` composes `DecorationMask`
## and `SurfaceMaterial` only; it never builds or reads `SnowlineMaterial`. `DecorationMask`'s
## own water/shoreline exclusion still applies (a rock does not float), inherited exactly as
## `TreeMask` inherits it.
##
## **2. Every biome is positive, and `mountain` is the densest.** `vegetation_density` ships
## `desert`/`snow`/`mountain` at `0.0`; `prop_density` ships all six positive, with
## `biome.mountain` the **highest** rather than absent. `nextsteps.md` flagged this at the
## brick's start: rocks are something a mountain biome plausibly wants *more* of, not fewer,
## the opposite of trees. The answer is the same shape as 087's — no separate
## `ErosionPass.ruggedness_at()` gate here either, because a genuinely rugged column already
## routes to `biome.mountain` through the classifier (`RUGGEDNESS_MOUNTAIN`, 066) — but the
## per-biome number is turned up instead of off, so the rockiness a ruggedness gate would add
## is expressed through the biome the ruggedness already produced. §27.3.
##
## ## Order: the (rarely-firing) cheap gate first
##
## `is_rock_at()` still checks `spacing_at(column) > 0` before touching `DecorationMask`, the
## same cheap-rejection-first ordering `CaveCarving.is_hollow_at()` (078) and `TreeMask` (087)
## use. With the shipped catalog no biome is `0.0`, so this gate almost never fires — but a
## future biome may ship `0.0`, and a hand-built registry in a test can, so the guard stays.
##
## ## What this brick does not decide
##
## - **What a rock or a prop actually is.** No `VoxelBlockyModel`, no mesh, no object id —
##   this brick decides candidate columns only, `TreeMask`'s exact boundary. Placement is
##   095/106–107.
## - **Cross-pass exclusion with `TreeMask`.** `DecorationMask` §25.8 stands: a tree anchor
##   and a rock anchor can legally land on the same column or adjacent ones, because the two
##   passes draw from independent streams (`SALT_TREES` vs `SALT_PROPS`) over the same cell
##   grid. If it turns out to matter visually, that is a later brick's problem.
## - **A `VoxelGenerator` write, or any voxel touched at all.** Still nothing in the project
##   writes a voxel.
##
## Contract: `docs/world-generation.md` §27.

var _decoration: DecorationMask
var _surface: SurfaceMaterial
var _biomes: BiomeRegistry


func _init(p_decoration: DecorationMask, p_surface: SurfaceMaterial,
		p_biomes: BiomeRegistry) -> void:
	_decoration = p_decoration
	_surface = p_surface
	_biomes = p_biomes


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds rock masking to one world and one loaded content set, or returns null (logged) when
## any piece underneath cannot be built. **The supported entry point.**
##
## Builds its own `DecorationMask` and `SurfaceMaterial` — `TreeMask.for_world()`'s own
## recurring reason: each is stateless and small, and a shared instance would be a second way
## for two passes to disagree about which world they are generating. Unlike `TreeMask`, no
## `SnowlineMaterial` is built (see the class comment).
static func for_world(p_hash: GenerationHash, p_biomes: BiomeRegistry,
		p_blocks: BlockRegistry) -> RockMask:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build rock masking without a world binding"):
		return null
	if not Log.check(p_biomes != null and p_biomes.is_locked(), Log.CH_GEN,
			"rock masking needs a locked biome registry"):
		return null
	var bound_decoration := DecorationMask.for_world(p_hash, p_biomes, p_blocks)
	if bound_decoration == null:
		return null
	var bound_surface := SurfaceMaterial.for_world(p_hash, p_biomes, p_blocks)
	if bound_surface == null:
		return null
	return RockMask.new(bound_decoration, bound_surface, p_biomes)


# ---------------------------------------------------------------------------
# Density
# ---------------------------------------------------------------------------

## The cell pitch `column` scatters rocks at, from whichever biome `SurfaceMaterial.
## biome_id_at()` already settled on there — `0` (`DecorationMask.spacing_for_density()`'s own
## "disabled" value) for a biome with no props. A missing biome record logs and reads as `0`
## rather than crashing, `TreeMask.spacing_at()`'s own missing-record handling.
func spacing_at(column: Vector2i) -> int:
	var id := _surface.biome_id_at(column)
	var biome: BiomeDefinition = _biomes.get_biome(id)
	if biome == null:
		Log.error(Log.CH_GEN, "rock mask: winning biome has no record",
				{"id": id, "column": column})
		return 0
	return DecorationMask.spacing_for_density(biome.prop_density)


# ---------------------------------------------------------------------------
# The combination
# ---------------------------------------------------------------------------

## True where a rock stands at `column`: the biome's own density picks a candidate cell
## pitch, and `DecorationMask` picks the one eligible anchor per cell at that pitch, at
## `WorldHash.SALT_PROPS`. No altitude exclusion — see the class comment for why a rock line
## is not a tree line.
func is_rock_at(column: Vector2i) -> bool:
	var spacing := spacing_at(column)
	if spacing <= 0:
		return false
	return _decoration.is_decoration_anchor_at(column, spacing, WorldHash.SALT_PROPS)


## The same answer at a voxel. Y is dropped, exactly as `TreeMask.is_tree_at_voxel()` drops
## it: a rock stands on a column, not at a height.
func is_rock_at_voxel(voxel: Vector3i) -> bool:
	return is_rock_at(GenerationGrid.voxel_to_column(voxel))


# ---------------------------------------------------------------------------
# Shape of the pass
# ---------------------------------------------------------------------------

## The decoration mask underneath, for a consumer that wants the unmasked eligibility answer
## directly. Read-only by convention.
func decoration() -> DecorationMask:
	return _decoration


## The surface material underneath, for a consumer that wants the winning biome id directly
## rather than through `spacing_at()`.
func surface() -> SurfaceMaterial:
	return _surface


## The biome catalog underneath, for a consumer that wants a density directly.
func biomes() -> BiomeRegistry:
	return _biomes
