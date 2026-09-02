class_name BiomeCatalog
extends RefCounted
## Loads the data-driven biome catalog into a locked BiomeRegistry (backlog brick 067).
##
## `BlockSet.load_default()`'s shape (038) for `data/biomes/`: scan the directory, register
## each `.tres` as a `BiomeDefinition`, lock, return. A per-biome record then lives in a
## data file, which is where bricks 068–073 add to it and where `CLAUDE.md` §9 says content
## belongs.
##
## The one difference from `BlockSet` is the completeness check, and it is the reason this
## file exists rather than a second copy of that one. A block registry that came back one
## entry short is a missing block; a biome registry that came back one entry short is a
## world with columns that classify into nothing. So the load still degrades per entry —
## one bad file is one logged error, not a crash — and then `BiomeRegistry.self_check()`
## runs once over the result and logs loudly if the catalog as a whole is unusable. It
## still returns the registry: the caller decides whether to continue, exactly as
## `GenerationVersion` hands back a verdict rather than aborting.
##
## `tools/generators/generate_biome_catalog.gd` is what wrote the six files this reads.
##
## Contract: `docs/world-generation.md` §12.

const DEFAULT_DIR := "res://data/biomes/"


## Loads every `*.tres` file directly under `dir`, registers each as a `BiomeDefinition`,
## locks the registry, and returns it — always locked, even when nothing loaded. A missing
## directory, an unloadable file, a file that is not a `BiomeDefinition`, or a definition
## that fails `BiomeRegistry.register_biome()` is skipped and logged.
##
## `verify` runs `BiomeRegistry.self_check()` on the result and logs its reason. Pass false
## only where an incomplete catalog is the point — a test building a partial one, or a tool
## inspecting a directory that is not the project's.
static func load_default(dir: String = DEFAULT_DIR, verify: bool = true) -> BiomeRegistry:
	var registry := BiomeRegistry.new()

	var handle := DirAccess.open(dir)
	if handle == null:
		Log.error(Log.CH_GEN, "biome data directory not found", {"dir": dir})
		registry.lock()
		return registry

	var filenames: PackedStringArray = []
	handle.list_dir_begin()
	var entry := handle.get_next()
	while entry != "":
		if not handle.current_is_dir() and entry.get_extension() == "tres":
			filenames.append(entry)
		entry = handle.get_next()
	handle.list_dir_end()
	filenames.sort()  # deterministic load/log order, independent of filesystem enumeration

	for filename in filenames:
		var path := dir.path_join(filename)
		var resource: Resource = ResourceLoader.load(path)
		if resource == null:
			Log.error(Log.CH_GEN, "failed to load biome data file", {"path": path})
			continue
		if not (resource is BiomeDefinition):
			Log.error(Log.CH_GEN, "biome data file is not a BiomeDefinition",
					{"path": path, "type": resource.get_class()})
			continue
		registry.register_biome(resource)

	registry.lock()

	if verify:
		var problem := registry.self_check()
		if not problem.is_empty():
			Log.error(Log.CH_GEN, "biome catalog is incomplete or incoherent",
					{"dir": dir, "reason": problem, "loaded": registry.size()})

	return registry


## The file name a biome's record is stored under: the id's name segments, so
## `biome.grassland` is `grassland.tres`. Shared by the loader's own documentation and by
## the generator that writes the files, so the two cannot disagree about where a record
## lives.
static func file_name_for(id: String) -> String:
	return StableId.name_of(id) + ".tres"
