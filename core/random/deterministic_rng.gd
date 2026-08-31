class_name DeterministicRng
extends RefCounted
## Reproducible pseudo-random number stream (backlog brick 015).
##
## The generator is **splitmix64**, implemented here rather than taken from the engine
## on purpose: world generation and server rolls must produce the same numbers on every
## machine and in every future engine build. `randi()`, `randf()` and
## `RandomNumberGenerator` are engine implementation details that may change; a world
## that regenerates differently after an engine update is a corrupted world.
##
## Two independent uses, both served from here:
##
## - **Sequential** — server gameplay rolls (loot, crits, spawn variation). Order
##   matters and the stream's state is part of the world's saved state.
## - **Positional** — world generation, via `WorldHash`, which builds a stream from
##   `(seed, coordinates, salt)` so a chunk generates identically no matter when or in
##   what order it is visited.
##
## Contract and rules: `docs/rng.md`.
##
## Not thread-safe: one instance belongs to one owner. Generation worker threads take a
## positional stream of their own rather than sharing one.

## splitmix64 constants, written as signed 64-bit values because GDScript integers are
## signed and the unsigned literals do not fit.
const _GAMMA := -7046029254386353131      # 0x9E3779B97F4A7C15
const _MIX_A := -4658895280553007687      # 0xBF58476D1CE4E5B9
const _MIX_B := -7723592293110705685      # 0x94D049BB133111EB

## FNV-1a 64 parameters, for hashing stable IDs into salts. String.hash() is not used:
## it is 32-bit and engine-defined, so it is not a stable key across versions.
const _FNV_OFFSET := -3750763034362895579  # 0xCBF29CE484222325
const _FNV_PRIME := 1099511628211          # 0x100000001B3

const _MAX_INT := 9223372036854775807

var _state: int = 0


func _init(initial_seed: int = 0) -> void:
	_state = initial_seed


## Named constructor, for call sites where `DeterministicRng.new(seed)` would read as a
## magic number.
static func from_seed(seed_value: int) -> DeterministicRng:
	return DeterministicRng.new(seed_value)


## Builds a stream from a world seed and a stable string key, e.g. a system name or a
## content ID. Two systems using the same world seed but different keys never share a
## sequence.
static func from_seed_and_key(seed_value: int, key: String) -> DeterministicRng:
	return DeterministicRng.new(seed_value ^ hash_string(key))


# ---------------------------------------------------------------------------
# Core generator
# ---------------------------------------------------------------------------

## Next raw 64-bit value. Signed, so it spans the full negative and positive range;
## treat it as bits, not as a number.
func next_u64() -> int:
	_state += _GAMMA
	var z := _state
	z = (z ^ _logical_shift_right(z, 30)) * _MIX_A
	z = (z ^ _logical_shift_right(z, 27)) * _MIX_B
	return z ^ _logical_shift_right(z, 31)


## Uniform float in `[0, 1)`. Uses the top 53 bits, which is exactly the mantissa a
## double can represent without gaps — taking the low bits instead would waste them.
func next_float() -> float:
	return float(_logical_shift_right(next_u64(), 11)) / 9007199254740992.0


## Uniform float in `[minimum, maximum)`.
func next_range(minimum: float, maximum: float) -> float:
	return minimum + next_float() * (maximum - minimum)


## Uniform integer in `[minimum, maximum]`, inclusive at both ends.
##
## Rejection sampling, not modulo: plain `% span` over-represents the low values
## whenever the span does not divide the range evenly. That bias is invisible in casual
## testing and shows up as loot tables that quietly favour their first entries.
func next_int(minimum: int, maximum: int) -> int:
	if maximum <= minimum:
		return minimum
	var span := maximum - minimum + 1
	# Largest multiple of `span` that fits in [0, _MAX_INT]; values at or above it would
	# make the last, partial block more likely than the others.
	@warning_ignore("integer_division")
	var zone := (_MAX_INT / span) * span
	var value := _next_non_negative()
	while value >= zone:
		value = _next_non_negative()
	return minimum + (value % span)


## True with the given probability. `probability <= 0` is never true and `>= 1` is
## always true, without consuming a value in either case — so a disabled roll cannot
## shift the stream and change every later result.
func next_bool(probability: float = 0.5) -> bool:
	if probability <= 0.0:
		return false
	if probability >= 1.0:
		return true
	return next_float() < probability


## Uniform element from a non-empty array; `null` for an empty one.
func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[next_int(0, items.size() - 1)]


## Index chosen proportionally to `weights`. Returns -1 when every weight is zero or
## negative, so callers must handle "nothing was eligible" explicitly.
func pick_weighted(weights: PackedFloat64Array) -> int:
	var total := 0.0
	for weight in weights:
		if weight > 0.0:
			total += weight
	if total <= 0.0:
		return -1
	var roll := next_float() * total
	for i in weights.size():
		if weights[i] <= 0.0:
			continue
		roll -= weights[i]
		if roll < 0.0:
			return i
	return weights.size() - 1  # only reachable through float rounding at the very end


## Fisher-Yates on a copy. The input is left alone so a caller cannot accidentally
## reorder a shared definition list.
func shuffled(items: Array) -> Array:
	var out := items.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := next_int(0, i)
		var swap: Variant = out[i]
		out[i] = out[j]
		out[j] = swap
	return out


# ---------------------------------------------------------------------------
# Streams
# ---------------------------------------------------------------------------

## A new independent stream derived from this one's current state and a salt.
##
## Use this instead of sharing a stream between subsystems: a fork means one subsystem
## drawing a different number of values can never shift another subsystem's results.
## The parent stream advances once, so the same call sequence still reproduces exactly.
func derive(salt: int) -> DeterministicRng:
	return DeterministicRng.new(_mix(next_u64() ^ salt))


func derive_named(key: String) -> DeterministicRng:
	return derive(hash_string(key))


## Opaque state, for saving. Restore with `set_state()` to resume an identical sequence.
func get_state() -> int:
	return _state


func set_state(state: int) -> void:
	_state = state


# ---------------------------------------------------------------------------
# Hashing helpers
# ---------------------------------------------------------------------------

## Stable 64-bit hash of a string. FNV-1a, defined here so it never changes: it keys
## saved data and network content, so an engine upgrade must not be able to move it.
static func hash_string(text: String) -> int:
	var hash_value := _FNV_OFFSET
	for byte in text.to_utf8_buffer():
		hash_value = (hash_value ^ byte) * _FNV_PRIME
	return _mix(hash_value)


## splitmix64 finalizer, exposed because positional hashing (`WorldHash`) needs the same
## avalanche without stepping a stream.
static func mix64(value: int) -> int:
	return _mix(value)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

static func _mix(value: int) -> int:
	var z := value
	z = (z ^ _logical_shift_right(z, 30)) * _MIX_A
	z = (z ^ _logical_shift_right(z, 27)) * _MIX_B
	return z ^ _logical_shift_right(z, 31)


## Non-negative 63-bit value: the raw output with the sign bit cleared.
func _next_non_negative() -> int:
	return next_u64() & _MAX_INT


## GDScript's `>>` sign-extends, so shifting a negative value keeps its high bits set.
## Masking off what the shift should have vacated gives the logical shift the mixing
## functions require.
static func _logical_shift_right(value: int, bits: int) -> int:
	return (value >> bits) & ((1 << (64 - bits)) - 1)
