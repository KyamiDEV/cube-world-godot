class_name StructurePlacement
extends RefCounted
## Whether a structure is actually allowed to stand at a region's candidate anchor
## (backlog brick 090).
##
## `StructureSeedField` (089) reserves **exactly one** `StructureSeed` per in-world region —
## a jittered anchor column plus an owned 64-bit sub-seed — and rolls no presence gate and
## reads no terrain, on purpose: "whether a structure actually stands at the anchor — the
## presence roll, slope/water/biome suitability, spacing to the next structure, the falloff
## weighting `matrix-world.md` §2 records — is entirely brick 090's question"
## (`structure_seed_field.gd` class comment, `docs/world-generation.md` §28.2). This file is
## that question, answered as a single `is_placed_at(region) -> bool`.
##
## ```gdscript
## var placement := StructurePlacement.for_world(hash, biomes, blocks)
## var candidate := placement.seed_at(region)   # null unless a structure stands here
## if candidate != null:
##     _generate_structure(candidate.anchor_column, candidate.rng())   # brick 091
## ```
##
## ## The four gates, and which reference function each stands in for
##
## | Gate | Reference (`matrix-world.md` §2) | This file |
## |---|---|---|
## | **presence** | `World_featureCountRange`, `World_featureTier` — a region holds *0..N* features | one candidate (089's), kept with probability `PRESENCE_CHANCE`, rolled from the candidate's **own** owned stream so 089's region stream and 091's `structure_seed` are both left untouched |
## | **eligible ground** | — | `DecorationMask.is_eligible_at()` (086) at the anchor: not wet, not the beach edge of water — the same exclusion trees (087) and rocks (088) already reuse |
## | **buildable slope** | `World::objectFalloffWeight`, `World::falloffSquared` (the *inverse* — that helper flattens ground *near* a placed structure) | the terraced surface within a small pad of the anchor rises no more than one terrace; steeper ground is refused rather than flattened (flattening is 091's, §28.7) |
## | **spacing** | `World::findNearestFeatureCell` | refused when a higher-priority candidate in one of the 8 neighbouring regions clears its own presence + ground gates within `MIN_STRUCTURE_SPACING_VOXELS` |
##
## ## Biome suitability is not a biome-record read
##
## `nextsteps.md` names "slope/water/**biome** suitability" among 090's job, but this file
## reads no `BiomeDefinition` and adds no field to one — the same call `TreeMask` (§26.6) and
## `RockMask` (§27.3) made about ruggedness. A genuinely unbuildable place is already
## refused: a lake by the eligibility gate, a rugged mountainside by the slope gate. A
## `BiomeDefinition.hosts_structures` flag nothing else reads would be the "record grows,
## nothing reads it" shape brick 067 named five times and bricks 068–073 were folded to
## avoid (`backlog.md`, §13.1). If a later brick finds a biome that is buildable *and* flat
## *and* dry yet should still host nothing, that brick adds the field with its own consumer.
## `docs/world-generation.md` §29.4.
##
## ## The spacing check does not recurse
##
## A candidate at region `R` is refused when a neighbour `R'` within
## `MIN_STRUCTURE_SPACING_VOXELS` *both* clears its own presence + eligibility + slope gates
## *and* out-ranks `R` — where rank is the candidate's own `structure_seed`, tie-broken by
## region coordinates, a total order that does not depend on visit order. The neighbour test
## consults only those local gates, never the spacing gate itself, so there is no mutual
## recursion: exactly the lower-ranked of any two too-close candidates is dropped, and both
## regions agree on which that is.
##
## The 8-neighbour scan is complete because `MIN_STRUCTURE_SPACING_VOXELS` (768) is below
## `GenerationGrid.REGION_SIZE_VOXELS` (1024): two anchors in regions two cells apart are at
## least `2·1024 − 1023 = 1025` voxels apart on that axis, already past the threshold.
## `self_check()` asserts the bound so a later widening of the spacing cannot silently
## outrun the scan.
##
## ## Not a generation version bump
##
## The boundary every Phase D brick since 062 has named: no world has ever had a voxel
## written, so nothing here can contradict one. This file mixes no new `WorldHash` salt and
## no new `GenerationHash.Space` — the presence roll forks `StructureSeed.rng()` (089's
## owned sub-seed) with a fixed string key. `PRESENCE_CHANCE`, `MIN_STRUCTURE_SPACING_VOXELS`,
## the slope thresholds, the neighbour priority order and the fork key all become pinned
## generation inputs the moment brick 091's `VoxelGenerator` reads `is_placed_at()` to place
## a structure — the same "first `VoxelBuffer` write" boundary bricks 075–089 each named.
## `docs/world-generation.md` §29.7.
##
## Contract: `docs/world-generation.md` §29. Reference:
## `docs/reference/matrix-world.md` §2, `docs/reference/region-coordinate-hashing.md`
## (confidence MEDIUM — no helper body was opened; the shapes are `matrix-world.md` §2's
## one-line index and `terrain-base-height-field.md` §3 claim 6).

## Probability that a region's one candidate is kept by the presence roll, before any
## terrain gate. A design choice, not a reference number (`World_featureCountRange`'s own
## range was never read): structures are landmarks, not scenery. Measured placed fraction
## over the fixture sweep, after eligibility/slope/spacing thin it further, is in
## `docs/world-generation.md` §29.5.
const PRESENCE_CHANCE := 0.4

## Half-width of the square pad around the anchor the slope gate probes, in voxels: 16 =
## 8 m, so a 32-voxel / 16 m pad. Deliberately not "the structure's footprint" — 090 has no
## footprint (§28.7) — but the immediate ground a structure of any kind has to sit level on,
## wide enough that a genuine hillside registers across it.
const SITE_PROBE_RADIUS_VOXELS := 16

## The most the terraced surface may rise across the probe pad before the anchor is refused,
## in voxels: one `TerracePass` terrace, 8 = 4 m. `TerracePass.max_riser_voxels()` is exactly
## one terrace, so this admits ground that steps once and refuses ground that steps twice.
const MAX_SITE_RELIEF_VOXELS := TerracePass.TERRACE_HEIGHT_VOXELS

## Minimum distance between two placed structure anchors, in voxels: 768 = 384 m. Below
## `GenerationGrid.REGION_SIZE_VOXELS` so the 8-neighbour spacing scan is provably complete
## (see the class comment); `self_check()` guards the relationship.
const MIN_STRUCTURE_SPACING_VOXELS := 768

## Fixed key the presence roll forks `StructureSeed.rng()` with. A string, not a
## `WorldHash.SALT_*` value: the fork is over 089's owned sub-seed stream, not over a
## `GenerationHash` space, so it uses `DeterministicRng.derive_named()` rather than a salt.
const _PRESENCE_STREAM_KEY := "structure.placement.presence"

## The 8 Moore-neighbour region offsets the spacing scan visits.
const _NEIGHBOR_REGION_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

## The 8 Moore probe offsets for the slope gate, at `SITE_PROBE_RADIUS_VOXELS` — the four
## edges and the four corners of the pad, so a slope on a diagonal is caught too.
const _PROBE_OFFSETS: Array[Vector2i] = [
	Vector2i(SITE_PROBE_RADIUS_VOXELS, 0), Vector2i(-SITE_PROBE_RADIUS_VOXELS, 0),
	Vector2i(0, SITE_PROBE_RADIUS_VOXELS), Vector2i(0, -SITE_PROBE_RADIUS_VOXELS),
	Vector2i(SITE_PROBE_RADIUS_VOXELS, SITE_PROBE_RADIUS_VOXELS),
	Vector2i(SITE_PROBE_RADIUS_VOXELS, -SITE_PROBE_RADIUS_VOXELS),
	Vector2i(-SITE_PROBE_RADIUS_VOXELS, SITE_PROBE_RADIUS_VOXELS),
	Vector2i(-SITE_PROBE_RADIUS_VOXELS, -SITE_PROBE_RADIUS_VOXELS),
]

var _seeds: StructureSeedField
var _decoration: DecorationMask
var _terrace: TerracePass


func _init(p_seeds: StructureSeedField, p_decoration: DecorationMask,
		p_terrace: TerracePass) -> void:
	_seeds = p_seeds
	_decoration = p_decoration
	_terrace = p_terrace


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds structure placement to one world and one loaded content set, or returns null
## (logged) when any piece underneath cannot be built. **The supported entry point.**
##
## Builds its own `StructureSeedField`, `DecorationMask` and `TerracePass` —
## `TreeMask.for_world()`'s own recurring reason: each is stateless and small, and a shared
## instance would be a second way for two passes to disagree about which world they are
## generating. `DecorationMask.for_world()` already validates the biome/block registries;
## this adds nothing of its own to check at construction.
static func for_world(p_hash: GenerationHash, p_biomes: BiomeRegistry,
		p_blocks: BlockRegistry) -> StructurePlacement:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build structure placement without a world binding"):
		return null
	var bound_seeds := StructureSeedField.for_world(p_hash)
	if bound_seeds == null:
		return null
	var bound_decoration := DecorationMask.for_world(p_hash, p_biomes, p_blocks)
	if bound_decoration == null:
		return null
	var bound_terrace := TerracePass.for_world(p_hash)
	if bound_terrace == null:
		return null
	return StructurePlacement.new(bound_seeds, bound_decoration, bound_terrace)


# ---------------------------------------------------------------------------
# The decision
# ---------------------------------------------------------------------------

## True where a structure actually stands: the region has a candidate (089), it clears the
## presence roll and the eligibility/slope gates, and no higher-priority neighbour crowds
## it out. `false` for a region outside the grid, which has no candidate at all.
func is_placed_at(region: Vector2i) -> bool:
	return _clears_local_gates(region) and has_clearance_at(region)


## The `StructureSeed` for `region` when `is_placed_at(region)`, otherwise `null` — so a
## caller iterating regions gets the anchor and the owned sub-seed only where a structure
## is real. Mirrors `StructureSeedField.seed_at()`, one gate stricter.
func seed_at(region: Vector2i) -> StructureSeed:
	if not is_placed_at(region):
		return null
	return _seeds.seed_at(region)


## The placed `StructureSeed` for whichever region contains world column `column`, or
## `null` when nothing stands in that region.
func seed_for_column(column: Vector2i) -> StructureSeed:
	return seed_at(GenerationGrid.column_to_region(column))


## The same, for a voxel. Y is dropped: a structure is anchored to a column, not a height
## (brick 091 reads the terraced surface there for the vertical placement).
func seed_for_voxel(voxel: Vector3i) -> StructureSeed:
	return seed_for_column(GenerationGrid.voxel_to_column(voxel))


## True when `region` has a placed structure at all — the `is_placed_at()` question under a
## name that reads as intent for a caller scanning the world.
func has_structure_at(region: Vector2i) -> bool:
	return is_placed_at(region)


# ---------------------------------------------------------------------------
# The gates, separately
# ---------------------------------------------------------------------------
#
# `is_placed_at()` is the conjunction; these are its terms. Brick 091 wants to know *why* a
# likely-looking region stands empty, and the spacing scan needs the presence + ground
# terms on their own (without itself) to stay non-recursive.

## True when `region`'s candidate is kept by the presence roll. `false` when the region has
## no candidate. Rolled from `StructureSeed.rng()` forked with `_PRESENCE_STREAM_KEY`, so it
## disturbs neither 089's region stream nor the raw `structure_seed` 091 forks its own
## generator from.
func passes_presence_roll_at(region: Vector2i) -> bool:
	var candidate := _seeds.seed_at(region)
	if candidate == null:
		return false
	return candidate.rng().derive_named(_PRESENCE_STREAM_KEY).next_bool(PRESENCE_CHANCE)


## True when the ground at `region`'s anchor could hold a structure: dry, off the beach
## (`DecorationMask.is_eligible_at()`) and flat enough (`is_slope_buildable_at()`). `false`
## when the region has no candidate.
func is_ground_suitable_at(region: Vector2i) -> bool:
	var candidate := _seeds.seed_at(region)
	if candidate == null:
		return false
	var anchor := candidate.anchor_column
	return _decoration.is_eligible_at(anchor) and is_slope_buildable_at(anchor)


## True when the terraced surface across the probe pad (the anchor plus the eight points
## `SITE_PROBE_RADIUS_VOXELS` out) spans no more than `MAX_SITE_RELIEF_VOXELS`. A rugged
## column already classifies away from a buildable biome upstream, so this only has to catch
## the merely sloped one.
func is_slope_buildable_at(anchor: Vector2i) -> bool:
	var lowest := _terrace.surface_y(anchor)
	var highest := lowest
	for offset in _PROBE_OFFSETS:
		var y := _terrace.surface_y(anchor + offset)
		lowest = mini(lowest, y)
		highest = maxi(highest, y)
	return highest - lowest <= MAX_SITE_RELIEF_VOXELS


## True when no higher-priority neighbouring candidate crowds `region`'s anchor out. A
## region with no candidate has no clearance. See the class comment for why the scan is
## exactly the 8 Moore neighbours and why it does not recurse.
func has_clearance_at(region: Vector2i) -> bool:
	var here := _seeds.seed_at(region)
	if here == null:
		return false
	var here_rank := _rank_of(here, region)
	var spacing_squared := MIN_STRUCTURE_SPACING_VOXELS * MIN_STRUCTURE_SPACING_VOXELS
	for offset in _NEIGHBOR_REGION_OFFSETS:
		var neighbor_region := region + offset
		var other := _seeds.seed_at(neighbor_region)
		if other == null:
			continue
		if _anchor_distance_squared(here.anchor_column, other.anchor_column) >= spacing_squared:
			continue
		if not _clears_local_gates(neighbor_region):
			continue
		if _rank_greater(_rank_of(other, neighbor_region), here_rank):
			return false
	return true


# ---------------------------------------------------------------------------
# Shape of the pass
# ---------------------------------------------------------------------------

## The seed field underneath, for a consumer that wants every region's candidate regardless
## of whether a structure stands there. Read-only by convention.
func seeds() -> StructureSeedField:
	return _seeds


## The decoration mask underneath, for a consumer that wants the raw eligibility answer.
func decoration() -> DecorationMask:
	return _decoration


## The terrace pass underneath, for a consumer that wants the surface height the slope gate
## probes.
func terrace() -> TerracePass:
	return _terrace


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Presence roll and ground suitability, without the spacing gate — the term the spacing
## scan consults for a neighbour, and half of `is_placed_at()`.
func _clears_local_gates(region: Vector2i) -> bool:
	return passes_presence_roll_at(region) and is_ground_suitable_at(region)


## Squared Euclidean distance between two anchor columns, in voxels². Squared to match
## `World::falloffSquared`'s own shape and to keep the comparison in exact integers.
static func _anchor_distance_squared(a: Vector2i, b: Vector2i) -> int:
	var delta := a - b
	return delta.x * delta.x + delta.y * delta.y


## The priority key for a candidate: its own `structure_seed` (a splitmix64 output, so
## already well spread), with the region coordinates as a deterministic tie-break for the
## astronomically rare collision. A total order, independent of visit order.
static func _rank_of(seed_record: StructureSeed, region: Vector2i) -> Array:
	return [seed_record.structure_seed, region.x, region.y]


## `a` out-ranks `b`. `structure_seed` is compared as unsigned 64-bit bits (the sign bit is
## just the top bit of a hash), then the region coordinates break a tie.
static func _rank_greater(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return _unsigned_greater(a[0], b[0])
	if a[1] != b[1]:
		return a[1] > b[1]
	return a[2] > b[2]


## `x > y` treating both as unsigned 64-bit. Flipping the sign bit maps the unsigned order
## onto the signed one GDScript's `>` implements.
static func _unsigned_greater(x: int, y: int) -> bool:
	return (x ^ -9223372036854775808) > (y ^ -9223372036854775808)


# ---------------------------------------------------------------------------
# Self-check
# ---------------------------------------------------------------------------

## Empty string when the constants still hold the relationships the class comment relies on,
## otherwise the reason — `SnowlineMaterial.self_check()`'s own precedent for a derived
## bound asserted rather than trusted.
static func self_check() -> String:
	if MIN_STRUCTURE_SPACING_VOXELS >= GenerationGrid.REGION_SIZE_VOXELS:
		return ("MIN_STRUCTURE_SPACING_VOXELS (%d) is not below REGION_SIZE_VOXELS (%d); "
				+ "the 8-neighbour spacing scan is no longer complete") % [
						MIN_STRUCTURE_SPACING_VOXELS, GenerationGrid.REGION_SIZE_VOXELS]
	if PRESENCE_CHANCE <= 0.0 or PRESENCE_CHANCE > 1.0:
		return "PRESENCE_CHANCE (%s) is not in (0, 1]" % PRESENCE_CHANCE
	if MAX_SITE_RELIEF_VOXELS < 0:
		return "MAX_SITE_RELIEF_VOXELS (%d) is negative" % MAX_SITE_RELIEF_VOXELS
	return ""
