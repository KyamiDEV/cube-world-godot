class_name DefinitionRegistry
extends RefCounted
## Keyed collection of definitions for one domain (backlog brick 016).
##
## Every content catalogue — blocks, items, creatures, biomes, quests — is one of these.
## It owns four responsibilities that are easy to get subtly wrong if each catalogue
## reinvents them:
##
## 1. **Validation.** Only well-formed IDs of the registry's own domain get in.
## 2. **Immutability after load.** `lock()` closes the registry; registering afterwards
##    is a programming error, not a runtime condition. A catalogue that can change
##    mid-session cannot be replicated or saved coherently.
## 3. **Aliases.** A renamed ID keeps resolving, because saves and clients still carry
##    the old one.
## 4. **Network indices.** IDs are strings; the wire needs small integers. Indices are
##    assigned at `lock()` in sorted ID order, so a client and a server that loaded the
##    same content always agree — without exchanging a table.
##
## Contract: `docs/ids-and-registries.md`.

## Domain every ID in this registry must have, e.g. "item".
var _domain: String = ""

## id -> definition.
var _definitions: Dictionary = {}

## deprecated id -> current id.
var _aliases: Dictionary = {}

## id -> network index, assigned at lock().
var _indices: Dictionary = {}

## network index -> id.
var _ids_by_index: PackedStringArray = []

var _locked: bool = false


func _init(domain_name: String) -> void:
	_domain = domain_name


func domain() -> String:
	return _domain


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

## Adds a definition. Returns true on success; on failure it logs why and returns false
## so a bad data file degrades to "this one entry is missing" rather than a crash.
func register(id: String, definition: Variant) -> bool:
	if not Log.check(not _locked, Log.CH_CORE,
			"registry is locked", {"domain": _domain, "id": id}):
		return false

	var problem := StableId.validate(id)
	if not problem.is_empty():
		Log.error(Log.CH_CORE, "invalid definition id",
				{"domain": _domain, "id": id, "reason": problem})
		return false

	if StableId.domain_of(id) != _domain:
		Log.error(Log.CH_CORE, "id belongs to another domain",
				{"registry": _domain, "id": id})
		return false

	if _definitions.has(id):
		Log.error(Log.CH_CORE, "duplicate definition id", {"domain": _domain, "id": id})
		return false

	if _aliases.has(id):
		Log.error(Log.CH_CORE, "id is already an alias for another definition",
				{"domain": _domain, "id": id, "target": _aliases[id]})
		return false

	_definitions[id] = definition
	return true


## Points a deprecated ID at a current one, so old saves and older clients keep
## resolving. The target need not exist yet: data files load in an arbitrary order, so
## aliases are checked at `lock()` instead.
func add_alias(deprecated_id: String, current_id: String) -> bool:
	if not Log.check(not _locked, Log.CH_CORE,
			"registry is locked", {"domain": _domain, "id": deprecated_id}):
		return false
	if _definitions.has(deprecated_id):
		Log.error(Log.CH_CORE, "alias would shadow a live definition",
				{"domain": _domain, "id": deprecated_id})
		return false
	_aliases[deprecated_id] = current_id
	return true


## Closes the registry and assigns network indices.
##
## Indices are assigned in sorted ID order rather than insertion order: two processes
## that loaded the same content must agree on them, and insertion order depends on file
## system enumeration. Returns false when an alias points nowhere — that check has to
## wait until every definition is in.
func lock() -> bool:
	if _locked:
		return true

	var ok := true
	for deprecated in _aliases:
		if not _definitions.has(_aliases[deprecated]):
			Log.error(Log.CH_CORE, "alias points at an unknown definition",
					{"domain": _domain, "alias": deprecated, "target": _aliases[deprecated]})
			ok = false

	var sorted_ids := PackedStringArray(_definitions.keys())
	sorted_ids.sort()
	_ids_by_index = sorted_ids
	_indices.clear()
	for i in sorted_ids.size():
		_indices[sorted_ids[i]] = i

	_locked = true
	Log.info(Log.CH_CORE, "registry locked",
			{"domain": _domain, "definitions": _definitions.size(), "aliases": _aliases.size()})
	return ok


func is_locked() -> bool:
	return _locked


## Empties the registry. For tests and for reloading content between sessions — never
## while a world is running.
func clear() -> void:
	_definitions.clear()
	_aliases.clear()
	_indices.clear()
	_ids_by_index = PackedStringArray()
	_locked = false


# ---------------------------------------------------------------------------
# Lookup
# ---------------------------------------------------------------------------

## Resolves aliases and returns the definition, or null when unknown. Use for data that
## may legitimately be absent — an old save referring to removed content.
func get_definition(id: String) -> Variant:
	var resolved := resolve(id)
	return _definitions.get(resolved, null)


## Like `get_definition`, but logs when the ID is unknown. Use where a missing
## definition means the content or the code is broken.
func require(id: String) -> Variant:
	var definition: Variant = get_definition(id)
	if definition == null:
		Log.error(Log.CH_CORE, "unknown definition id", {"domain": _domain, "id": id})
	return definition


func has(id: String) -> bool:
	return _definitions.has(resolve(id))


## Maps a possibly-deprecated ID to the current one. Unknown IDs come back unchanged, so
## the caller sees the ID it asked about in its own error message.
func resolve(id: String) -> String:
	if _definitions.has(id):
		return id
	var seen := {}
	var current := id
	# Alias chains are allowed (A -> B -> C) but must not loop.
	while _aliases.has(current) and not seen.has(current):
		seen[current] = true
		current = _aliases[current]
	return current


## Every registered ID, sorted. Sorted rather than insertion-ordered so iteration is
## reproducible — content order must not depend on file enumeration.
func ids() -> PackedStringArray:
	if _locked:
		return _ids_by_index
	var sorted_ids := PackedStringArray(_definitions.keys())
	sorted_ids.sort()
	return sorted_ids


## Every ID under a prefix, e.g. `item.sword` -> all sword variants. Sorted.
func ids_under(prefix: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for id in ids():
		if StableId.is_under(id, prefix):
			found.append(id)
	return found


func size() -> int:
	return _definitions.size()


# ---------------------------------------------------------------------------
# Network indices
# ---------------------------------------------------------------------------

## Compact wire index for an ID, or -1 when unknown or before `lock()`.
func network_index(id: String) -> int:
	return _indices.get(resolve(id), -1)


## Inverse of `network_index`. Returns an empty string for an out-of-range index — a
## packet from an incompatible peer must not be able to index out of bounds.
func id_from_network_index(index: int) -> String:
	if index < 0 or index >= _ids_by_index.size():
		return ""
	return _ids_by_index[index]


## Order-independent fingerprint of the registry's contents. Two peers compare these at
## connection time: equal fingerprints mean their network indices agree.
func content_hash() -> int:
	var accumulated := DeterministicRng.hash_string(_domain)
	for id in ids():
		# Combined by XOR of per-entry hashes that already include the index, so the
		# result depends on the mapping rather than on iteration order.
		accumulated ^= DeterministicRng.hash_string("%d:%s" % [network_index(id), id])
	return accumulated
