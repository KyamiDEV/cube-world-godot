class_name BlockRegistry
extends RefCounted
## Domain registry for BlockDefinition (backlog brick 032).
##
## `DefinitionRegistry` (brick 016) is domain-agnostic: it stores `Variant` and only
## validates the *id*, never the definition's own fields
## (`docs/ids-and-registries.md` §5 — "each domain's definition type checks its own
## fields"). This wrapper closes that gap for the "block" domain specifically:
##
## - pins the domain to "block", so callers never pass the domain string themselves
## - calls `BlockDefinition.validate()` before handing anything to storage, so a
##   definition with a malformed field never gets in just because its id was well-formed
## - returns `BlockDefinition` instead of `Variant` at every read
##
## Storage, locking, aliasing and network indices are still entirely owned by the
## wrapped `DefinitionRegistry`; this type adds no state of its own beyond that instance.

var _registry := DefinitionRegistry.new("block")


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

## Validates `definition` and registers it under its own id. Returns false — and logs
## why — for an invalid definition or an id problem the wrapped registry itself rejects
## (duplicate, wrong domain, locked). Mirrors `DefinitionRegistry.register()`'s
## degrade-to-one-missing-entry contract.
func register_block(definition: BlockDefinition) -> bool:
	var problem := definition.validate()
	if not problem.is_empty():
		Log.error(Log.CH_CORE, "invalid block definition",
				{"id": definition.id, "reason": problem})
		return false
	return _registry.register(definition.id, definition)


func add_alias(deprecated_id: String, current_id: String) -> bool:
	return _registry.add_alias(deprecated_id, current_id)


func lock() -> bool:
	return _registry.lock()


func is_locked() -> bool:
	return _registry.is_locked()


func clear() -> void:
	_registry.clear()


# ---------------------------------------------------------------------------
# Lookup
# ---------------------------------------------------------------------------

func get_block(id: String) -> BlockDefinition:
	return _registry.get_definition(id)


func require_block(id: String) -> BlockDefinition:
	return _registry.require(id)


func has_block(id: String) -> bool:
	return _registry.has(id)


func resolve(id: String) -> String:
	return _registry.resolve(id)


func ids() -> PackedStringArray:
	return _registry.ids()


func ids_under(prefix: String) -> PackedStringArray:
	return _registry.ids_under(prefix)


func size() -> int:
	return _registry.size()


# ---------------------------------------------------------------------------
# Network indices
# ---------------------------------------------------------------------------

func network_index(id: String) -> int:
	return _registry.network_index(id)


func id_from_network_index(index: int) -> String:
	return _registry.id_from_network_index(index)


func content_hash() -> int:
	return _registry.content_hash()
