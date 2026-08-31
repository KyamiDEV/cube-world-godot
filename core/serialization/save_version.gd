class_name SaveVersion
extends RefCounted
## Version and compatibility rules for anything this project writes to disk
## (backlog brick 017).
##
## Four numbers travel with every world, and they answer four different questions
## (`CLAUDE.md` §11). Collapsing them into one "save version" is the mistake this class
## exists to prevent: adding a block would then invalidate every save, while a change to
## the terrain generator — which genuinely does change what the world looks like — would
## be indistinguishable from it.
##
## | Number | Answers | Changes when |
## |---|---|---|
## | `WORLD_FORMAT_VERSION` | can this build parse the file at all? | the container layout, field names or encoding change |
## | `GENERATION_VERSION` | would ungenerated terrain match what is already there? | any generator, noise constant, or the RNG algorithm changes |
## | `DATA_VERSION` | do the content catalogues still line up? | definitions are added, removed or renamed |
## | `seed` | which world is this? | never, for a given world |
##
## Contract: `docs/persistence.md`.
##
## Static-only: never instantiate.

## Container layout this build writes.
const WORLD_FORMAT_VERSION := 1

## Oldest container layout this build can still read, migrating forward. Raising this
## drops support for older saves and is a deliberate, announced decision.
const MIN_SUPPORTED_FORMAT_VERSION := 1

## Identity of the deterministic generation pipeline this build implements. A world
## records the version it was created with and keeps generating with that one; it is
## never silently re-generated under a newer algorithm (see `docs/persistence.md`).
const GENERATION_VERSION := 1

## Oldest generation algorithm this build can still reproduce.
const MIN_SUPPORTED_GENERATION_VERSION := 1

## Content catalogue version: blocks, items, creatures, biomes.
const DATA_VERSION := 1

## Result of comparing a save header against this build.
enum Compatibility {
	## Same versions: load directly.
	CURRENT,
	## Older but supported container: migrate forward, then load.
	NEEDS_MIGRATION,
	## Written by a newer build. Refuse — this build cannot know what it does not know.
	TOO_NEW,
	## Older than this build still supports.
	TOO_OLD,
	## The container is readable, but the generation algorithm the world was created
	## with is no longer implemented, so unexplored terrain would not match.
	GENERATOR_UNAVAILABLE,
	## The header is missing fields or has wrong types.
	MALFORMED,
}

## Header keys every save carries.
const REQUIRED_FIELDS: PackedStringArray = [
	"world_format_version", "generation_version", "data_version", "seed",
]


## Builds the header written at the head of a world save.
##
## `engine_version` and `saved_at_unix` are diagnostics only: they help a bug report,
## and nothing may branch on them. A load path that depends on the wall clock is not
## reproducible.
static func make_header(seed_value: int, extra: Dictionary = {}) -> Dictionary:
	var header := {
		"world_format_version": WORLD_FORMAT_VERSION,
		"generation_version": GENERATION_VERSION,
		"data_version": DATA_VERSION,
		"seed": seed_value,
		"engine_version": Engine.get_version_info()["string"],
		"saved_at_unix": int(Time.get_unix_time_from_system()),
	}
	for key in extra:
		header[key] = extra[key]
	return header


## Empty string when the header is structurally sound, otherwise the reason.
static func validate_header(header: Dictionary) -> String:
	for field in REQUIRED_FIELDS:
		if not header.has(field):
			return "header is missing '%s'" % field
		if typeof(header[field]) != TYPE_INT:
			return "header field '%s' must be an integer" % field
	if int(header["world_format_version"]) < 1:
		return "world_format_version must be positive"
	if int(header["generation_version"]) < 1:
		return "generation_version must be positive"
	return ""


## Classifies a save against this build. `available_generation_versions` lists the
## generation algorithms this build can still reproduce; pass the default to accept the
## documented supported range.
static func classify(header: Dictionary,
		available_generation_versions: PackedInt32Array = PackedInt32Array()) -> Compatibility:
	if not validate_header(header).is_empty():
		return Compatibility.MALFORMED

	var format_version := int(header["world_format_version"])
	if format_version > WORLD_FORMAT_VERSION:
		return Compatibility.TOO_NEW
	if format_version < MIN_SUPPORTED_FORMAT_VERSION:
		return Compatibility.TOO_OLD

	var generation_version := int(header["generation_version"])
	if not _generation_supported(generation_version, available_generation_versions):
		return Compatibility.GENERATOR_UNAVAILABLE

	if format_version < WORLD_FORMAT_VERSION:
		return Compatibility.NEEDS_MIGRATION
	return Compatibility.CURRENT


## True when a save can be opened at all — with migration if needed.
static func can_load(header: Dictionary,
		available_generation_versions: PackedInt32Array = PackedInt32Array()) -> bool:
	var verdict := classify(header, available_generation_versions)
	return verdict == Compatibility.CURRENT or verdict == Compatibility.NEEDS_MIGRATION


## Human-readable explanation, for the load screen and the log. A player being told
## "cannot load" without a reason will delete the save.
static func explain(header: Dictionary,
		available_generation_versions: PackedInt32Array = PackedInt32Array()) -> String:
	match classify(header, available_generation_versions):
		Compatibility.CURRENT:
			return "save is current"
		Compatibility.NEEDS_MIGRATION:
			return "save uses world format %d; migrating to %d" % [
					int(header["world_format_version"]), WORLD_FORMAT_VERSION]
		Compatibility.TOO_NEW:
			return "save was written by a newer build (world format %d, this build reads up to %d)" % [
					int(header["world_format_version"]), WORLD_FORMAT_VERSION]
		Compatibility.TOO_OLD:
			return "save uses world format %d; this build supports %d and later" % [
					int(header["world_format_version"]), MIN_SUPPORTED_FORMAT_VERSION]
		Compatibility.GENERATOR_UNAVAILABLE:
			return "world was generated with algorithm version %d, which this build no longer implements" % [
					int(header["generation_version"])]
		_:
			return "save header is malformed: " + validate_header(header)


## Ordered list of migration steps to apply: `[2, 3]` means "run the 1->2 migration,
## then the 2->3 migration". Empty when nothing is needed.
static func migration_steps(from_format_version: int) -> PackedInt32Array:
	var steps: PackedInt32Array = []
	if from_format_version >= WORLD_FORMAT_VERSION:
		return steps
	for version in range(from_format_version + 1, WORLD_FORMAT_VERSION + 1):
		steps.append(version)
	return steps


## True when the content catalogues have moved since the save was written. Not an error:
## content is expected to grow. The loader validates the IDs it actually finds, using
## registry aliases for anything renamed (`docs/ids-and-registries.md` §3).
static func data_version_differs(header: Dictionary) -> bool:
	return int(header.get("data_version", -1)) != DATA_VERSION


static func _generation_supported(version: int,
		available: PackedInt32Array) -> bool:
	if not available.is_empty():
		return available.has(version)
	return version >= MIN_SUPPORTED_GENERATION_VERSION and version <= GENERATION_VERSION
