class_name StructureSeedField
extends RefCounted
## One deterministic structure seed per region (backlog brick 089).
##
## `DecorationMask` (086) answers "one candidate point per `spacing × spacing` cell" for
## trees and rocks by hashing the cell and letting its own stream pick a column inside it.
## This file is the same mechanism one grid coarser: the cell is a **region**
## (`GenerationGrid.REGION_SIZE_VOXELS`, 1024 voxels), the salt is
## `WorldHash.SALT_STRUCTURES`, and what the cell's stream picks is not just a column but a
## whole `StructureSeed` — the anchor column plus the owned seed a structure generator
## (091) will draw its kind, rotation and size from.
##
## ```gdscript
## var field := StructureSeedField.for_world(GenerationHash.for_world(world_seed))
## var candidate := field.seed_for_column(player_column)
## if candidate != null:
##     ...   # brick 090 decides whether it may stand; brick 091 builds it
## ```
##
## ## Exactly one seed per region — presence is brick 090's job, not this one's
##
## Every in-world region yields exactly one `StructureSeed`, the way every
## `DecorationMask` cell yields exactly one anchor. This file rolls **no** rarity gate and
## reads **no** terrain, biome or climate: whether a structure actually stands at the
## anchor — slope, water, biome suitability, distance to the next structure, the falloff
## weighting `matrix-world.md` §2 records (`World::objectFalloffWeight`) — is entirely
## brick 090's question. Folding a presence roll in here would be the same mistake as
## `DecorationMask` deciding snow cover: a later brick needs that decision and has the
## fields to make it well; this one does not.
##
## ## The region stream is drawn in a fixed order
##
## `seed_at()` takes `GenerationHash.rng_region(region, WorldHash.SALT_STRUCTURES)` and
## draws, in this order and never any other:
##
## 1. the anchor's X offset inside the region, `0 .. REGION_SIZE_VOXELS - 1`
## 2. the anchor's Z offset inside the region
## 3. the `structure_seed` — one raw 64-bit value
##
## This is the "position-owned stream" shape `GenerationHash`'s own class comment
## describes (a structure's kind, then its rotation, then its size): a single sequence
## owned by one coordinate, so the order is part of the contract. Appending a fourth draw
## later is fine; inserting one in the middle moves every anchor in the world and is a
## generation version bump.
##
## ## Out-of-grid regions have no seed
##
## `seed_at()` returns `null` for a region outside `GenerationGrid.is_region_in_world()` —
## the reference's own `INV-2` (`region-coordinate-hashing.md`: "a region outside the grid
## has no content at all, rather than clamped or wrapped content"), and the place §10 of
## that note said the `is_region_in_world()` check would first be *used*. It is a quiet
## `null`, not a logged error: a caller scanning the world edge is expected to get some.
##
## ## Not a generation version bump
##
## The boundary every Phase D brick since 062 has named: no world has ever had a voxel
## written, so nothing here can contradict one. This file mixes no new salt
## (`WorldHash.SALT_STRUCTURES`, reserved since brick 015, unread until now) and adds no
## new `GenerationHash.Space` — `Space.REGION` and `rng_region()` already exist, and
## `rng_region()`'s own docstring already names bricks 089–090. `SALT_STRUCTURES`, the
## draw order above and the region grid pitch all become pinned generation inputs the
## moment brick 091's `VoxelGenerator` reads a `StructureSeed` to place a structure —
## the same "first `VoxelBuffer` write" boundary bricks 075–088 each named.
##
## Contract: `docs/world-generation.md` §28.

var _hash: GenerationHash


func _init(p_hash: GenerationHash) -> void:
	_hash = p_hash


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds structure seed selection to one world, or returns null (logged) without a world
## binding. **The supported entry point.**
##
## Takes only a `GenerationHash`: this brick reads no biome catalog and no block registry,
## unlike the decoration masks it borrows its mechanism from.
static func for_world(p_hash: GenerationHash) -> StructureSeedField:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build structure seed selection without a world binding"):
		return null
	return StructureSeedField.new(p_hash)


# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------

## The one `StructureSeed` region cell `region` reserves, or `null` when `region` is
## outside the region grid. See the class comment for the fixed draw order.
func seed_at(region: Vector2i) -> StructureSeed:
	if not GenerationGrid.is_region_in_world(region):
		return null
	var rng := _hash.rng_region(region, WorldHash.SALT_STRUCTURES)
	var offset_x := rng.next_int(0, GenerationGrid.REGION_SIZE_VOXELS - 1)
	var offset_z := rng.next_int(0, GenerationGrid.REGION_SIZE_VOXELS - 1)
	var structure_seed := rng.next_u64()
	var origin := GenerationGrid.region_origin(region)
	return StructureSeed.new(region, origin + Vector2i(offset_x, offset_z), structure_seed)


## The `StructureSeed` for whichever region contains world column `column`, or `null` when
## that region is outside the grid.
func seed_for_column(column: Vector2i) -> StructureSeed:
	return seed_at(GenerationGrid.column_to_region(column))


## The same, for a voxel. Y is dropped: a structure is anchored to a column, not a height
## (brick 091 reads the terraced surface there for the vertical placement).
func seed_for_voxel(voxel: Vector3i) -> StructureSeed:
	return seed_for_column(GenerationGrid.voxel_to_column(voxel))


## True when `region` has a structure seed at all — a thin, named passthrough to
## `GenerationGrid.is_region_in_world()`, so a caller iterating regions reads the intent
## rather than the grid arithmetic.
func has_seed(region: Vector2i) -> bool:
	return GenerationGrid.is_region_in_world(region)


# ---------------------------------------------------------------------------
# Shape of the pass
# ---------------------------------------------------------------------------

## The world binding underneath, for a consumer that needs the seed or generation version
## directly. Read-only by convention. Not named `hash()`: `Object.hash()` already exists
## with a different return type.
func generation_hash() -> GenerationHash:
	return _hash
