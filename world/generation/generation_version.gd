class_name GenerationVersion
extends RefCounted
## The lifecycle of the world-generation algorithm version (backlog brick 057).
##
## `SaveVersion` (017) owns the *number*: `GENERATION_VERSION` is the algorithm this
## build writes, and a save header carries the one a world was created under.
## `WorldSeed` (056) records which version applies to one world. Neither answers the
## three questions a version only becomes useful by answering:
##
## | Question | Answered by |
## |---|---|
## | when must the number be bumped? | `docs/world-generation.md` §2.1 — and `self_check()`, which fails the suite when a bump is left half-done |
## | which algorithms can this build still reproduce? | `SUPPORTED` |
## | what happens to a world whose algorithm is gone? | `status()` / `explain()`, and `classify_header()` refusing the load with a reason |
##
## The rule underneath all three is `docs/persistence.md` §3: a world keeps generating
## with the version it was created under, and is never silently re-generated under a
## newer one. A build therefore supports a *set* of versions, not just the newest.
##
## Contract: `docs/world-generation.md` §2.
##
## Static-only: never instantiate.

## The algorithm new worlds are created under. Same number as
## `SaveVersion.GENERATION_VERSION`, which stays the canonical constant — `core/` cannot
## depend on `world/`, so the number lives there and its lifecycle lives here.
const CURRENT := SaveVersion.GENERATION_VERSION

## Every generation algorithm this build can still reproduce, oldest first. A world on a
## version listed here loads; a world on any other version does not.
##
## Entries are only ever *removed* deliberately (a retirement), and removing one means
## every world created under it stops loading. Adding a version happens as part of a bump
## — see `docs/world-generation.md` §2.5 for the checklist `self_check()` enforces.
const SUPPORTED: PackedInt32Array = [1]

## One line per version, for the load screen and the log. Kept for retired versions too:
## a refusal that names what the world was made with is a bug report; one that says only
## "cannot load" is a deleted save (`docs/persistence.md` §2).
const SUMMARIES := {
	1: "initial Phase D generation pipeline (splitmix64 / FNV-1a 64, bricks 056-090)",
}

## Where one version stands relative to this build.
enum Status {
	## The algorithm this build writes. New worlds get this one.
	CURRENT_VERSION,
	## Older, still implemented: worlds on it load and keep generating with it.
	LEGACY,
	## Older and no longer implemented. Worlds on it are refused, not re-generated.
	RETIRED,
	## Newer than this build knows. Written by a newer build.
	FUTURE,
	## Not a version number at all.
	INVALID,
}


# ---------------------------------------------------------------------------
# The supported set
# ---------------------------------------------------------------------------

## Every version this build can reproduce. Pass this wherever `SaveVersion` accepts an
## `available_generation_versions` list; `classify_header()` already does.
static func supported() -> PackedInt32Array:
	return SUPPORTED


static func is_supported(version: int) -> bool:
	return SUPPORTED.has(version)


## Oldest world this build can still open. Kept in step with
## `SaveVersion.MIN_SUPPORTED_GENERATION_VERSION` by `self_check()`.
static func oldest_supported() -> int:
	return SUPPORTED[0]


# ---------------------------------------------------------------------------
# Status of one version
# ---------------------------------------------------------------------------

static func status(version: int) -> Status:
	return status_of(version, CURRENT, SUPPORTED)


## The pure form: what `version` would be to a build declaring `p_current` and
## `p_supported`. Separated out because it is the half worth testing against version
## histories this build does not have yet (a retirement, a hole, a newer peer), and
## because the session handshake (bricks 235-236) has to answer this question about the
## *other* side's declared set, not its own.
static func status_of(version: int, p_current: int, p_supported: PackedInt32Array) -> Status:
	if version < 1:
		return Status.INVALID
	if version > p_current:
		return Status.FUTURE
	if not p_supported.has(version):
		return Status.RETIRED
	if version == p_current:
		return Status.CURRENT_VERSION
	return Status.LEGACY


static func status_name(p_status: Status) -> String:
	match p_status:
		Status.CURRENT_VERSION:
			return "CURRENT_VERSION"
		Status.LEGACY:
			return "LEGACY"
		Status.RETIRED:
			return "RETIRED"
		Status.FUTURE:
			return "FUTURE"
		_:
			return "INVALID"


## What the version did, or "" when this build never knew it.
static func summary(version: int) -> String:
	return str(SUMMARIES.get(version, ""))


## Human-readable, for the load screen and the log.
static func explain(version: int) -> String:
	var described := summary(version)
	var suffix := "" if described.is_empty() else " (%s)" % described
	match status(version):
		Status.CURRENT_VERSION:
			return "generation version %d is current%s" % [version, suffix]
		Status.LEGACY:
			return "generation version %d%s is older than this build writes (%d), and still supported: the world keeps generating with %d" % [
					version, suffix, CURRENT, version]
		Status.RETIRED:
			return "generation version %d%s is no longer implemented by this build, which supports %s" % [
					version, suffix, str(SUPPORTED)]
		Status.FUTURE:
			return "generation version %d was written by a newer build (this build writes %d)" % [
					version, CURRENT]
		_:
			return "generation version %d is not a valid version number" % version


# ---------------------------------------------------------------------------
# Save headers
# ---------------------------------------------------------------------------

## Classifies a save header against this build. **The only supported way to ask** —
## `SaveVersion.classify()` called without a list falls back to the
## `MIN_SUPPORTED_GENERATION_VERSION..GENERATION_VERSION` range, which is right only
## while `SUPPORTED` has no holes; a retired middle version would slip through it.
static func classify_header(header: Dictionary) -> SaveVersion.Compatibility:
	return SaveVersion.classify(header, SUPPORTED)


static func can_load_header(header: Dictionary) -> bool:
	return SaveVersion.can_load(header, SUPPORTED)


static func explain_header(header: Dictionary) -> String:
	return SaveVersion.explain(header, SUPPORTED)


# ---------------------------------------------------------------------------
# Self-consistency
# ---------------------------------------------------------------------------

## Empty string when this build's version declaration is coherent, otherwise the reason
## — same string-reason convention `SaveVersion.validate_header()` and `WorldSeed`
## already use. `tests/unit/test_generation_version.gd` asserts it, which is what turns
## `docs/world-generation.md` §2.5's bump checklist from a habit into a failing suite: a
## bumped `GENERATION_VERSION` with no matching `SUPPORTED`/`SUMMARIES` entry stops the
## build here rather than at the first unreadable save.
static func self_check() -> String:
	return self_check_of(CURRENT, SUPPORTED, SaveVersion.MIN_SUPPORTED_GENERATION_VERSION,
			SUMMARIES)


## The pure form of `self_check()`, for the same reason `status_of()` exists.
static func self_check_of(p_current: int, p_supported: PackedInt32Array,
		p_min_supported: int, p_summaries: Dictionary) -> String:
	if p_current < 1:
		return "current generation version must be positive"
	if p_supported.is_empty():
		return "no generation version is supported"

	var previous := 0
	for version in p_supported:
		if version < 1:
			return "supported generation version %d must be positive" % version
		if version <= previous:
			return "supported generation versions must be sorted and unique, found %d after %d" % [
					version, previous]
		previous = version

	# A build must be able to reproduce what it writes, or every world it creates is
	# unloadable by the build that made it.
	if p_supported[p_supported.size() - 1] != p_current:
		return "current generation version %d is not the newest supported (%d)" % [
				p_current, p_supported[p_supported.size() - 1]]
	# Both ends of the range SaveVersion falls back to must name the same worlds this
	# list does, or two files disagree about which saves still open.
	if p_supported[0] != p_min_supported:
		return "oldest supported generation version %d does not match SaveVersion's %d" % [
				p_supported[0], p_min_supported]

	for version in p_supported:
		if not p_summaries.has(version):
			return "supported generation version %d has no summary" % version
	for key in p_summaries:
		if typeof(key) != TYPE_INT:
			return "summary keys must be version numbers"
		if int(key) < 1 or int(key) > p_current:
			return "summary for generation version %s is outside 1..%d" % [str(key), p_current]
	return ""
