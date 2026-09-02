class_name TreeMask
extends RefCounted
## Which columns grow a tree, and how densely per biome (backlog brick 087).
##
## `DecorationMask` (086) already answers "is there room for *any* decoration here" as a
## pure function of a column's own coordinates, deliberately blind to biome or climate —
## §25.4/§25.8 of its own class comment name both as open questions left for whichever
## brick first needs an answer. This is that brick: a candidate density that differs by
## biome (a forest stands thick, a desert stands bare) and one more exclusion
## `DecorationMask` was explicitly told not to make on its own (a snow-capped column, §25.8's
## "reading `SnowlineMaterial`" line), composed into a single `is_tree_at(column) -> bool`.
##
## ```gdscript
## var trees := TreeMask.for_world(hash, biomes, blocks)
## if trees.is_tree_at(column):
##     _place_tree(column)
## ```
##
## ## Density comes from the biome the ground already agreed on
##
## `BiomeDefinition.vegetation_density` (this brick's own field, see its class comment) is
## read through `SurfaceMaterial.biome_id_at(column)` — the same dithered biome pick
## `SubsurfaceMaterial` (076) already reads rather than rolling a second, independent one —
## so a column's tree density always agrees with whichever biome's ground it is actually
## standing on, including the salt-and-pepper columns near a biome edge that dither to their
## neighbor's block. Reading `BiomeClassifier.at()` directly instead would let a column grow
## its neighbor's grass while spacing its trees by its own biome's density, two decisions
## about the same edge disagreeing with each other for no reason.
##
## ## The spacing check runs first, and it is the cheap gate `CaveCarving`'s own ordering
## argument asks for
##
## Three biomes ship `vegetation_density = 0.0` (`desert`, `snow`, `mountain`) —
## `DecorationMask.spacing_for_density()`'s own "disabled" value, returning `0`. `is_tree_at()`
## checks that first: a `0` spacing short-circuits before `SnowlineMaterial` or
## `DecorationMask.is_decoration_anchor_at()` ever run, exactly `CaveCarving.is_hollow_at()`'s
## reason (078) for testing the cheap gate before the expensive one — half of every column in
## the world reads a bare biome and never touches either.
##
## ## Snow cover excludes trees, and this is the brick that decides it
##
## `DecorationMask`'s own class comment left this open on purpose: "frost cover is a
## per-biome ground question, not a 'can anything stand here' question, and this file has no
## more business deciding it than `ShorelineMaterial` had deciding surface material." A tree
## mask is exactly the biome-aware layer that question was deferred to. `SnowlineMaterial.
## is_snow_covered_at()` (085) already knows a column stands high and cold enough to be
## capped regardless of biome; a forest column under that cap grows no tree, the same way a
## real treeline stops before a cold enough summit. Checked *after* the density gate (a
## `TerracePass`/`TemperatureField` read is not free either, but every biome-zero column
## skips it entirely) and *before* the anchor draw, so a snow-capped forest column never
## reaches `DecorationMask` at all — no wasted hash, and no anchor "reserved" at a column
## this file is about to refuse anyway.
##
## ## What this brick does not decide
##
## - **Ruggedness.** `ErosionPass.ruggedness_at()` is never read here. `DecorationMask`'s own
##   §25.4/§25.8 named this as open for 087 *or* 088; this file settles it for trees the
##   smaller way — `RUGGEDNESS_MOUNTAIN` already routes a rugged column to `biome.mountain`,
##   whose own shipped density is `0.0`, so a genuinely rugged column is already bare through
##   the biome it classifies into, with no second gate needed. A column rugged enough to
##   dither *toward* `mountain` at an edge without crossing the classifier's own threshold is
##   deliberately left alone — the same salt-and-pepper edge `SurfaceMaterial`'s dither
##   already treats as a real mix of two biomes, not a bug to patch around here.
## - **Cross-pass exclusion with `RockMask` (088, not yet built).** `DecorationMask`'s own
##   §25.8 line stands unchanged: a tree anchor and a rock anchor can legally land on the
##   same column, or adjacent ones, because the two passes read different salts
##   (`WorldHash.SALT_TREES` here, `WorldHash.SALT_PROPS` reserved for 088) over the same
##   cell grid.
## - **A `VoxelGenerator` write, or any voxel touched at all.** Still nothing in the project
##   writes a voxel; this brick only decides which columns are candidates.
##
## Contract: `docs/world-generation.md` §26.

var _decoration: DecorationMask
var _surface: SurfaceMaterial
var _snowline: SnowlineMaterial
var _biomes: BiomeRegistry


func _init(p_decoration: DecorationMask, p_surface: SurfaceMaterial,
		p_snowline: SnowlineMaterial, p_biomes: BiomeRegistry) -> void:
	_decoration = p_decoration
	_surface = p_surface
	_snowline = p_snowline
	_biomes = p_biomes


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds tree masking to one world and one loaded content set, or returns null (logged) when
## any piece underneath cannot be built. **The supported entry point.**
##
## Builds its own `DecorationMask`, `SurfaceMaterial` and `SnowlineMaterial` —
## `SnowlineMaterial.for_world()`'s own recurring reason: every one is stateless and small,
## and a shared instance would be a second way for two passes to disagree about which world
## they are generating.
static func for_world(p_hash: GenerationHash, p_biomes: BiomeRegistry,
		p_blocks: BlockRegistry) -> TreeMask:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build tree masking without a world binding"):
		return null
	if not Log.check(p_biomes != null and p_biomes.is_locked(), Log.CH_GEN,
			"tree masking needs a locked biome registry"):
		return null
	var bound_decoration := DecorationMask.for_world(p_hash, p_biomes, p_blocks)
	if bound_decoration == null:
		return null
	var bound_surface := SurfaceMaterial.for_world(p_hash, p_biomes, p_blocks)
	if bound_surface == null:
		return null
	var bound_snowline := SnowlineMaterial.for_world(p_hash, p_biomes, p_blocks)
	if bound_snowline == null:
		return null
	return TreeMask.new(bound_decoration, bound_surface, bound_snowline, p_biomes)


# ---------------------------------------------------------------------------
# Density
# ---------------------------------------------------------------------------

## The cell pitch `column` grows trees at, from whichever biome `SurfaceMaterial.
## biome_id_at()` already settled on there — `0` (`DecorationMask.spacing_for_density()`'s
## own "disabled" value) for a biome with no vegetation. A missing biome record logs and
## reads as `0` rather than crashing, `SurfaceMaterial.block_id_at()`'s own missing-record
## handling.
func spacing_at(column: Vector2i) -> int:
	var id := _surface.biome_id_at(column)
	var biome: BiomeDefinition = _biomes.get_biome(id)
	if biome == null:
		Log.error(Log.CH_GEN, "tree mask: winning biome has no record",
				{"id": id, "column": column})
		return 0
	return DecorationMask.spacing_for_density(biome.vegetation_density)


# ---------------------------------------------------------------------------
# The combination
# ---------------------------------------------------------------------------

## True where a tree stands at `column`: the biome's own density picks a candidate cell
## pitch, a column above the frost line never qualifies, and `DecorationMask` picks the one
## eligible anchor per cell at that pitch. See the class comment for why the checks run in
## this order.
func is_tree_at(column: Vector2i) -> bool:
	var spacing := spacing_at(column)
	if spacing <= 0:
		return false
	if _snowline.is_snow_covered_at(column):
		return false
	return _decoration.is_decoration_anchor_at(column, spacing, WorldHash.SALT_TREES)


## The same answer at a voxel. Y is dropped, exactly as `DecorationMask.
## is_eligible_at_voxel()` drops it: a tree stands on a column, not at a height.
func is_tree_at_voxel(voxel: Vector3i) -> bool:
	return is_tree_at(GenerationGrid.voxel_to_column(voxel))


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


## The snowline pass underneath, for a consumer that wants the altitude exclusion on its own
## terms.
func snowline() -> SnowlineMaterial:
	return _snowline


## The biome catalog underneath, for a consumer that wants a density directly.
func biomes() -> BiomeRegistry:
	return _biomes
