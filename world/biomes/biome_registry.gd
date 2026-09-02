class_name BiomeRegistry
extends RefCounted
## Domain registry for BiomeDefinition (backlog brick 067).
##
## `BlockRegistry`'s shape, for the "biome" domain: `DefinitionRegistry` (016) stores
## `Variant` and validates only the *id*, so each domain wraps it with the checks its own
## definition type owes (`docs/ids-and-registries.md` §5). Storage, locking, aliasing and
## network indices stay entirely with the wrapped registry; this type adds no state.
##
## It also adds the one thing a *block* registry has no equivalent of. Blocks are an open
## set — dropping another `.tres` into `data/blocks/` is how a block kind is added, and a
## registry holding four or forty is equally correct. Biomes are a **closed** set, fixed in
## code by `BiomeClassifier.IDS`, and the two directions fail differently:
##
## - an id the classifier cannot produce is **dead content** — a record nothing will ever
##   look up, usually a typo, and it is rejected at `register_biome()`;
## - a classifier id with no record is a **broken world** — every column classified into it
##   resolves to nothing — and it cannot be caught one entry at a time, so it is
##   `coverage_reason()`, checked once the catalog is loaded.
##
## `docs/world-generation.md` §12.2.

## Smallest RGB distance two debug colours may sit at, as a Euclidean distance over the
## unit cube. Not a perceptual metric and not trying to be one: it is a guard against two
## biomes being given the same swatch, not a colour-science claim. The measured minimum in
## the baseline palette is `0.28` (grassland against mountain).
const MINIMUM_DEBUG_COLOR_DISTANCE := 0.25

var _registry := DefinitionRegistry.new("biome")


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

## Validates `definition` and registers it under its own id. Returns false — and logs why —
## for an invalid definition, an id the classifier cannot produce, or an id problem the
## wrapped registry rejects (duplicate, wrong domain, locked). Mirrors
## `DefinitionRegistry.register()`'s degrade-to-one-missing-entry contract; the missing
## entry is then caught in the aggregate by `coverage_reason()`.
func register_biome(definition: BiomeDefinition) -> bool:
	var problem := definition.validate()
	if not problem.is_empty():
		Log.error(Log.CH_GEN, "invalid biome definition",
				{"id": definition.id, "reason": problem})
		return false
	if not BiomeClassifier.is_biome_id(definition.id):
		Log.error(Log.CH_GEN, "biome definition names a biome nothing can classify",
				{"id": definition.id, "known": BiomeClassifier.IDS})
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

func get_biome(id: String) -> BiomeDefinition:
	return _registry.get_definition(id)


func require_biome(id: String) -> BiomeDefinition:
	return _registry.require(id)


func has_biome(id: String) -> bool:
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


# ---------------------------------------------------------------------------
# Catalog invariants
# ---------------------------------------------------------------------------

## Empty string when this registry holds a record for **every** id `BiomeClassifier` can
## produce and nothing else, otherwise the reason.
##
## The set-equality check the closed set earns. `register_biome()` already refuses the
## unknown-id direction one entry at a time, so in practice this reports what is *missing*.
func coverage_reason() -> String:
	return coverage_reason_for(ids())


## The same comparison against a bare id list, with no registry involved.
##
## Static and list-taking so that **both** directions are reachable: `register_biome()`
## refuses an unclassifiable id, so a live registry can only ever be short, and a check
## whose second branch no test can reach is a check nobody has run. It is also what a
## loader, a save-file audit or a network handshake wants — three places that hold ids
## before they hold definitions.
static func coverage_reason_for(present: PackedStringArray) -> String:
	var missing: PackedStringArray = []
	for id in BiomeClassifier.IDS:
		if not present.has(id):
			missing.append(id)
	if not missing.is_empty():
		return "no definition for %s" % ", ".join(missing)
	var extra: PackedStringArray = []
	for id in present:
		if not BiomeClassifier.is_biome_id(id):
			extra.append(id)
	if not extra.is_empty():
		return "definition for %s, which nothing can classify" % ", ".join(extra)
	return ""


## Empty string when every pair of registered biomes is tellable apart by `debug_color`,
## otherwise the first offending pair. Ids are visited in `ids()`' sorted order, so the
## reported pair does not depend on load order.
func palette_reason() -> String:
	var all_ids := ids()
	for i in all_ids.size():
		for j in range(i + 1, all_ids.size()):
			var a := get_biome(all_ids[i])
			var b := get_biome(all_ids[j])
			var distance := color_distance(a.debug_color, b.debug_color)
			if distance < MINIMUM_DEBUG_COLOR_DISTANCE:
				return "%s and %s are %s apart in debug_color, minimum is %s" % [
						all_ids[i], all_ids[j], distance, MINIMUM_DEBUG_COLOR_DISTANCE]
	return ""


## Empty string when the catalog is coherent, otherwise the reason. Same shape and same
## purpose as `BiomeClassifier.self_check()` and `GenerationVersion.self_check()`: the
## failures here make every biome in the world wrong while each individual record still
## validates, so they are worth one call that a boot path or a test can make.
func self_check() -> String:
	var coverage := coverage_reason()
	if not coverage.is_empty():
		return coverage
	return palette_reason()


## Euclidean RGB distance, alpha ignored — `BiomeDefinition.validate()` already requires
## every debug colour to be opaque.
static func color_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
