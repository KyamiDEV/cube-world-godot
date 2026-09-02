class_name GenerationHash
extends RefCounted
## Positional hashing bound to one world (backlog brick 058).
##
## `WorldHash` (015) is the primitive: coordinates plus an integer seed plus a salt, out
## comes a value, with no state and no visit-order dependence. It is deliberately generic
## and takes a bare `int`. This file is the generation layer's only supported way to call
## it, and it adds the three things a generator needs that the primitive cannot know
## about:
##
## | Adds | Why |
## |---|---|
## | binding to a `WorldSeed` | `docs/world-generation.md` §1.1 — generation call sites take a `WorldSeed`, never an integer, so `(seed, generation version)` cannot drift apart. Reaching for `config.value` at each call site would re-open exactly that hole |
## | a checked version, once | this is where a `WorldSeed` becomes numbers, so it is where "this build cannot reproduce that world's algorithm" has to be refused (`docs/world-generation.md` §2.3). The check runs in `for_world()`, never per call — hashing is the hottest path in the project |
## | a **space tag** per coordinate grid | chunk `(3, 0, 5)` and voxel `(3, 0, 5)` are different places that carry the same numbers. Untagged, a per-voxel pass and a per-chunk pass sharing a salt would agree cell for cell, and every chunk-scale decision would land on the voxel that shares its coordinates |
##
## ```gdscript
## var hash := GenerationHash.for_world(world_seed)
## var height := hash.value01_column(column, WorldHash.SALT_ELEVATION)
## if hash.chance_voxel(voxel, 0.02, WorldHash.SALT_TREES):
##     _place_tree(voxel)
## ```
##
## The **generation version is not mixed into the hash**, on purpose. A version selects
## which algorithm runs; it is not an input to that algorithm. Mixing it in would make
## every bump reshuffle every unrelated pass — a fix to the tree mask would move every
## mountain — and would make "version 2 is version 1 with different numbers"
## indistinguishable from a real algorithmic change. `docs/world-generation.md` §3.3.
##
## Contract: `docs/world-generation.md` §3. Coordinate spaces and the conversions between
## them: `world/generation/generation_grid.gd`. RNG rules: `docs/rng.md`.

## The coordinate grids generation hashes at, one per `GenerationGrid` space.
##
## Values are **baked into every world generated with them** and follow the same rule as
## `WorldHash`'s salts (`docs/rng.md` §4): append, never renumber, never reuse. `VOXEL`
## is 0 so that voxel-space hashing stays byte-identical to a bare `WorldHash` call — the
## tagging is free for the base case and only separates the coarser grids from it.
enum Space {
	VOXEL = 0,
	COLUMN = 1,
	CHUNK = 2,
	CHUNK_COLUMN = 3,
	REGION = 4,
	## A decoration scatter's own cell grid (brick 086) — `column / spacing`, floored. Its
	## pitch is chosen per decoration pass, so a cell coordinate here shares no meaning with
	## a `COLUMN`-space coordinate at the same numbers; the tag is what keeps them from
	## agreeing by coincidence.
	DECORATION_CELL = 5,
}

## Spacing between one space's salt block and the next. Every `WorldHash.SALT_*` constant
## must be smaller than this, or two spaces would share effective salts and the tagging
## would silently stop working; `tests/unit/test_generation_hash.gd` asserts it over the
## whole constant list rather than trusting the next person to check.
const SPACE_SALT_STRIDE := 4096

## The world this instance generates. Held whole, not unpacked, so a caller that needs
## the version or the display text has it without a second parameter.
var world_seed: WorldSeed

## `world_seed.value`, read once. Every hash call goes through it, so it is not looked up
## through a property on the hot path.
var _seed_value: int


func _init(p_world_seed: WorldSeed) -> void:
	world_seed = p_world_seed
	_seed_value = p_world_seed.value


# ---------------------------------------------------------------------------
# Binding to a world
# ---------------------------------------------------------------------------

## Binds hashing to one world, or returns null (logged) when this build must not generate
## it. **The supported entry point** — `GenerationHash.new()` skips the check.
##
## Refusing here rather than at the first call is the point: a build that cannot
## reproduce a world's algorithm must not produce *approximately* that world, because the
## result looks right and stitches a second algorithm into terrain a player already
## explored (`docs/persistence.md` §3).
static func for_world(p_world_seed: WorldSeed) -> GenerationHash:
	var reason := refuse_reason(p_world_seed)
	if not Log.check(reason.is_empty(), Log.CH_GEN,
			"cannot bind world generation to this seed configuration", {"reason": reason}):
		return null
	return GenerationHash.new(p_world_seed)


## Empty string when this build may generate the given world, otherwise why it may not —
## the same string-reason convention `WorldSeed.validate()` and
## `GenerationVersion.self_check()` use.
##
## Pure and static, so the session handshake (bricks 235-236) and a load screen can ask
## the question before anything is constructed.
static func refuse_reason(p_world_seed: WorldSeed) -> String:
	if p_world_seed == null:
		return "no seed configuration"
	var invalid := p_world_seed.validate()
	if not invalid.is_empty():
		return invalid
	if not GenerationVersion.is_supported(p_world_seed.generation_version):
		return GenerationVersion.explain(p_world_seed.generation_version)
	return ""


## The numeric seed every hash below mixes. Exposed for a call site that must reach the
## `WorldHash` primitive directly (a benchmark, a debug probe); ordinary generation code
## calls the methods below instead, so the space tag is never left off by accident.
func seed_value() -> int:
	return _seed_value


## The effective salt for one pass in one space. Deterministic and stable forever: change
## this arithmetic and every world ever generated changes with it, which is a generation
## version bump (`docs/world-generation.md` §2.1).
static func salt_in(space: Space, salt: int) -> int:
	return int(space) * SPACE_SALT_STRIDE + salt


# ---------------------------------------------------------------------------
# Raw hashes
# ---------------------------------------------------------------------------

## 64-bit hash of a 3D coordinate in a 3D space. Treat the result as bits, not a number.
func hash3_in(space: Space, x: int, y: int, z: int, salt: int = 0) -> int:
	return WorldHash.hash3(_seed_value, x, y, z, salt_in(space, salt))


## 64-bit hash of a 2D coordinate in a 2D space.
func hash2_in(space: Space, x: int, z: int, salt: int = 0) -> int:
	return WorldHash.hash2(_seed_value, x, z, salt_in(space, salt))


func hash_voxel(voxel: Vector3i, salt: int = 0) -> int:
	return hash3_in(Space.VOXEL, voxel.x, voxel.y, voxel.z, salt)


func hash_chunk(chunk: Vector3i, salt: int = 0) -> int:
	return hash3_in(Space.CHUNK, chunk.x, chunk.y, chunk.z, salt)


func hash_column(column: Vector2i, salt: int = 0) -> int:
	return hash2_in(Space.COLUMN, column.x, column.y, salt)


func hash_chunk_column(chunk_column: Vector2i, salt: int = 0) -> int:
	return hash2_in(Space.CHUNK_COLUMN, chunk_column.x, chunk_column.y, salt)


func hash_region(region: Vector2i, salt: int = 0) -> int:
	return hash2_in(Space.REGION, region.x, region.y, salt)


# ---------------------------------------------------------------------------
# Unit values
# ---------------------------------------------------------------------------

## Uniform value in `[0, 1)` at a 3D coordinate in a 3D space.
func value01_3_in(space: Space, x: int, y: int, z: int, salt: int = 0) -> float:
	return WorldHash.value01_3(_seed_value, x, y, z, salt_in(space, salt))


## Uniform value in `[0, 1)` at a 2D coordinate in a 2D space.
func value01_2_in(space: Space, x: int, z: int, salt: int = 0) -> float:
	return WorldHash.value01_2(_seed_value, x, z, salt_in(space, salt))


func value01_voxel(voxel: Vector3i, salt: int = 0) -> float:
	return value01_3_in(Space.VOXEL, voxel.x, voxel.y, voxel.z, salt)


func value01_chunk(chunk: Vector3i, salt: int = 0) -> float:
	return value01_3_in(Space.CHUNK, chunk.x, chunk.y, chunk.z, salt)


func value01_column(column: Vector2i, salt: int = 0) -> float:
	return value01_2_in(Space.COLUMN, column.x, column.y, salt)


func value01_chunk_column(chunk_column: Vector2i, salt: int = 0) -> float:
	return value01_2_in(Space.CHUNK_COLUMN, chunk_column.x, chunk_column.y, salt)


func value01_region(region: Vector2i, salt: int = 0) -> float:
	return value01_2_in(Space.REGION, region.x, region.y, salt)


# ---------------------------------------------------------------------------
# Placement masks
# ---------------------------------------------------------------------------

## True with the given probability at a voxel. The workhorse for placement masks: "does a
## tree stand here?", answered with no sequence at all, so sampling one cell can never
## change another.
##
## A probability of `0` or `1` short-circuits **before hashing**, matching
## `DeterministicRng.next_bool()` — a disabled pass must cost nothing and change nothing.
func chance_voxel(voxel: Vector3i, probability: float, salt: int = 0) -> bool:
	if probability <= 0.0:
		return false
	if probability >= 1.0:
		return true
	return value01_voxel(voxel, salt) < probability


func chance_column(column: Vector2i, probability: float, salt: int = 0) -> bool:
	if probability <= 0.0:
		return false
	if probability >= 1.0:
		return true
	return value01_column(column, salt) < probability


func chance_region(region: Vector2i, probability: float, salt: int = 0) -> bool:
	if probability <= 0.0:
		return false
	if probability >= 1.0:
		return true
	return value01_region(region, salt) < probability


# ---------------------------------------------------------------------------
# Position-owned streams
# ---------------------------------------------------------------------------

## A private stream owned by one coordinate, for a pass that needs several related values
## there — a structure's kind, then its rotation, then its size. The sequence belongs to
## that coordinate alone, so it reproduces whatever else the generator did in between.
##
## One stream, one owner (`docs/rng.md` §5): a generation worker takes its own rather than
## sharing.
func rng_voxel(voxel: Vector3i, salt: int = 0) -> DeterministicRng:
	return DeterministicRng.new(hash_voxel(voxel, salt))


func rng_chunk(chunk: Vector3i, salt: int = 0) -> DeterministicRng:
	return DeterministicRng.new(hash_chunk(chunk, salt))


func rng_column(column: Vector2i, salt: int = 0) -> DeterministicRng:
	return DeterministicRng.new(hash_column(column, salt))


func rng_chunk_column(chunk_column: Vector2i, salt: int = 0) -> DeterministicRng:
	return DeterministicRng.new(hash_chunk_column(chunk_column, salt))


## The stream a region-scale placement pass draws from (bricks 089-090). The original
## seeded this from a linear combination of the region coordinates and fed a process-global
## `srand()`; `docs/reference/region-coordinate-hashing.md` §9 records why this does not.
func rng_region(region: Vector2i, salt: int = 0) -> DeterministicRng:
	return DeterministicRng.new(hash_region(region, salt))


## The stream a decoration scatter cell draws its anchor point from (`DecorationMask`,
## brick 086). One cell, one stream: two decoration passes at different salts never agree
## about where inside a shared cell their own anchor sits.
func rng_decoration_cell(cell: Vector2i, salt: int = 0) -> DeterministicRng:
	return DeterministicRng.new(hash2_in(Space.DECORATION_CELL, cell.x, cell.y, salt))
