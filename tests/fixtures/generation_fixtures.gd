class_name GenerationFixtures
extends RefCounted
## The committed inputs every generation test samples, and the checks it samples them
## with (backlog brick 059).
##
## Phase D adds one generation pass per brick (060 onward), and every one of them owes the
## same four properties to `CLAUDE.md` §1 — a pass must be **repeatable** (same coordinate,
## same answer), **order-free** (the answer does not depend on what was generated first),
## **seed-sensitive** (two worlds are two worlds) and **in range**. Left to each brick,
## those would be re-invented four different ways over thirty bricks, each sampling
## whichever handful of coordinates its author happened to think of, and none of them
## sampling the coordinates that actually break: negative axes, cell boundaries, the far
## corners of `WorldBounds`.
##
## This file is that shared floor. It holds three things:
##
## | Part | What it is |
## |---|---|
## | named worlds | a few `WorldSeed`s with **pinned** numeric values, covering seed 0, a typed phrase, the face-value numeric branch and an all-bits-set negative |
## | coordinate samples | the voxels, columns, chunks, chunk columns and regions worth asking any pass about, each one there for a stated reason |
## | checks | `determinism_reason()`, `seed_sensitivity_reason()`, `range_reason()`, `variation_reason()` and `signature()`, all pure and all returning the project's empty-string-means-fine convention |
##
## ```gdscript
## func test_the_elevation_field_is_deterministic() -> void:
##     var make := func(h: GenerationHash) -> Callable:
##         return func(c: Vector2i) -> float: return ElevationField.at(h, c)
##     var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
##     assert_eq(GenerationFixtures.determinism_reason(make.bind(hash), COLUMNS), "")
##     assert_eq(GenerationFixtures.seed_sensitivity_reason(make, COLUMNS), "")
## ```
##
## **The pinned seed values are a contract, not test data.** They are what
## `WorldHash.seed_from_text()` produces today; a change to the hash changes them, and
## `docs/rng.md` §3 says a changed hash after brick 060 is a generation version bump. The
## fixture failing is that bump asking to be made deliberately rather than noticed by a
## player whose world moved.
##
## Not a test file: the runner only collects `test_*.gd`, so nothing here runs on its own —
## `tests/unit/test_generation_fixtures.gd` is what proves it works. Contract:
## `docs/world-generation.md` §4.
##
## Static-only: never instantiate.

# ---------------------------------------------------------------------------
# Named worlds
# ---------------------------------------------------------------------------

const WORLD_ZERO := "zero"
const WORLD_TYPED := "typed"
const WORLD_NUMERIC := "numeric"
const WORLD_NEGATIVE := "negative"

## The worlds every generation test runs against, and why each one is in the list. `value`
## is pinned rather than computed: see the class comment.
##
## An entry with `text` set is built through `WorldSeed.from_text()` and must hash back to
## `value` (`self_check()` enforces it); an entry with empty text is built through
## `WorldSeed.from_value()`.
const WORLDS := {
	# Seed 0. The accidental default of every uninitialised field, and the one seed where
	# a pass that multiplies the seed into its result collapses to a constant world.
	WORLD_ZERO: {"text": "", "value": 0},
	# The ordinary case: a phrase a player typed, through the string-hash branch.
	WORLD_TYPED: {"text": "cube world", "value": 2398121596163494691},
	# `seed_from_text()`'s face-value branch — "12345" is the seed 12345, so a bug report
	# quoting it reproduces. A small positive seed also leaves the high bits of the seed
	# empty, which is where a pass that only ever mixes low bits shows up.
	WORLD_NUMERIC: {"text": "12345", "value": 12345},
	# Every bit set. Catches a pass that assumes a non-negative seed, and pairs with
	# WORLD_ZERO to bracket the arithmetic.
	WORLD_NEGATIVE: {"text": "", "value": -1},
}


## The fixture world names, in declaration order.
static func world_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for key in WORLDS:
		names.append(key)
	return names


## One named fixture world, freshly built. Null (with an error) for an unknown name — a
## typo in a test must not silently become "no world".
static func world(name: String) -> WorldSeed:
	if not WORLDS.has(name):
		push_error("no fixture world named '%s'" % name)
		return null
	var entry: Dictionary = WORLDS[name]
	var text: String = entry["text"]
	if text.is_empty():
		return WorldSeed.from_value(int(entry["value"]))
	return WorldSeed.from_text(text)


static func worlds() -> Array[WorldSeed]:
	var out: Array[WorldSeed] = []
	for name in world_names():
		out.append(world(name))
	return out


## The generation binding for one named world — what a pass under test is constructed
## with. Null when the seed configuration is refused, which `self_check()` rules out for
## every fixture world, so a null here is a real regression in `GenerationHash`.
static func hash_for(name: String) -> GenerationHash:
	var seed_config := world(name)
	if seed_config == null:
		return null
	return GenerationHash.for_world(seed_config)


# ---------------------------------------------------------------------------
# Coordinate samples
# ---------------------------------------------------------------------------
#
# Every list is returned freshly built, never as a shared constant: a test that sorts or
# appends to what it was handed must not change what the next test samples.

## Voxels worth asking a 3D pass about.
static func voxels() -> Array[Vector3i]:
	var out: Array[Vector3i] = [
		Vector3i(0, 0, 0),           # the origin — every off-by-one lands on or beside it
		Vector3i(1, 2, 3),           # an ordinary interior cell, all axes distinct
		Vector3i(-1, -1, -1),        # the cell diagonally opposite the origin
		Vector3i(-7, 5, -9),         # the coordinate whose sign symmetry brick 058 found,
		Vector3i(7, 5, 9),           # ... with its mirror, so a returning symmetry shows
		Vector3i(15, 0, 15),         # last voxel of chunk (0, 0, 0)
		Vector3i(16, 0, 16),         # first voxel of the next chunk along
		Vector3i(-1, 0, -1),         # last voxel of the chunk below the origin — the cell
		Vector3i(-16, 0, -16),       # ... whose chunk truncating division gets wrong
		Vector3i(1023, 0, 1023),     # last column of region (0, 0)
		Vector3i(1024, 0, 1024),     # first column of region (1, 1)
		Vector3i(-1024, 0, -1024),   # first column of region (-1, -1)
		Vector3i(0, WorldBounds.HALF_EXTENT_VERTICAL_VOXELS - 1, 0),   # world ceiling
		Vector3i(0, -WorldBounds.HALF_EXTENT_VERTICAL_VOXELS, 0),      # world floor
		# The far corners. Coordinates this large overflow a 32-bit intermediate and lose
		# exactness in a float one, so a pass that reaches for either fails only here.
		Vector3i(WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS - 1, 0,
				WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS - 1),
		Vector3i(-WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS, 0,
				-WorldBounds.HALF_EXTENT_HORIZONTAL_VOXELS),
	]
	return out


## Columns worth asking a per-column pass (elevation, temperature, humidity, biome) about.
## Deliberately not just `voxels()` flattened: a column list with duplicates would make a
## sample count meaningless, and the horizontal cases are the ones that matter here.
static func columns() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for voxel in voxels():
		var column := GenerationGrid.voxel_to_column(voxel)
		if not out.has(column):
			out.append(column)
	# Two columns that share one coordinate: a pass that folds x and z together answers
	# the same for both, which is a real bug and invisible on a diagonal-only sample set.
	out.append(Vector2i(9, -9))
	out.append(Vector2i(-9, 9))
	return out


static func chunks() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for voxel in voxels():
		var chunk := GenerationGrid.voxel_to_chunk(voxel)
		if not out.has(chunk):
			out.append(chunk)
	return out


static func chunk_columns() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for chunk in chunks():
		var chunk_column := GenerationGrid.chunk_to_chunk_column(chunk)
		if not out.has(chunk_column):
			out.append(chunk_column)
	return out


## Regions worth asking a macro-placement pass about. Every one is inside the region grid
## (`GenerationGrid.is_region_in_world()`), including its two extreme corners — a region
## outside it has no defined content, so sampling one would test nothing.
static func regions() -> Array[Vector2i]:
	var out: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 1),
		Vector2i(-1, -1),
		Vector2i(3, -5),
		Vector2i(-5, 3),
		Vector2i(GenerationGrid.HALF_REGIONS_PER_AXIS - 1,
				GenerationGrid.HALF_REGIONS_PER_AXIS - 1),
		Vector2i(-GenerationGrid.HALF_REGIONS_PER_AXIS,
				-GenerationGrid.HALF_REGIONS_PER_AXIS),
	]
	return out


# ---------------------------------------------------------------------------
# Determinism checks
# ---------------------------------------------------------------------------
#
# All of these return "" when the property holds and a reason when it does not — the same
# convention `WorldSeed.validate()`, `GenerationHash.refuse_reason()` and
# `GenerationVersion.self_check()` use, so a check reads the same in a test, in a debug
# probe and in a server-side self-test.
#
# A `sampler` is `func(coordinate) -> Variant`. Where a check takes a **factory** instead,
# it is because the property can only be observed against a *freshly built* pass: one that
# caches or accumulates as it generates answers a repeat call consistently and is still
# order-dependent. Two factory shapes, one per question:
#
# - `determinism_reason()` — `func() -> Callable`, one world. A test that already holds a
#   binding passes `factory.bind(hash)`.
# - `seed_sensitivity_reason()` — `func(hash: GenerationHash) -> Callable`, because the
#   check is what supplies the worlds.

## The whole determinism contract for one world: repeatable, then order-free.
## The single call a Phase D pass's own test makes.
static func determinism_reason(sampler_factory: Callable, samples: Array) -> String:
	var reason := repeatability_reason(sampler_factory.call() as Callable, samples)
	if not reason.is_empty():
		return reason
	return order_independence_reason(sampler_factory, samples)


## Sampling the same coordinate twice gives the same answer.
static func repeatability_reason(sampler: Callable, samples: Array) -> String:
	for sample in samples:
		var first: Variant = sampler.call(sample)
		var second: Variant = sampler.call(sample)
		if not values_equal(first, second):
			return "%s sampled twice gave %s then %s" % [sample, first, second]
	return ""


## The answer at a coordinate does not depend on which coordinates were sampled before it.
##
## Three visit orders against three freshly built passes: forward, reversed, and odd
## indices before even ones. This is the property a player actually depends on — walking
## into a chunk from the east must build the same ground as walking in from the west
## (`docs/rng.md` §2).
static func order_independence_reason(sampler_factory: Callable, samples: Array) -> String:
	var count := samples.size()
	var baseline: Array = []
	var forward := sampler_factory.call() as Callable
	for sample in samples:
		baseline.append(forward.call(sample))

	for order in [_reversed_order(count), _interleaved_order(count)]:
		var sampler := sampler_factory.call() as Callable
		for index in order:
			var value: Variant = sampler.call(samples[index])
			if not values_equal(value, baseline[index]):
				return "%s gave %s in visit order %s, %s in forward order" % [
						samples[index], value, order, baseline[index]]
	return ""


## Two different worlds are two different worlds.
##
## Every pair of fixture worlds must disagree somewhere in `samples`. A pass that forgot
## to mix the seed in — or mixed it in somewhere the result never reaches — produces one
## identical world for every seed, which no single-world test can see.
static func seed_sensitivity_reason(sampler_factory: Callable, samples: Array) -> String:
	var names := world_names()
	var sampled: Dictionary = {}
	for name in names:
		var bound := hash_for(name)
		if bound == null:
			return "fixture world '%s' was refused by GenerationHash" % name
		var sampler := sampler_factory.call(bound) as Callable
		var values: Array = []
		for sample in samples:
			values.append(sampler.call(sample))
		sampled[name] = values

	for i in names.size():
		for j in range(i + 1, names.size()):
			if _all_equal(sampled[names[i]], sampled[names[j]]):
				return "worlds '%s' and '%s' agree at every one of %d samples" % [
						names[i], names[j], samples.size()]
	return ""


## Every sampled value is a float inside `[minimum, maximum]`.
##
## Worth running even on a field whose formula obviously cannot leave its range: the
## failure this catches is a NaN, which compares false against both ends and so is
## reported here rather than propagating into terrain as a silently missing chunk.
static func range_reason(sampler: Callable, samples: Array, minimum: float,
		maximum: float) -> String:
	for sample in samples:
		var value: Variant = sampler.call(sample)
		if typeof(value) != TYPE_FLOAT:
			return "%s gave %s, which is not a float" % [sample, value]
		var number: float = value
		if is_nan(number):
			return "%s gave NaN" % sample
		if number < minimum or number > maximum:
			return "%s gave %s, outside [%s, %s]" % [sample, number, minimum, maximum]
	return ""


## At least `minimum_distinct` different values across the samples.
##
## The check that a pass is actually doing something. A stub returning `0.0`, a field
## whose amplitude ended up zero, and a mask nothing ever passes are all deterministic,
## all in range, and all wrong.
static func variation_reason(sampler: Callable, samples: Array,
		minimum_distinct: int = 2) -> String:
	var seen: Dictionary = {}
	for sample in samples:
		seen[sampler.call(sample)] = true
	if seen.size() < minimum_distinct:
		return "only %d distinct value(s) across %d samples, expected at least %d" % [
				seen.size(), samples.size(), minimum_distinct]
	return ""


# ---------------------------------------------------------------------------
# Golden signatures
# ---------------------------------------------------------------------------

## Starting accumulator for `signature()`. Arbitrary and fixed forever: changing it
## invalidates every pinned signature at once for no information.
const SIGNATURE_SEED := 0x5EED0059

## A 16-hex-digit digest of what a sampler answered across `samples`, in order.
##
## This is the "golden output" half of a fixture. A pass pins one string per world; any
## change to the algorithm changes it, and the test that fails then asks the question that
## matters: **is this a bug, or a generation version bump?** (`docs/world-generation.md`
## §2.1). Pinning a signature is cheap; pinning a hundred individual expected values is
## how a test file stops being read.
##
## The digest is order-sensitive and type-strict on purpose — an `int` 1 and a `float` 1.0
## digest differently, because a field that started returning integers is a real change.
static func signature(sampler: Callable, samples: Array) -> String:
	var accumulator := SIGNATURE_SEED
	for index in samples.size():
		var value: Variant = sampler.call(samples[index])
		accumulator = DeterministicRng.mix64(accumulator * 31 + index)
		accumulator = DeterministicRng.mix64(accumulator ^ (typeof(value) * 0x9E3779B1))
		accumulator = DeterministicRng.mix64(accumulator ^ value_bits(value))
	return "%08x%08x" % [(accumulator >> 32) & 0xFFFFFFFF, accumulator & 0xFFFFFFFF]


## The bits of one sampled value, exactly — never `str()`, which prints a float to a
## handful of digits and would digest two genuinely different terrains identically.
##
## A type this does not list falls back to its string form, which is lossy; a pass whose
## output is not one of these should digest a projection of it instead.
static func value_bits(value: Variant) -> int:
	match typeof(value):
		TYPE_BOOL:
			return 0x1F if value else 0x2E
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return _float_bits(value)
		TYPE_VECTOR2I:
			var v2i: Vector2i = value
			return DeterministicRng.mix64(v2i.x * 31 + v2i.y)
		TYPE_VECTOR3I:
			var v3i: Vector3i = value
			return DeterministicRng.mix64(DeterministicRng.mix64(v3i.x * 31 + v3i.y) + v3i.z)
		TYPE_VECTOR2:
			var v2: Vector2 = value
			return DeterministicRng.mix64(_float_bits(v2.x) * 31 + _float_bits(v2.y))
		TYPE_VECTOR3:
			var v3: Vector3 = value
			return DeterministicRng.mix64(
					DeterministicRng.mix64(_float_bits(v3.x) * 31 + _float_bits(v3.y))
					+ _float_bits(v3.z))
		_:
			return DeterministicRng.hash_string(str(value))


# ---------------------------------------------------------------------------
# Self-check
# ---------------------------------------------------------------------------

## Empty string when the fixtures themselves are coherent, otherwise the reason.
##
## Same shape as `GenerationVersion.self_check()`, and for the same reason: a fixture set
## that has quietly drifted — a seed that no longer hashes to its pinned value, a sample
## that has fallen outside `WorldBounds` — makes every test built on it meaningless while
## they all still pass.
static func self_check() -> String:
	var values: Dictionary = {}
	for name in world_names():
		var entry: Dictionary = WORLDS[name]
		var pinned: int = entry["value"]
		if values.has(pinned):
			return "worlds '%s' and '%s' are the same world" % [values[pinned], name]
		values[pinned] = name
		var text: String = entry["text"]
		if not text.is_empty() and WorldHash.seed_from_text(text) != pinned:
			return ("fixture world '%s': '%s' now hashes to %d, not the pinned %d — "
					+ "the world seed hash changed") % [
							name, text, WorldHash.seed_from_text(text), pinned]
		var built := world(name)
		if built == null:
			return "fixture world '%s' could not be built" % name
		if built.value != pinned:
			return "fixture world '%s' built seed %d, pinned %d" % [name, built.value, pinned]
		var invalid := built.validate()
		if not invalid.is_empty():
			return "fixture world '%s' is not a valid seed configuration: %s" % [name, invalid]
		if GenerationHash.for_world(built) == null:
			return "fixture world '%s' was refused by GenerationHash" % name

	var seen_voxels: Dictionary = {}
	for voxel in voxels():
		if seen_voxels.has(voxel):
			return "voxel sample %s is listed twice" % voxel
		seen_voxels[voxel] = true
		if not WorldBounds.contains(voxel):
			return "voxel sample %s is outside the world" % voxel
	for region in regions():
		if not GenerationGrid.is_region_in_world(region):
			return "region sample %s is outside the region grid" % region

	return _coverage_reason()


## The sample set has to keep containing the cases it exists for. Adding a sample is free;
## deleting the one negative-axis voxel would quietly turn every determinism test in
## Phase D into a positive-quadrant-only test.
static func _coverage_reason() -> String:
	var has_negative := false
	var has_cell_last := false
	var has_cell_first := false
	for voxel in voxels():
		if voxel.x < 0 and voxel.z < 0:
			has_negative = true
		var inside := GenerationGrid.voxel_in_chunk(voxel)
		if inside.x == GenerationGrid.CHUNK_SIZE_VOXELS - 1:
			has_cell_last = true
		if inside == Vector3i.ZERO:
			has_cell_first = true
	if not has_negative:
		return "no voxel sample has negative x and z"
	if not has_cell_last:
		return "no voxel sample sits on a chunk's last cell"
	if not has_cell_first:
		return "no voxel sample sits on a chunk origin"

	var has_negative_region := false
	for region in regions():
		if region.x < 0 or region.y < 0:
			has_negative_region = true
	if not has_negative_region:
		return "no region sample is negative"
	return ""


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Type-strict equality, matching `TestCase._values_equal()`: `1` and `1.0` are equal
## under GDScript `==`, and a field that started returning integers is a change worth
## failing on.
static func values_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	return a == b


static func _all_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for index in a.size():
		if not values_equal(a[index], b[index]):
			return false
	return true


## The exact 64 bits of a double. `-0.0` is normalised to `0.0`: the two are equal
## everywhere else in the language, so digesting them apart would report a difference no
## player could observe.
static func _float_bits(value: float) -> int:
	var normalised := 0.0 if value == 0.0 else value
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, normalised)
	return bytes.decode_s64(0)


static func _reversed_order(count: int) -> Array[int]:
	var out: Array[int] = []
	for index in range(count - 1, -1, -1):
		out.append(index)
	return out


## Odd indices first, then even ones — a permutation for every size, unlike a stride,
## which degenerates whenever the stride divides the count.
static func _interleaved_order(count: int) -> Array[int]:
	var out: Array[int] = []
	for index in count:
		if index % 2 == 1:
			out.append(index)
	for index in count:
		if index % 2 == 0:
			out.append(index)
	return out
