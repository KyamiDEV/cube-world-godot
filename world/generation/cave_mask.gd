class_name CaveMask
extends RefCounted
## Where the underground is hollow, independent of what stands above it (backlog brick 077).
##
## Every pass before this one either shapes the ground (`ElevationField`, `ErosionPass`,
## `TerracePass`) or decides what the ground is made of (`SurfaceMaterial`,
## `SubsurfaceMaterial`). This is neither. A cave is a *hollow*, not a height and not a
## material choice, so it is answered by its own 3D field rather than by reading either —
## `TerracePass` says where the ground's surface is, `SubsurfaceMaterial` says what fills
## it, and this file says which of those filled voxels are actually air. Brick 078 is what
## combines the three: it carves only where this mask says hollow **and** `TerracePass`
## says the voxel is underground, so a mask value at, say, y = +800 never surfaces as a
## hole in the sky — that clip belongs to the carving pass, not to this one.
##
## ```gdscript
## var caves := CaveMask.for_world(GenerationHash.for_world(world_seed))
## if caves.is_cave_at(voxel):
##     ...   # brick 078 clips this against the terraced surface before carving
## ```
##
## One `ValueNoise.value301()` layer, thresholded:
##
## ```text
## is_cave_at(voxel) = density_at(voxel) < DENSITY_THRESHOLD
## density_at(voxel)  = noise.value301(voxel)                          # [0, 1]
## ```
##
## Three decisions worth keeping:
##
## 1. **A threshold on a 3D field, not domain warping or a ridged variant.** Worm-like
##    tunnels are a real cave shape, but they need a second noise call bent through the
##    first (domain warping) or a `1 - |value|` ridge remap — both real techniques and
##    neither this brick's, matching `Continentalness`' own restraint (§5.6). A thresholded
##    blob field gives connected caverns rather than tunnels, which is a smaller, honest
##    first cut; a worm-shaped brick can revisit this file without changing its contract.
## 2. **The threshold is a round number, and the fraction it selects is measured rather
##    than aimed at.** `DENSITY_THRESHOLD = 0.25`, a quarter of the field's own `[0, 1]`
##    range — the same style of round fraction `ElevationField.SHORE_MIDPOINT`/
##    `SHORE_WIDTH` use. What it actually selects is **not** a quarter of the world:
##    3D trilinear interpolation blends eight independent corners per octave against value
##    noise's four, so the summed field concentrates far more tightly around its own mean
##    than any 2D layer in this project — measured `mean 0.499`, `sd 0.150` at these exact
##    constants (`CELL_SIZE_VOXELS`, `OCTAVES`, `GAIN`) over a 13824-voxel sweep spaced just
##    under the coarsest cell, on each of four fixture-style seeds, against a comparable
##    fade-shaped 2D field's `sd ~0.28 – 0.32` (`docs/world-generation.md` §10.4). At `0.25`
##    that puts **4.1% – 4.3%** of raw 3D space below
##    threshold, consistent across every seed measured. That is a property of being a 3D
##    field, not a bug to correct — caves are meant to be rare and worth finding, not the
##    majority of the underground, and the measured fraction already reads that way before
##    078 clips it down further to the ground that is actually underground.
## 3. **The scale mirrors `ElevationField`'s relief, deliberately in the other direction.**
##    `ErosionPass.RUGGEDNESS_CELL_SIZE_VOXELS` sits *eight times coarser* than
##    `ElevationField.RELIEF_CELL_SIZE_VOXELS` because it decides *where* relief may exist,
##    a coarser question than the relief itself. `CELL_SIZE_VOXELS` here sits **eight times
##    finer** (`1024 / 8 = 128`) because a cave system is a smaller thing than a mountain
##    range, and the finest cave cell (`finest_cell_size_voxels()`, 16 voxels = 8 m) is
##    **half** of `ElevationField`'s own finest relief cell (32) — the same "half, not the
##    whole" legibility argument bricks 074 and 076 already used, here so the smallest cave
##    detail resolves finer than the smallest hill the ground itself carries.
##
## No dependency on `TerracePass`, `SurfaceMaterial` or `SubsurfaceMaterial` anywhere in
## this file — see item 3 of the class comment above, and `nextsteps.md`'s note carried
## into this brick: a mask that read the surface would be answering "is this underground"
## as well as "is this hollow", conflating two questions brick 078 needs to ask separately.
##
## Contract: `docs/world-generation.md` §16.

## Cell edge of the coarsest cave octave, in voxels: 64 m — an eighth of
## `ElevationField.RELIEF_CELL_SIZE_VOXELS` (item 3 above).
##
## A literal, not `ElevationField.RELIEF_CELL_SIZE_VOXELS / 8`: GDScript's
## warnings-as-errors flags integer division even where the result is exact, matching
## `generation_grid.gd`'s `floor_div()` precedent. The relationship is still asserted at
## runtime in `self_check()` rather than trusted from the comment, `SubsurfaceMaterial`'s
## exact precedent for the same constraint.
const CELL_SIZE_VOXELS := 128

## Layers of cave noise summed. Four takes the finest octave to `128 >> 3` = 16 voxels,
## half of `ElevationField`'s own finest relief cell (item 3 above).
const OCTAVES := 4

## Amplitude ratio between one cave octave and the next: the conventional half, matching
## every other layer in the project.
const GAIN := 0.5

## Below this, `density_at()` reads as hollow. A round quarter of the field's own `[0, 1]`
## range; what fraction of space that actually selects is measured, not implied by the
## number — item 2 of the class comment.
const DENSITY_THRESHOLD := 0.25

var _density: ValueNoise


func _init(p_density: ValueNoise) -> void:
	_density = p_density


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds the mask to one world, or returns null (logged) when the binding is missing or
## the layer underneath it cannot be built. **The supported entry point.**
static func for_world(p_hash: GenerationHash) -> CaveMask:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build the cave mask without a world binding"):
		return null
	var layer := ValueNoise.layer(p_hash, CELL_SIZE_VOXELS, OCTAVES, GAIN, WorldHash.SALT_CAVES)
	if layer == null:
		return null
	return CaveMask.new(layer)


# ---------------------------------------------------------------------------
# Sampling
# ---------------------------------------------------------------------------

## The raw noise density at a voxel, in `[0, 1]`. Pure: same voxel, same answer, whatever
## else was sampled first — the same determinism contract every Phase D pass owes
## (`CLAUDE.md` §1).
func density_at(voxel: Vector3i) -> float:
	return _density.value301(voxel)


## True where the voxel is hollow. The mask's whole answer — everything else in this file
## is either how that answer is computed or how it is inspected.
func is_cave_at(voxel: Vector3i) -> bool:
	return density_at(voxel) < DENSITY_THRESHOLD


# ---------------------------------------------------------------------------
# Shape of the pass
# ---------------------------------------------------------------------------

## The layer underneath, for a debug probe or a pass that wants a single octave of it.
func density_noise() -> ValueNoise:
	return _density


## Cell edge of the finest cave octave, in voxels — the smallest cave feature this mask can
## carry on its own; 078's carving still clips against a solid neighbour, so a real passage
## reads narrower than this in practice.
func finest_cell_size_voxels() -> int:
	return _density.finest_cell_size()


# ---------------------------------------------------------------------------
# Self-check
# ---------------------------------------------------------------------------

## Empty string when the constants above still hold the relationships item 3 of the class
## comment claims, otherwise the reason. `CELL_SIZE_VOXELS` and `OCTAVES` are literals
## (integer division cannot sit in a `const` expression, see `CELL_SIZE_VOXELS`'s own
## comment), so nothing else asserts this on their behalf.
static func self_check() -> String:
	if CELL_SIZE_VOXELS * 8 != ElevationField.RELIEF_CELL_SIZE_VOXELS:
		return "CELL_SIZE_VOXELS (%d) is no longer an eighth of RELIEF_CELL_SIZE_VOXELS (%d)" % [
				CELL_SIZE_VOXELS, ElevationField.RELIEF_CELL_SIZE_VOXELS]
	var finest := CELL_SIZE_VOXELS >> (OCTAVES - 1)
	var relief_finest := (ElevationField.RELIEF_CELL_SIZE_VOXELS
			>> (ElevationField.RELIEF_OCTAVES - 1))
	if finest * 2 != relief_finest:
		return "finest cave cell (%d) is no longer half the finest relief cell (%d)" % [
				finest, relief_finest]
	return ""
