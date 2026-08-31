class_name StableId
extends RefCounted
## Validation and parsing for stable content IDs (backlog brick 016).
##
## Format: `<domain>.<name>[.<variant>…]` — lower-case `[a-z0-9_]` segments joined by
## dots, no segment starting with a digit. `item.sword.iron`, `creature.goblin`,
## `quest.village_bandits_01`.
##
## An ID is written into save files, network packets and logs, so it is **permanent**.
## Display names are localised and edited for feel; array indices shift when content is
## inserted. Neither can key anything that outlives a session (`CLAUDE.md` §9).
##
## Grammar and rationale: `docs/conventions.md` §5, `docs/ids-and-registries.md`.
##
## Static-only: never instantiate.

## The closed set of first segments. Adding one is a deliberate documentation change,
## not a decision made at a call site.
const DOMAINS: PackedStringArray = [
	"block", "item", "creature", "npc", "skill", "effect", "quest", "dialogue",
	"faction", "biome", "structure", "dungeon", "loot", "recipe", "sound", "ui",
]

## Depth beyond this means the taxonomy is wrong, not that the ID needs another level.
const MAX_SEGMENTS := 5

const _SEGMENT_PATTERN := "^[a-z][a-z0-9_]*$"


## True when `id` is well-formed **and** its domain is known.
static func is_valid(id: String) -> bool:
	return validate(id).is_empty()


## Returns an empty string when `id` is valid, otherwise a human-readable reason.
## Callers that reject content should log this reason — "invalid id" alone tells a
## content author nothing.
static func validate(id: String) -> String:
	if id.is_empty():
		return "id is empty"
	if id != id.to_lower():
		return "id must be lower case"
	if not id.contains("."):
		return "id must have a domain: <domain>.<name>"

	var segments := id.split(".", true)  # keep empties so "a..b" is caught
	if segments.size() > MAX_SEGMENTS:
		return "id has %d segments, maximum is %d" % [segments.size(), MAX_SEGMENTS]

	var regex := RegEx.new()
	regex.compile(_SEGMENT_PATTERN)
	for segment in segments:
		if segment.is_empty():
			return "id has an empty segment"
		if regex.search(segment) == null:
			return "segment '%s' must be [a-z][a-z0-9_]*" % segment

	if not DOMAINS.has(segments[0]):
		return "unknown domain '%s'" % segments[0]
	return ""


## First segment, or an empty string when the ID is malformed.
static func domain_of(id: String) -> String:
	if not id.contains("."):
		return ""
	return id.get_slice(".", 0)


## Everything after the domain: `item.sword.iron` -> `sword.iron`.
static func name_of(id: String) -> String:
	var first_dot := id.find(".")
	return "" if first_dot < 0 else id.substr(first_dot + 1)


## Last segment: `item.sword.iron` -> `iron`. Useful for variant-aware lookups.
static func leaf_of(id: String) -> String:
	var last_dot := id.rfind(".")
	return id if last_dot < 0 else id.substr(last_dot + 1)


static func segments_of(id: String) -> PackedStringArray:
	return id.split(".", false)


## True when `id` sits under `prefix`: `is_under("item.sword.iron", "item.sword")`.
## Segment-aware, so `item.swordfish` is **not** under `item.sword`.
static func is_under(id: String, prefix: String) -> bool:
	if id == prefix:
		return true
	return id.begins_with(prefix + ".")


## Best-effort repair of an authored string, for tooling and importers only.
## Never call this on a saved or received ID: silently accepting a malformed key is how
## two spellings of the same thing end up in one save file.
static func normalise(text: String) -> String:
	# Path-ish separators become segment separators first, so that "Item / Sword"
	# splits into segments before spaces are folded into underscores. Doing it the
	# other way round turns " / " into "_._".
	var working := text.strip_edges().to_lower().replace("\\", "/").replace("/", ".")
	var segments: PackedStringArray = []
	for raw in working.split(".", false):
		var segment := raw.strip_edges().replace(" ", "_").replace("-", "_")
		while segment.contains("__"):
			segment = segment.replace("__", "_")
		segment = segment.trim_prefix("_").trim_suffix("_")
		if not segment.is_empty():
			segments.append(segment)
	return ".".join(segments)
