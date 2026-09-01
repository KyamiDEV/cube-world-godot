class_name BlockSet
extends RefCounted
## Loads the data-driven block-kind catalogue into a locked BlockRegistry (backlog
## brick 038).
##
## `BlockDefinition`'s own header comment (031) predicted this file: "a loader parses
## `data/blocks/*.tres` ... and hands each one to a `BlockRegistry`". This is that
## loader — the first concrete implementation of `docs/ids-and-registries.md`'s generic
## "a loader parses data and calls register()" contract, not a new one.
##
## Scans the directory rather than hardcoding a list of ids: a later brick adds another
## block kind purely as data (drop a `.tres` file in `data/blocks/`), no change here.
## `tools/generators/generate_block_set.gd` is what wrote the first three files
## (grass/dirt/stone) this loader reads.

const DEFAULT_DIR := "res://data/blocks/"


## Loads every `*.tres` file directly under `dir`, registers each as a `BlockDefinition`,
## locks the registry, and returns it. A missing directory, a file that fails to load, a
## file that isn't a `BlockDefinition`, or a definition that fails its own `validate()`
## is skipped and logged rather than failing the whole load — same "one entry missing,
## not a crash" contract `BlockRegistry.register_block()` already uses. The returned
## registry is always locked, even when nothing loaded.
static func load_default(dir: String = DEFAULT_DIR) -> BlockRegistry:
	var registry := BlockRegistry.new()

	var handle := DirAccess.open(dir)
	if handle == null:
		Log.error(Log.CH_VOXEL, "block data directory not found", {"dir": dir})
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
			Log.error(Log.CH_VOXEL, "failed to load block data file", {"path": path})
			continue
		if not (resource is BlockDefinition):
			Log.error(Log.CH_VOXEL, "block data file is not a BlockDefinition",
					{"path": path, "type": resource.get_class()})
			continue
		registry.register_block(resource)

	registry.lock()
	return registry
