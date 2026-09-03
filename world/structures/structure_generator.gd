class_name StructureGenerator
extends RefCounted
## What a placed structure actually *is*: its footprint, its blocks, and the levelled ground
## it stands on (backlog brick 091).
##
## The last three bricks each answered one question and deliberately refused the next.
## `StructureSeedField` (089) reserves one candidate per region and reads no terrain.
## `StructurePlacement` (090) decides which candidates are real and explicitly leaves "what a
## structure is — no kind list, no footprint, no mesh" and "terrace / erosion flattening under
## a placed structure" to this brick (`docs/world-generation.md` §29.8). This file is both of
## those answers.
##
## ```gdscript
## var structures := StructureGenerator.for_world(hash, biomes, blocks)
## var ground := structures.surface_y_at(column)          # levelled where a structure stands
## var id := structures.block_id_at(voxel)                # "" where the structure places nothing
## ```
##
## ## Three things this pass produces
##
## | Question | Answer |
## |---|---|
## | **where and how big** | `site_at(region)` → a `StructureSite`: the placed candidate's own stream resolved into a centred odd square footprint and a wall height, on the terrace plane at its anchor |
## | **what the ground does** | `ground_falloff_at()` / `surface_y_at()` — the `World::objectFalloffWeight` / `World::falloffSquared` levelling 090 deferred here |
## | **what the structure is made of** | `part_at()` / `block_id_at()` / `clears_terrain_at()` — a stone floor slab and a wall ring, with a hollow interior |
##
## ## The initial structure is a walled plinth, and that is the whole point of "initial"
##
## Backlog 091 is the *initial* structure generator; 092 is a house, 093 a village, 094 a
## dungeon. So the shape here is the smallest thing that reads as **built rather than
## grown** — a solid floor slab with a wall ring around it — and its parts (`FLOOR`, `WALL`,
## `INTERIOR`) are exactly the vocabulary a house extends with a roof and a doorway. No kind
## list is invented here for kinds that do not exist yet: 092 adds the second kind and the
## draw that chooses between them, appended to the end of the site stream (§28.4).
##
## ## The ground falloff is applied *above* `TerracePass`, not inside the erosion product
##
## `docs/world-generation.md` §7.1 files "structure falloff" as one more `[0, 1]` factor in
## `ErosionPass`'s relief product, and the reference's `objectFalloffWeight` is exactly that.
## It cannot go there, and the reason is a dependency cycle rather than a preference:
## `StructurePlacement`'s slope gate reads `TerracePass`, which reads `ErosionPass`, so an
## `ErosionPass` that read placement would have to know where structures are before deciding
## whether their ground is buildable. The levelling is therefore a pass **over**
## `TerracePass.surface_y()`, and `surface_y_at()` is the ground height every later consumer
## should read instead.
##
## Two consequences worth stating plainly:
##
## 1. **It levels in both directions.** Every §7.1 pass only ever lowers ground; this one both
##    cuts and fills, because a building pad that could only cut would leave a structure on
##    the high side of a step hanging over air. It is not a member of that family and does not
##    claim the family's invariant.
## 2. **It is bounded by one terrace anyway.** 090's slope gate already refused every anchor
##    whose terraced surface spans more than `MAX_SITE_RELIEF_VOXELS` (one terrace) across a
##    16-voxel pad, and `self_check()` asserts this pass's own pad is no wider than that one.
##    So the levelling moves ground by at most a single 4 m terrace, never carving a plateau
##    out of a mountainside.
##
## ## Cost, and why there is no cache
##
## `site_for_column()` scans the 3×3 region neighbourhood, but only reaches
## `StructurePlacement.is_placed_at()` for a region whose *candidate anchor* is already within
## pad range — normally none, so the common case is nine cheap `StructureSeedField` lookups.
## No memoization: voxel generation runs on Voxel Tools worker threads, and a mutable cache on
## a shared pass object is a data race, not an optimisation. `CLAUDE.md` §8's "profile before
## optimizing" applies — if this shows up in a Phase L profile, the fix is a per-thread or
## per-chunk cache owned by the caller, not hidden state here.
##
## ## Not a generation version bump
##
## The boundary every Phase D brick since 062 has named still holds: **nothing in this project
## writes a voxel yet.** This file mixes no new `WorldHash` salt and adds no new
## `GenerationHash.Space` — the site draws fork `StructureSeed.rng()` with a fixed string key,
## the shape 090's presence roll already established. Every constant here joins 089's and
## 090's as a pinned generation input the moment a `VoxelGenerator` first writes a
## `VoxelBuffer` from it. `docs/world-generation.md` §30.7.
##
## Contract: `docs/world-generation.md` §30. Reference: `docs/reference/matrix-world.md` §2
## (`World::objectFalloffWeight`, `World::falloffSquared`),
## `docs/reference/terrain-base-height-field.md` §3 claim 6. Confidence MEDIUM — no helper
## body was opened; the shapes are `matrix-world.md` §2's one-line index.

## What a structure puts at a voxel.
##
## `INTERIOR` is not `NONE`: the inside of a walled plinth is air the generator must *clear*,
## even where the natural ground would have filled it. `clears_terrain_at()` is that
## distinction, and it is the one a `VoxelGenerator` has to respect to avoid burying its own
## structures.
enum Part {
	NONE,      ## The structure has nothing to say about this voxel.
	FLOOR,     ## The floor slab, at `StructureSite.base_y` across the whole footprint.
	WALL,      ## The wall ring, the outermost footprint band above the floor.
	INTERIOR,  ## Enclosed air: inside the walls, above the floor.
}

## The block every part of the initial structure is built from. One id, not a per-part table:
## the block set ships grass, dirt, stone, sand and snow (038, 084, 085), and stone is the only
## one of them that reads as masonry. 092's house is where a second material earns its place.
const STRUCTURE_BLOCK_ID := "block.stone"

## Bounds of the footprint half-extent draw, in voxels. `4 .. 8` gives a square 9 to 17 voxels
## (4.5 to 8.5 m) on a side — a room, not a monument, and comfortably inside the 16-voxel pad
## `StructurePlacement`'s slope gate already verified is level (`self_check()` asserts it).
const MIN_HALF_EXTENT_VOXELS := 4
const MAX_HALF_EXTENT_VOXELS := 8

## Bounds of the wall height draw, in voxels above the floor: `5 .. 9` = 2.5 to 4.5 m, so the
## walls always clear a player and never quite reach a full second terrace.
const MIN_WALL_HEIGHT_VOXELS := 5
const MAX_WALL_HEIGHT_VOXELS := 9

## How far beyond the footprint the ground levelling blends back to natural terrain, in
## voxels: 8 = 4 m of apron. Together with `MAX_HALF_EXTENT_VOXELS` this is the widest the
## pass ever touches, and `self_check()` holds that sum at or below
## `StructurePlacement.SITE_PROBE_RADIUS_VOXELS`.
const GROUND_PAD_VOXELS := 8

## Fixed key the site draws fork `StructureSeed.rng()` with. A string, not a `WorldHash.SALT_*`
## value, for 090's own reason: the fork is over 089's owned sub-seed stream rather than a
## `GenerationHash` space, so it uses `DeterministicRng.derive_named()`. Forking rather than
## drawing from `rng()` directly is what lets 090's presence roll, this brick's site draws and
## 092's future kind draws coexist without any of them shifting the others.
const _SITE_STREAM_KEY := "structure.site"

## The 3×3 block of regions `site_for_column()` scans. Complete because the widest pad
## (`MAX_HALF_EXTENT_VOXELS + GROUND_PAD_VOXELS`) is far below `GenerationGrid
## .REGION_SIZE_VOXELS`, so a column can only be reached by an anchor in its own region or an
## immediate neighbour — `self_check()` asserts the bound.
const _NEIGHBORHOOD_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var _placement: StructurePlacement
var _terrace: TerracePass
var _blocks: BlockRegistry


func _init(p_placement: StructurePlacement, p_terrace: TerracePass,
		p_blocks: BlockRegistry) -> void:
	_placement = p_placement
	_terrace = p_terrace
	_blocks = p_blocks


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds structure generation to one world and one loaded content set, or returns null
## (logged) when any piece underneath cannot be built or the block set has no masonry block.
## **The supported entry point.**
##
## Reuses `StructurePlacement`'s own `TerracePass` rather than building a second one: 090
## already built it, this pass must agree with the slope gate about where the ground is, and a
## second instance would be a second way for the two to disagree. That is the same reasoning
## every `for_world()` since 062 gives for *not* sharing — applied the other way round,
## because here the two passes are answering about the same site rather than about the same
## world.
static func for_world(p_hash: GenerationHash, p_biomes: BiomeRegistry,
		p_blocks: BlockRegistry) -> StructureGenerator:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build structure generation without a world binding"):
		return null
	if not Log.check(p_blocks != null and p_blocks.is_locked(), Log.CH_GEN,
			"structure generation needs a locked block registry"):
		return null
	var reason := structure_block_reason_for(p_blocks)
	if not Log.check(reason.is_empty(), Log.CH_GEN,
			"structure generation cannot build: %s" % reason):
		return null
	var bound_placement := StructurePlacement.for_world(p_hash, p_biomes, p_blocks)
	if bound_placement == null:
		return null
	return StructureGenerator.new(bound_placement, bound_placement.terrace(), p_blocks)


## Empty string when `blocks` has a record for `STRUCTURE_BLOCK_ID`, otherwise the reason.
##
## Static and registry-taking for `SurfaceMaterial.surface_block_reason_for()`'s own
## reachability reason: a live `StructureGenerator` can only exist once this has passed, so the
## failing branch needs its own caller — a content tool, or this brick's test file.
static func structure_block_reason_for(p_blocks: BlockRegistry) -> String:
	if p_blocks == null:
		return "no block registry"
	if not p_blocks.has_block(STRUCTURE_BLOCK_ID):
		return "the block registry has no record for structure block '%s'" % STRUCTURE_BLOCK_ID
	return ""


# ---------------------------------------------------------------------------
# Sites
# ---------------------------------------------------------------------------

## The resolved structure standing in `region`, or `null` when none does — `StructurePlacement
## .seed_at()` one step further along, with the candidate's stream spent on a footprint and a
## wall height and the terrace plane at the anchor read for the floor.
##
## Pure and order-free: the draws come from a stream owned by the candidate's own sub-seed, so
## resolving one region never shifts another.
func site_at(region: Vector2i) -> StructureSite:
	var candidate := _placement.seed_at(region)
	if candidate == null:
		return null
	return _site_from(candidate)


## The structure whose **ground pad** covers `column`, or `null` when none does.
##
## At most one can: two placed anchors are at least `StructurePlacement
## .MIN_STRUCTURE_SPACING_VOXELS` (768) apart, and a column inside two pads would put their
## anchors within `2 · (MAX_HALF_EXTENT_VOXELS + GROUND_PAD_VOXELS)` = 32 voxels of each other.
## `self_check()` asserts that gap; the first placed match is therefore the only one.
func site_for_column(column: Vector2i) -> StructureSite:
	var region := GenerationGrid.column_to_region(column)
	for offset in _NEIGHBORHOOD_OFFSETS:
		var candidate := _placement.seeds().seed_at(region + offset)
		if candidate == null:
			continue
		# Cheap rejection first: most columns are near no anchor at all, and this skips the
		# 8-neighbour spacing scan `is_placed_at()` would otherwise run nine times.
		if _chebyshev(candidate.anchor_column, column) > MAX_HALF_EXTENT_VOXELS + GROUND_PAD_VOXELS:
			continue
		if not _placement.is_placed_at(candidate.region):
			continue
		var site := _site_from(candidate)
		if _chebyshev(site.anchor_column, column) <= _pad_radius_of(site):
			return site
	return null


## The same lookup at a voxel. Y is dropped: which structure covers a place is a property of
## the column, exactly as `StructurePlacement.seed_for_voxel()` drops it.
func site_for_voxel(voxel: Vector3i) -> StructureSite:
	return site_for_column(GenerationGrid.voxel_to_column(voxel))


# ---------------------------------------------------------------------------
# The ground
# ---------------------------------------------------------------------------

## How much of the *natural* terraced ground survives at `column`, in `[0, 1]` — the
## `objectFalloffWeight` term 090 deferred here.
##
## `0` inside the footprint (the pad is fully levelled to the structure's floor plane), rising
## as `t²` across `GROUND_PAD_VOXELS` of apron, and exactly `1` everywhere else in the world.
## Squared rather than linear for `World::falloffSquared`'s own shape, and for the reason
## §7.2 gives about the ruggedness weight: a squared ramp keeps most of its mass near zero, so
## the pad reads as a deliberate plateau with a soft edge rather than a cone.
func ground_falloff_at(column: Vector2i) -> float:
	var site := site_for_column(column)
	if site == null:
		return 1.0
	return falloff_for(site, _chebyshev(site.anchor_column, column))


## Ground height at `column` after structure levelling, in voxels — **the height a voxel
## generator should fill up to**, and the answer that replaces `TerracePass.surface_y()` for
## every consumer downstream of this pass.
##
## Identical to `TerracePass.surface_y()` wherever no structure stands, which is almost
## everywhere. Inside a pad it is the natural surface pulled toward the site's floor plane by
## `ground_falloff_at()`, then snapped back onto a terrace plane so the block world keeps its
## silhouette: both ends of the blend are already terrace multiples, so the snap only affects
## the apron in between.
func surface_y_at(column: Vector2i) -> int:
	var natural := _terrace.surface_y(column)
	var site := site_for_column(column)
	if site == null:
		return natural
	var weight := falloff_for(site, _chebyshev(site.anchor_column, column))
	if weight >= 1.0:
		return natural
	var blended := float(site.base_y) + weight * float(natural - site.base_y)
	return int(TerracePass.terraced(blended))


## How many voxels the levelling moved the ground at `column`: positive where it cut, negative
## where it filled, `0` everywhere no structure stands. The term a debug overlay wants, and
## the one `test_structure_generator.gd` bounds against 090's slope gate.
func ground_offset_at(column: Vector2i) -> int:
	return surface_y_at(column) - _terrace.surface_y(column)


## The falloff curve on its own, for a site and a Chebyshev distance from its anchor.
##
## Static: the curve is part of the world's definition, and a test that wants to know what
## happens exactly at the footprint edge or exactly at the pad edge should not have to hunt
## the world for a column that happens to sit there — `TerracePass.terraced()`'s own reason
## for being static.
static func falloff_for(site: StructureSite, distance: int) -> float:
	if distance <= site.half_extent_voxels:
		return 0.0
	var pad := site.half_extent_voxels + GROUND_PAD_VOXELS
	if distance >= pad:
		return 1.0
	var t := float(distance - site.half_extent_voxels) / float(GROUND_PAD_VOXELS)
	return t * t


# ---------------------------------------------------------------------------
# The structure itself
# ---------------------------------------------------------------------------

## What the structure puts at `voxel`: `Part.NONE` where none does.
##
## The whole geometry of the initial structure, and deliberately small enough to read at once:
## a solid `FLOOR` slab filling the footprint at `base_y`, a `WALL` ring on the outermost
## footprint band for `wall_height_voxels` above it, and `INTERIOR` air inside that ring.
func part_at(voxel: Vector3i) -> int:
	var column := GenerationGrid.voxel_to_column(voxel)
	var site := site_for_column(column)
	if site == null:
		return Part.NONE
	return part_of(site, voxel)


## The same question against a site already in hand — the form a generator filling one chunk
## wants, because it resolves the site once for the whole column instead of once per voxel.
static func part_of(site: StructureSite, voxel: Vector3i) -> int:
	var column := GenerationGrid.voxel_to_column(voxel)
	if not site.contains_column(column):
		return Part.NONE
	if voxel.y == site.base_y:
		return Part.FLOOR
	if voxel.y > site.base_y and voxel.y <= site.top_y():
		return Part.WALL if site.is_wall_column(column) else Part.INTERIOR
	return Part.NONE


## The block id the structure places at `voxel`, or `""` where it places none — including
## inside the walls, which is air on purpose (`clears_terrain_at()`).
func block_id_at(voxel: Vector3i) -> String:
	var part := part_at(voxel)
	if part == Part.FLOOR or part == Part.WALL:
		return STRUCTURE_BLOCK_ID
	return ""


## True where the structure occupies `voxel` with a solid block.
func is_structure_voxel_at(voxel: Vector3i) -> bool:
	var part := part_at(voxel)
	return part == Part.FLOOR or part == Part.WALL


## True where the structure requires `voxel` to be **air**, whatever the terrain underneath
## would have put there. The enclosed volume above the floor and inside the walls: without
## this a structure dug into a hillside would generate solid.
func clears_terrain_at(voxel: Vector3i) -> bool:
	return part_at(voxel) == Part.INTERIOR


# ---------------------------------------------------------------------------
# Shape of the pass
# ---------------------------------------------------------------------------

## The placement pass underneath, for a consumer that wants the raw gates or the candidate
## seeds. Read-only by convention: none of these objects holds mutable state.
func placement() -> StructurePlacement:
	return _placement


## The terrace pass underneath — the *natural* ground, before levelling. `surface_y_at()` is
## what a generator should fill to; this is what the world would have done without structures.
func terrace() -> TerracePass:
	return _terrace


## The block catalog underneath, for a consumer that wants the structure block's record.
func blocks() -> BlockRegistry:
	return _blocks


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Resolve a placed candidate into a site. The draw order is the contract, exactly as §28.4
## makes 089's draw order one: half extent, then wall height, from a stream forked at
## `_SITE_STREAM_KEY`. Appending a draw later is free; inserting one in the middle resizes
## every structure in the world.
func _site_from(candidate: StructureSeed) -> StructureSite:
	var stream := candidate.rng().derive_named(_SITE_STREAM_KEY)
	var half_extent := stream.next_int(MIN_HALF_EXTENT_VOXELS, MAX_HALF_EXTENT_VOXELS)
	var wall_height := stream.next_int(MIN_WALL_HEIGHT_VOXELS, MAX_WALL_HEIGHT_VOXELS)
	return StructureSite.new(candidate.region, candidate.anchor_column,
			_terrace.surface_y(candidate.anchor_column), half_extent, wall_height,
			candidate.structure_seed)


## How far from its anchor a site still touches the ground.
static func _pad_radius_of(site: StructureSite) -> int:
	return site.half_extent_voxels + GROUND_PAD_VOXELS


## Chebyshev distance between two columns, in voxels — the metric the square footprint and the
## square pad are both made of.
static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	var delta := a - b
	return maxi(absi(delta.x), absi(delta.y))


# ---------------------------------------------------------------------------
# Self-check
# ---------------------------------------------------------------------------

## Empty string when the constants still hold the relationships the class comment relies on,
## otherwise the reason — `StructurePlacement.self_check()`'s own precedent for a derived
## bound asserted rather than trusted.
static func self_check() -> String:
	if MIN_HALF_EXTENT_VOXELS <= 0 or MIN_HALF_EXTENT_VOXELS > MAX_HALF_EXTENT_VOXELS:
		return "half extent bounds %d..%d are not a positive range" % [
				MIN_HALF_EXTENT_VOXELS, MAX_HALF_EXTENT_VOXELS]
	if MIN_WALL_HEIGHT_VOXELS <= 0 or MIN_WALL_HEIGHT_VOXELS > MAX_WALL_HEIGHT_VOXELS:
		return "wall height bounds %d..%d are not a positive range" % [
				MIN_WALL_HEIGHT_VOXELS, MAX_WALL_HEIGHT_VOXELS]
	if GROUND_PAD_VOXELS <= 0:
		return "GROUND_PAD_VOXELS (%d) is not positive" % GROUND_PAD_VOXELS
	var pad_radius := MAX_HALF_EXTENT_VOXELS + GROUND_PAD_VOXELS
	if pad_radius > StructurePlacement.SITE_PROBE_RADIUS_VOXELS:
		return ("the widest ground pad (%d) is wider than the pad 090's slope gate checks "
				+ "(%d); levelling could exceed one terrace") % [
						pad_radius, StructurePlacement.SITE_PROBE_RADIUS_VOXELS]
	if 2 * pad_radius >= StructurePlacement.MIN_STRUCTURE_SPACING_VOXELS:
		return ("two ground pads (%d voxels across) can now overlap within the minimum "
				+ "structure spacing (%d); site_for_column() is no longer single-valued") % [
						2 * pad_radius, StructurePlacement.MIN_STRUCTURE_SPACING_VOXELS]
	if pad_radius >= GenerationGrid.REGION_SIZE_VOXELS:
		return ("the widest ground pad (%d) is not below REGION_SIZE_VOXELS (%d); the 3×3 "
				+ "region scan is no longer complete") % [
						pad_radius, GenerationGrid.REGION_SIZE_VOXELS]
	return ""
