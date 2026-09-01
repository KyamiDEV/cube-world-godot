class_name GenerationGrid
extends RefCounted
## The coordinate spaces world generation works in, and the conversions between them
## (backlog brick 058).
##
## `WorldScale` (013) owns metres <-> world units <-> voxels. This file owns everything
## *coarser* than a voxel: the grids generation actually asks questions at.
##
## | Space | Type | Edge | Asked at |
## |---|---|---|---|
## | voxel | `Vector3i` | 1 voxel | per-cell content: is this cell stone, air, ore? |
## | column | `Vector2i` (x, z) | 1 voxel | per-column fields: elevation, temperature, humidity, biome |
## | chunk | `Vector3i` | `CHUNK_SIZE_VOXELS` | the generator's work unit — one `VoxelBuffer` fill |
## | chunk column | `Vector2i` (x, z) | `CHUNK_SIZE_VOXELS` | "does anything in this column of chunks need generating at all?" |
## | region | `Vector2i` (x, z) | `REGION_SIZE_VOXELS` | macro placement: structures, POIs, region-scale variation |
##
## Two rules this file exists to enforce:
##
## 1. **Floor division, never truncation.** `-1 / 16` is `0` in GDScript, so a truncating
##    conversion puts voxel -1 and voxel 0 in the same chunk and makes every grid
##    asymmetric around the origin. That is a determinism bug that only appears in
##    negative coordinates — half the world — and only when a player walks there.
##    `WorldScale.world_to_voxel()` already makes this point for the float boundary; this
##    is the integer half of it.
## 2. **Grids are half-open.** A chunk owns `[origin, origin + size)`. `WorldBounds.aabb()`
##    is inclusive at its maximum face because `AABB.has_point()` is, so the single voxel
##    plane at `x == +HALF_EXTENT_HORIZONTAL_VOXELS` (likewise z) is inside the world
##    bounds and outside the region grid. Generation uses the half-open convention;
##    `is_region_in_world()` is the authority for "is there a region here".
##
## Contract: `docs/world-generation.md` §3. Hashing at these spaces is
## `world/generation/generation_hash.gd`, which tags each space so two grids never
## collide.
##
## Static-only: never instantiate.

## Edge of one generation work unit, in voxels. This is Voxel Tools' *data* block size,
## which is fixed at 16 for `VoxelTerrain` — a generator is handed one such block at a
## time, so making the generation grid anything else would mean every generated chunk
## straddled a block boundary. Deliberately **not** `VoxelTerrainBuilder.
## DEFAULT_MESH_BLOCK_SIZE` (ADR 0002): that one is a rendering-granularity choice and is
## free to become 32 without moving a single generated voxel.
const CHUNK_SIZE_VOXELS := 16

## Edge of one region, in voxels: 1024 voxels = 512 m.
##
## Chosen so the region grid is exactly `REGIONS_PER_AXIS` x `REGIONS_PER_AXIS` across
## `WorldBounds`' horizontal extent. The 1024 x 1024 *shape* is the one piece of the
## original's region grid worth keeping (`docs/reference/region-coordinate-hashing.md`,
## claim 1); the size in voxels is ours, scaled to our own, much smaller world rather
## than copied from the reference's 16 384-unit regions.
const REGION_SIZE_VOXELS := 1024

## Chunks along one region edge. Asserted against the two constants above by
## `tests/unit/test_generation_grid.gd` rather than divided out here, so a change to
## either one fails the suite instead of silently re-deriving.
const REGION_SIZE_CHUNKS := 64

## Regions along one horizontal world axis, and half that count — region coordinates run
## `-HALF_REGIONS_PER_AXIS .. HALF_REGIONS_PER_AXIS - 1` on both X and Z. Unlike the
## reference's grid, ours is signed and centred on the origin (claim 1 / §9 of the note
## above): the world has no corner to count from.
const REGIONS_PER_AXIS := 1024
const HALF_REGIONS_PER_AXIS := 512


# ---------------------------------------------------------------------------
# Integer floor arithmetic
# ---------------------------------------------------------------------------

## Floor division for integers. `floor_div(-1, 16)` is `-1`, where `-1 / 16` is `0`.
##
## Public because every coarser grid a later brick invents needs the same operation, and
## a hand-rolled `int(floor(float(a) / b))` loses exactness once coordinates grow past
## the 53-bit mantissa. The subtraction makes the division exact, so the truncating `/`
## below cannot round.
static func floor_div(value: int, divisor: int) -> int:
	@warning_ignore("integer_division")
	return (value - posmod(value, divisor)) / divisor


## Non-negative remainder: the position of `value` inside its own cell. `floor_mod(-1, 16)`
## is `15`. A thin name over `posmod()`, so a call site reads as the grid operation it is.
static func floor_mod(value: int, divisor: int) -> int:
	return posmod(value, divisor)


# ---------------------------------------------------------------------------
# Voxel <-> chunk
# ---------------------------------------------------------------------------

## The chunk containing a voxel.
static func voxel_to_chunk(voxel: Vector3i) -> Vector3i:
	return Vector3i(
		floor_div(voxel.x, CHUNK_SIZE_VOXELS),
		floor_div(voxel.y, CHUNK_SIZE_VOXELS),
		floor_div(voxel.z, CHUNK_SIZE_VOXELS))


## Minimum-corner voxel of a chunk — the anchor a generator fills from.
static func chunk_origin(chunk: Vector3i) -> Vector3i:
	return chunk * CHUNK_SIZE_VOXELS


## Position of a voxel inside its own chunk, each axis in `0 .. CHUNK_SIZE_VOXELS - 1`.
## Correct for negative coordinates, which is the whole reason it is not `voxel %
## CHUNK_SIZE_VOXELS`.
static func voxel_in_chunk(voxel: Vector3i) -> Vector3i:
	return Vector3i(
		floor_mod(voxel.x, CHUNK_SIZE_VOXELS),
		floor_mod(voxel.y, CHUNK_SIZE_VOXELS),
		floor_mod(voxel.z, CHUNK_SIZE_VOXELS))


# ---------------------------------------------------------------------------
# Columns
# ---------------------------------------------------------------------------

## The world column a voxel stands in. Y is dropped, not zeroed: a column is a 2D
## coordinate, and `generation_hash.gd` tags it as one so it can never collide with a 3D
## coordinate that happens to carry the same numbers.
static func voxel_to_column(voxel: Vector3i) -> Vector2i:
	return Vector2i(voxel.x, voxel.z)


static func column_to_chunk_column(column: Vector2i) -> Vector2i:
	return Vector2i(
		floor_div(column.x, CHUNK_SIZE_VOXELS),
		floor_div(column.y, CHUNK_SIZE_VOXELS))


static func chunk_to_chunk_column(chunk: Vector3i) -> Vector2i:
	return Vector2i(chunk.x, chunk.z)


## Minimum-corner world column of a chunk column.
static func chunk_column_origin(chunk_column: Vector2i) -> Vector2i:
	return chunk_column * CHUNK_SIZE_VOXELS


## Position of a world column inside its own chunk column, each axis in
## `0 .. CHUNK_SIZE_VOXELS - 1`.
static func column_in_chunk_column(column: Vector2i) -> Vector2i:
	return Vector2i(
		floor_mod(column.x, CHUNK_SIZE_VOXELS),
		floor_mod(column.y, CHUNK_SIZE_VOXELS))


# ---------------------------------------------------------------------------
# Regions
# ---------------------------------------------------------------------------

static func column_to_region(column: Vector2i) -> Vector2i:
	return Vector2i(
		floor_div(column.x, REGION_SIZE_VOXELS),
		floor_div(column.y, REGION_SIZE_VOXELS))


static func voxel_to_region(voxel: Vector3i) -> Vector2i:
	return column_to_region(voxel_to_column(voxel))


static func chunk_to_region(chunk: Vector3i) -> Vector2i:
	return Vector2i(
		floor_div(chunk.x, REGION_SIZE_CHUNKS),
		floor_div(chunk.z, REGION_SIZE_CHUNKS))


## Minimum-corner world column of a region.
static func region_origin(region: Vector2i) -> Vector2i:
	return region * REGION_SIZE_VOXELS


## Position of a world column inside its own region, each axis in
## `0 .. REGION_SIZE_VOXELS - 1`.
static func column_in_region(column: Vector2i) -> Vector2i:
	return Vector2i(
		floor_mod(column.x, REGION_SIZE_VOXELS),
		floor_mod(column.y, REGION_SIZE_VOXELS))


## True when a region exists in this world at all — the region-grid counterpart of
## `WorldBounds.contains()`, and the check a macro-placement pass (bricks 089-090) runs
## before generating a region's contents.
##
## Half-open on purpose (see the class comment): the maximum face is `HALF_REGIONS_PER_AXIS
## - 1`, so the region grid covers `[-524288, +524288)` voxels while `WorldBounds.aabb()`
## includes the `+524288` plane itself.
static func is_region_in_world(region: Vector2i) -> bool:
	return (region.x >= -HALF_REGIONS_PER_AXIS and region.x < HALF_REGIONS_PER_AXIS
			and region.y >= -HALF_REGIONS_PER_AXIS and region.y < HALF_REGIONS_PER_AXIS)
