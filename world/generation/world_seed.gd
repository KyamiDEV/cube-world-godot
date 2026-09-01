class_name WorldSeed
extends RefCounted
## The identity of one generated world (backlog brick 056): the numeric seed every
## generation pass hashes against, the text a player typed to get it, and the generation
## algorithm version the world was created under.
##
## `docs/rng.md` §6 states the rule this type exists to make unavoidable: **a seed alone
## does not identify a world; the pair `(seed, generation version)` does**. Passing a
## bare `int` around lets the two drift apart — a world created under generation version
## 1 and later re-generated under version 2 is two worlds stitched together
## (`docs/persistence.md` §3). Every generation call site therefore takes a `WorldSeed`,
## not an integer, and reads `value` from it at the last moment.
##
## Both sides of a session hold one, and they must agree: `mismatch_reason()` is the
## check, and `docs/reference/world-generation-authority.md` is why it matters — the
## client is allowed to generate terrain locally for presentation, so seed parity is a
## network-visible contract, not an internal detail.
##
## Contract: `docs/world-generation.md` §1. Consumed by `WorldHash` (positional
## generation) and `DeterministicRng` (sequential server rolls) via `rng_for()`.

## Longest player-typed seed text accepted. A seed string travels in every save header
## and, later, in the session handshake; an unbounded one is a hole in both. Long enough
## for a memorable phrase, short enough to never be a payload.
const MAX_TEXT_LENGTH := 64

## Save-header key carrying `text`. The numeric seed and the generation version already
## have header keys of their own, owned by `SaveVersion.REQUIRED_FIELDS`.
const HEADER_TEXT_KEY := "seed_text"

## Numeric seed. This is what `WorldHash` hashes and what `DeterministicRng` streams
## from; everything else here is identity and provenance around it.
var value: int

## What a player typed, trimmed, or "" when the seed was not typed (an arbitrary new
## world, or one restored from a header written before the field existed). Kept so a bug
## report can quote the seed a player actually entered rather than a hash of it.
var text: String

## Generation algorithm version this world was created under. Pinned at creation from
## `GenerationVersion.CURRENT` and then carried unchanged for the life of the world — a
## loaded world keeps its own version even on a newer build. This field only records
## which version applies; the version *lifecycle* (what a bump means, which versions a
## build still implements, what happens to a world on a retired one) is
## `world/generation/generation_version.gd` (brick 057, `docs/world-generation.md` §2).
var generation_version: int


func _init(p_value: int, p_text: String = "",
		p_generation_version: int = GenerationVersion.CURRENT) -> void:
	value = p_value
	text = p_text
	generation_version = p_generation_version


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## From what a player typed. Numeric text is taken at face value so "12345" in a bug
## report reproduces; anything else goes through the project's own stable string hash
## (`WorldHash.seed_from_text()`, `docs/rng.md` §6).
##
## Empty text yields seed 0 — a real, reproducible world, not an error. A blank seed
## field in a UI means "pick one for me", which is `arbitrary()`, and that translation
## belongs to the UI, not here.
static func from_text(p_text: String) -> WorldSeed:
	var trimmed := p_text.strip_edges()
	return WorldSeed.new(WorldHash.seed_from_text(trimmed), trimmed)


## From a seed a player did not type: a numeric value chosen elsewhere (a share link, a
## test fixture, a copied header).
static func from_value(p_value: int) -> WorldSeed:
	return WorldSeed.new(p_value)


## A new world nobody chose a seed for.
##
## This is the **one** deliberately unreproducible call in the generation stack, and it
## is unreproducible in the only harmless way: it picks *which* world to create, once,
## and is never consulted again. Everything downstream is a pure function of the seed it
## returned. It avoids the engine's global randomness anyway (`docs/rng.md` §1 forbids it
## under `world/`, and `tests/unit/test_rng_discipline.gd` enforces that) — wall clock,
## uptime counter and process id, run through the project's own stable hash, are enough
## to separate two worlds created a millisecond apart in two processes.
static func arbitrary() -> WorldSeed:
	var entropy := "%d/%d/%d" % [
		int(Time.get_unix_time_from_system() * 1000.0),
		Time.get_ticks_usec(),
		OS.get_process_id(),
	]
	return WorldSeed.new(DeterministicRng.hash_string(entropy))


## Reads back the seed a save header records. Returns null (logged) when the header is
## not structurally sound — `SaveVersion.validate_header()` is the single authority on
## that, so this never grows a second, divergent idea of a valid header.
##
## The header's own `generation_version` wins over the build's constant: that is exactly
## the "a world keeps generating with the version it was created with" rule of
## `docs/persistence.md` §3.
static func from_header(header: Dictionary) -> WorldSeed:
	var reason := SaveVersion.validate_header(header)
	if not Log.check(reason.is_empty(), Log.CH_GEN, "cannot read world seed from header",
			{"reason": reason}):
		return null
	var stored_text := str(header.get(HEADER_TEXT_KEY, ""))
	return WorldSeed.new(int(header["seed"]), stored_text, int(header["generation_version"]))


# ---------------------------------------------------------------------------
# Validation and identity
# ---------------------------------------------------------------------------

## Empty string when this configuration is coherent, otherwise the reason — same
## string-reason convention `StableId`, `BlockDefinition` and `EditBlockCommand` use for
## a data-shape self-check.
##
## The round-trip rule is the one worth having: whenever `text` is set, re-hashing it
## must produce `value`. A pair that has drifted apart is worse than no text at all,
## because the seed a player is shown, quotes in a bug report and types back in would
## silently create a different world.
func validate() -> String:
	if generation_version < 1:
		return "generation_version must be positive"
	if text.length() > MAX_TEXT_LENGTH:
		return "seed text is longer than %d characters" % MAX_TEXT_LENGTH
	if text.is_empty():
		return ""
	if text != text.strip_edges():
		return "seed text must be stored trimmed"
	if WorldHash.seed_from_text(text) != value:
		return "seed text '%s' does not hash to seed value %d" % [text, value]
	return ""


## What to show a player and what they can type back to get this world again. The typed
## text when there is one, otherwise the number itself — which `from_text()` reads at
## face value, so the round trip holds either way.
func display_text() -> String:
	return text if not text.is_empty() else str(value)


## Empty string when two configurations describe the same world, otherwise why they do
## not. Meant for the session handshake: a client generating terrain from a different
## seed or a different algorithm than the server produces a world that looks right and
## is wrong, so the mismatch has to be a hard, explained failure rather than a drift.
##
## `text` is deliberately not compared — it is provenance, not identity. Two players who
## reached the same seed by different routes are in the same world.
func mismatch_reason(other: WorldSeed) -> String:
	if other == null:
		return "no seed configuration to compare against"
	if value != other.value:
		return "seed differs: %d vs %d" % [value, other.value]
	if generation_version != other.generation_version:
		return "generation version differs: %d vs %d" % [
				generation_version, other.generation_version]
	return ""


func matches(other: WorldSeed) -> bool:
	return mismatch_reason(other).is_empty()


# ---------------------------------------------------------------------------
# Consumption
# ---------------------------------------------------------------------------

## A named sequential stream for server-side gameplay rolls, seeded from this world
## (`docs/rng.md` §6, last bullet). Two subsystems asking for different keys never share
## a sequence, so a change in how many values one draws cannot shift the other's results.
##
## World *generation* does not come through here: it is positional, and takes `value`
## directly via `WorldHash` (`docs/rng.md` §2).
func rng_for(key: String) -> DeterministicRng:
	return DeterministicRng.from_seed_and_key(value, key)


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

## The save header for this world. Built by `SaveVersion.make_header()` so the container
## and data versions stay that class's business, then overridden with this world's own
## generation version — the build's constant describes the build, not the world.
func to_header(extra: Dictionary = {}) -> Dictionary:
	var fields := {
		"generation_version": generation_version,
		HEADER_TEXT_KEY: text,
	}
	for key in extra:
		fields[key] = extra[key]
	return SaveVersion.make_header(value, fields)


## Log/diagnostic context, so a call site does not spell out the same three keys.
func to_context() -> Dictionary:
	return {"seed": value, "seed_text": display_text(), "gen_version": generation_version}
