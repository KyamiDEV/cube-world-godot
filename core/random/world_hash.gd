class_name WorldHash
extends RefCounted
## Positional hashing for deterministic world generation (backlog brick 015).
##
## Generation must be a pure function of `(seed, world coordinates, generation version)`
## — never of visit order. A sequential stream cannot give that: chunk B's result would
## depend on whether chunk A was generated first, so a world would regenerate
## differently for a player who walked in from the other side.
##
## The primitive here is therefore *stateless*: coordinates in, value out. Where a
## generator needs several related values, `rng_at()` hands back a private
## `DeterministicRng` seeded from the position, so the sequence belongs to that position
## alone.
##
## ```gdscript
## var rng := WorldHash.rng_at(world_seed, chunk.x, chunk.y, chunk.z, WorldHash.SALT_TREES)
## var tree_count := rng.next_int(0, 5)
## ```
##
## Static-only: never instantiate.

## Large odd multipliers, one per axis, so that (x, y, z) and (y, x, z) do not collide
## and so that walking one axis does not walk the hash in a visible pattern.
const _AXIS_X := 6364136223846793005     # Knuth's LCG multiplier
const _AXIS_Y := -4265267296055464877    # 0xC4CEB9FE1A85EC53
const _AXIS_Z := 1442695040888963407     # Knuth's LCG increment, odd

## Applied after each axis is folded in, and the reason folding is not XOR alone.
##
## Negating an integer flips every bit above its lowest set bit, so `-n` is `n` XOR a
## suffix mask determined only by `n`'s trailing zero count. Two axis products whose
## trailing zero counts match therefore contribute the *same* mask, and XOR-combining
## them cancels both: `hash2(-7, -9)` came out exactly equal to `hash2(7, 9)`, giving the
## world a point symmetry through the origin across a quarter of all columns. Multiplying
## by an odd constant between folds propagates each axis into the high bits before the
## next one arrives, so no later term can cancel an earlier one.
##
## Found by brick 058's tests and fixed there, while no generated world existed yet;
## after brick 060 the same change would be a generation version bump
## (`docs/world-generation.md` §2.1).
const _COMBINE := -7046029254386353131   # 0x9E3779B97F4A7C15, golden-ratio odd constant

## Salts keep independent generation passes from correlating: the tree pass and the ore
## pass must not agree about which cells are "high". Add one per pass; never reuse a
## salt for a different purpose, and never renumber an existing one — the values are
## baked into every world generated with them.
const SALT_ELEVATION := 1
const SALT_TEMPERATURE := 2
const SALT_HUMIDITY := 3
const SALT_CAVES := 4
const SALT_TREES := 5
const SALT_PROPS := 6
const SALT_STRUCTURES := 7
const SALT_SPAWNS := 8
const SALT_LOOT := 9


## 64-bit hash of a 3D voxel or chunk coordinate under a world seed and pass salt.
static func hash3(seed_value: int, x: int, y: int, z: int, salt: int = 0) -> int:
	var value := seed_value * 31 + salt
	value = (value ^ (x * _AXIS_X)) * _COMBINE
	value = (value ^ (y * _AXIS_Y)) * _COMBINE
	value = (value ^ (z * _AXIS_Z)) * _COMBINE
	return DeterministicRng.mix64(value)


## 2D form for column-based passes (elevation, biome, moisture) where Y is irrelevant.
## It is not `hash3(..., 0, ...)`: keeping it distinct means a 2D field and a 3D field
## at y = 0 do not produce identical patterns.
static func hash2(seed_value: int, x: int, z: int, salt: int = 0) -> int:
	var value := seed_value * 31 + salt
	value = (value ^ (x * _AXIS_X)) * _COMBINE
	value = (value ^ (z * _AXIS_Z)) * _COMBINE
	value = (value ^ _AXIS_Y) * _COMBINE  # distinguishes 2D from 3D-at-y-0
	return DeterministicRng.mix64(value)


## Uniform value in `[0, 1)` at a 3D position.
static func value01_3(seed_value: int, x: int, y: int, z: int, salt: int = 0) -> float:
	return _to_unit_float(hash3(seed_value, x, y, z, salt))


## Uniform value in `[0, 1)` at a 2D position.
static func value01_2(seed_value: int, x: int, z: int, salt: int = 0) -> float:
	return _to_unit_float(hash2(seed_value, x, z, salt))


## A private stream owned by a position. Two calls with the same arguments always return
## streams that produce the same sequence, whatever else the generator did in between.
static func rng_at(seed_value: int, x: int, y: int, z: int, salt: int = 0) -> DeterministicRng:
	return DeterministicRng.new(hash3(seed_value, x, y, z, salt))


static func rng_at_column(seed_value: int, x: int, z: int, salt: int = 0) -> DeterministicRng:
	return DeterministicRng.new(hash2(seed_value, x, z, salt))


## Vector forms, for call sites that already hold a coordinate.
static func hash_voxel(seed_value: int, voxel: Vector3i, salt: int = 0) -> int:
	return hash3(seed_value, voxel.x, voxel.y, voxel.z, salt)


static func rng_at_voxel(seed_value: int, voxel: Vector3i, salt: int = 0) -> DeterministicRng:
	return rng_at(seed_value, voxel.x, voxel.y, voxel.z, salt)


## True with the given probability at a position. The workhorse for placement masks:
## "does a tree stand here?" answered without any sequence at all.
static func chance_at(seed_value: int, voxel: Vector3i, probability: float,
		salt: int = 0) -> bool:
	if probability <= 0.0:
		return false
	if probability >= 1.0:
		return true
	return value01_3(seed_value, voxel.x, voxel.y, voxel.z, salt) < probability


## Turns a user-facing seed string into the numeric world seed. Seeds players type must
## hash the same way forever, so this uses the project's own stable string hash rather
## than the engine's.
static func seed_from_text(text: String) -> int:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return 0
	# A purely numeric seed is taken at face value, which is what a player typing
	# "12345" expects, and what makes a bug report reproducible.
	if trimmed.is_valid_int():
		return trimmed.to_int()
	return DeterministicRng.hash_string(trimmed)


static func _to_unit_float(hash_value: int) -> float:
	# Top 53 bits, matching DeterministicRng.next_float(): the same bits mean the same
	# distribution whichever route produced the value.
	return float((hash_value >> 11) & ((1 << 53) - 1)) / 9007199254740992.0
