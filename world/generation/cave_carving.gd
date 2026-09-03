class_name CaveCarving
extends RefCounted
## Where a cave is actually allowed to hollow the ground: `CaveMask`'s hollow, clipped to the
## voxels `TerracePass` puts underground (backlog brick 078).
##
## `CaveMask` (077) answers "is this voxel hollow" everywhere in the world, including the
## sky — its own class comment names that as deliberate, and hands the clip to this brick by
## name: "brick 078 is what combines the three [`TerracePass`, `SubsurfaceMaterial`, itself]:
## it carves only where this mask says hollow **and** `TerracePass` says the voxel is
## underground, so a mask value at, say, y = +800 never surfaces as a hole in the sky." This
## file is exactly that clip, and nothing more.
##
## ```gdscript
## var carving := CaveCarving.for_world(GenerationHash.for_world(world_seed))
## if carving.is_hollow_at(voxel):
##     ...   # 079 decides what lines the hollow; this file only says whether one exists here
## ```
##
## One clip, and it is deliberately the whole pass:
##
## ```text
## is_hollow_at(voxel) = voxel.y < TerracePass.surface_y(column(voxel))
##                        and CaveMask.is_cave_at(voxel)
## ```
##
## Four things worth keeping:
##
## 1. **The surface check runs first, and the order is a real cost decision, not style.**
##    `TerracePass.surface_y()` is one division and a floor over an already-built height
##    field; `CaveMask.is_cave_at()` is four octaves of 3D trilinear noise, eight hashed
##    corners each. A voxel above ground never needs the expensive half of this function
##    evaluated at all — every above-ground voxel in the world short-circuits on the cheap
##    check, and `CaveMask.density_at()` is never called there.
## 2. **A strict inequality, matching `SubsurfaceMaterial`'s own boundary (§15's `depth <=
##    0` rule).** `TerracePass.surface_y(column)` names the top **solid** voxel of the
##    ground, not the first voxel of open air above it — the same convention every pass
##    since `TerracePass` itself has read. Carving that voxel away would hollow out the one
##    cell every other pass in the chain agrees is ground; underground starts strictly below
##    it, at `y < surface_y(column)`, which is the same line `SubsurfaceMaterial.
##    block_id_at()` already draws for the same column.
## 3. **A bool, not a block id — and that is the split 079 depends on.** `SurfaceMaterial`
##    and `SubsurfaceMaterial` both answer with a block id because both decide what a voxel
##    is *made of*. This file never has to: hollow-or-not is the whole question `CaveMask`
##    started with, and the backlog row itself calls this brick "carving", not "cave
##    material". Answering with a block id here would force this file to also decide what a
##    non-hollow underground voxel is made of — exactly what 079 ("implement underground
##    material rules") exists to answer next, as its own brick depending on this one rather
##    than folded into it, the same `CaveMask`/`SubsurfaceMaterial` split `nextsteps.md`
##    carried into this brick.
## 4. **No new noise field, no new salt, no new constant.** This is a clip over two existing
##    passes, the same "nothing here for a seed to vary" shape `TerracePass` itself is over
##    `ErosionPass` (§8).
##
## Contract: `docs/world-generation.md` §17.

var _caves: CaveMask
var _terrace: TerracePass


func _init(p_caves: CaveMask, p_terrace: TerracePass) -> void:
	_caves = p_caves
	_terrace = p_terrace


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds carving to one world, or returns null (logged) when the binding is missing or
## either pass underneath it cannot be built. **The supported entry point.**
##
## Builds its own `CaveMask` and `TerracePass`, `TerracePass.for_world()`'s own reason: both
## objects are stateless and small, and a shared instance would be a second way for two
## passes to disagree about which world they are generating.
static func for_world(p_hash: GenerationHash) -> CaveCarving:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build cave carving without a world binding"):
		return null
	var bound_caves := CaveMask.for_world(p_hash)
	if bound_caves == null:
		return null
	var bound_terrace := TerracePass.for_world(p_hash)
	if bound_terrace == null:
		return null
	return CaveCarving.new(bound_caves, bound_terrace)


# ---------------------------------------------------------------------------
# The clip
# ---------------------------------------------------------------------------

## True where `voxel` is both underground (strictly below its column's terraced surface) and
## hollow (`CaveMask.is_cave_at()`) — the only place a cave is actually allowed to carve.
## Pure: same voxel, same answer, whatever else was sampled first (`CLAUDE.md` §1).
func is_hollow_at(voxel: Vector3i) -> bool:
	var column := GenerationGrid.voxel_to_column(voxel)
	return is_hollow_for(voxel, _terrace.surface_y(column))


## The same clip against a surface height already computed — the form a generator filling one
## chunk wants (`StructureGenerator.part_of()`'s own reason, 091b).
##
## `is_hollow_at()` is exactly this with `_terrace.surface_y(column)` as `surface_y`, so the two
## can never disagree; the split exists because a fill loop already knows its column's surface
## and would otherwise re-run the whole height chain once **per voxel** to be told it again.
##
## Note that `surface_y` here is the *terraced* surface, not a ground height some later pass
## moved: 091b passes `WorldColumn.terrace_y`, deliberately keeping caves in absolute world
## space rather than shifting them with a river bed or a levelled building pad (§31.1).
func is_hollow_for(voxel: Vector3i, surface_y: int) -> bool:
	if voxel.y >= surface_y:
		return false
	return _caves.is_cave_at(voxel)


# ---------------------------------------------------------------------------
# Shape of the pass
# ---------------------------------------------------------------------------

## The mask underneath, for a consumer that wants the raw hollow answer with no surface clip.
## Read-only by convention: neither object this file holds is mutable.
func caves() -> CaveMask:
	return _caves


## The terrace pass underneath, for a consumer that wants the surface height directly.
func terrace() -> TerracePass:
	return _terrace
