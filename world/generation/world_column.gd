class_name WorldColumn
extends RefCounted
## One world column, resolved once (backlog brick 091b).
##
## Every Phase D pass answers a question about a *column* — where the ground is, whether a
## structure stands on it — and `WorldGenerator` fills a 16-voxel-tall stack of voxels per
## column. Asking those questions per voxel runs the whole `Continentalness ->
## ElevationField -> ErosionPass -> TerracePass -> RiverPass -> LakePass` chain sixteen times
## for one answer, plus `StructureGenerator.site_for_column()`'s nine-region scan sixteen times
## on top of it. That is not a theoretical cost: measured at this brick, the first draft spent
## **~2 s per 16³ chunk** doing exactly that, because `SubsurfaceMaterial` and `CaveCarving`
## each re-derived the surface height for every voxel they were asked about.
##
## This record is the per-chunk cache §30.5 named in advance ("the fix is a per-chunk or
## per-thread cache owned by the caller") — resolved once in `WorldGenerator.column_at()`, then
## read for every voxel in the stack, and handed to the resolved-input forms
## (`SubsurfaceMaterial.block_id_for_depth()`, `CaveCarving.is_hollow_for()`,
## `StructureGenerator.surface_y_for()`/`part_of()`) so no pass underneath recomputes it.
##
## It is a plain value record, `StructureSite`'s own shape (091, §30.2): fields, derived
## helpers, `validate()`, no behavior of its own. Nothing here samples noise; everything here
## was already decided by the pass that produced it.
##
## ```text
## ground_y   the top solid voxel plane, after river/lake carving and structure levelling
## terrace_y  the raw terraced surface underneath all of that
## site       the structure whose ground pad covers this column, or null
## ```
##
## ## Why both heights are kept
##
## Two different questions read two different surfaces, and conflating them is a real bug
## rather than a nicety.
##
## **Depth reads `ground_y`.** `RiverPass`/`LakePass` cut whole risers out of a channel
## (081/082, §20.5) and `StructureGenerator` levels a building pad in both directions (091,
## §30.4), so the topsoil band has to follow the surface those passes actually produced.
## Measuring depth from `terrace_y` instead would put topsoil at the wrong height in a river
## bed and — where a pad was *filled* — would report "above the surface" for voxels that are
## solid ground, punching a hole straight through a structure's own plinth.
##
## **Caves read `terrace_y`.** `CaveMask` is a 3D field in absolute world space (§16); shifting
## its clip with the ground would move a cavern rather than move the ground above it. Keeping
## the raw terraced surface here is also the safer answer where a pad was filled:
## `is_hollow_for()` is false at or above the surface it is given, so newly filled ground can
## never come back carved.
##
## Neither pass had to change its own rule for this — both grew a resolved-input form that
## takes the number the caller already has, the same shape `StructureGenerator.part_of()` and
## `falloff_for()` established at 091.
##
## Contract: `docs/world-generation.md` §31.

## The world column this record answers for.
var column: Vector2i

## The top solid voxel plane: the highest Y this column's terrain fills. Always an exact
## multiple of `TerracePass.TERRACE_HEIGHT_VOXELS` — every term that produced it is (the
## terrace plane itself, `RiverPass`/`LakePass`'s whole-riser cuts, and
## `StructureGenerator.surface_y_for()`'s terraced blend).
var ground_y: int

## `TerracePass.surface_y(column)`: the raw terraced surface, before any pass moved it. Equal
## to `ground_y` for the overwhelming majority of the world. See the class comment for what
## reads which.
var terrace_y: int

## The structure whose ground pad covers this column, or `null` — `StructureGenerator
## .site_for_column()`'s answer, resolved once. At most one can cover a column (§30.5).
var site: StructureSite


func _init(p_column: Vector2i, p_ground_y: int, p_terrace_y: int,
		p_site: StructureSite = null) -> void:
	column = p_column
	ground_y = p_ground_y
	terrace_y = p_terrace_y
	site = p_site


# ---------------------------------------------------------------------------
# Derived
# ---------------------------------------------------------------------------

## True where a structure's ground pad covers this column. Not the same as "a structure block
## stands here": the pad is `GROUND_PAD_VOXELS` wider than the footprint, and most pad columns
## carry only levelled ground.
func has_structure() -> bool:
	return site != null


## The highest voxel this column can possibly occupy — the early-out bound a chunk fill uses to
## skip a whole 16-voxel stack of sky without asking about a single voxel.
##
## A deliberate over-estimate where a site is present: `StructureSite.top_y()` is the wall
## crown over the *footprint*, and an apron column never reaches it. Over-estimating costs one
## skipped early-out; under-estimating would silently clip a wall, so the bound errs the only
## direction that cannot produce a wrong voxel.
func top_y() -> int:
	if site == null:
		return ground_y
	return maxi(ground_y, site.top_y())


## How far below this column's real ground the voxel at `y` sits: `1` for the voxel directly
## under the surface, `0` at it, negative above. The number
## `SubsurfaceMaterial.block_id_for_depth()` takes.
func depth_at(y: int) -> int:
	return ground_y - y


## How far river/lake carving and structure levelling together moved this column's ground away
## from the raw terrace plane: negative where they cut, positive where a pad was filled, `0`
## almost everywhere. Not read by the fill loop — the term a debug overlay and this brick's own
## tests want.
func ground_shift() -> int:
	return ground_y - terrace_y


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

## Empty string when this record is internally consistent, otherwise the reason.
##
## Structural only, `StructureSite.validate()`'s own scope: it cannot re-derive the noise chain
## that produced these heights, so it checks the relationships a caller could get wrong when
## assembling one by hand — both surfaces sit on terrace planes, and a site that is present
## really does cover this column.
func validate() -> String:
	if ground_y % TerracePass.TERRACE_HEIGHT_VOXELS != 0:
		return "ground_y (%d) at %s is not a terrace plane" % [ground_y, column]
	if terrace_y % TerracePass.TERRACE_HEIGHT_VOXELS != 0:
		return "terrace_y (%d) at %s is not a terrace plane" % [terrace_y, column]
	if site != null:
		var pad_radius := site.half_extent_voxels + StructureGenerator.GROUND_PAD_VOXELS
		if site.distance_to_column(column) > pad_radius:
			return "site %s does not cover column %s" % [site.anchor_column, column]
	else:
		# With no pad, only river and lake carving can move the ground, and both only ever cut,
		# by one whole riser each (§20.5/§21).
		var deepest_carve := RiverPass.CARVE_DEPTH_VOXELS + LakePass.CARVE_DEPTH_VOXELS
		if ground_shift() > 0 or ground_shift() < -deepest_carve:
			return ("column %s has no structure, so its ground (%d) cannot leave the terrace "
					+ "plane (%d) by %d voxels") % [column, ground_y, terrace_y, ground_shift()]
	return ""


func _to_string() -> String:
	var structure := ""
	if site != null:
		structure = ", structure @ %s" % site.anchor_column
	return "WorldColumn(%s, ground_y=%d, terrace_y=%d%s)" % [
			column, ground_y, terrace_y, structure]
