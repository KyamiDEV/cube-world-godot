class_name VoxelStreamBuilder
extends RefCounted
## Builds a configured `VoxelStreamSQLite` for a given database path (backlog brick 048).
##
## Scope is deliberately narrow: the stream object itself, wired for how this project
## saves voxels, not *where* it lives on disk or how a world's save directory is laid
## out — that storage-layout policy is `docs/persistence.md`'s own note: "Storage layout
## for voxel data lands with the voxel stream (bricks 048, 102-103)". This brick only
## produces a stream a caller can hand to `VoxelTerrainBuilder.build()` (039, extended
## here to accept one) and assign to `terrain.stream`.
##
## `save_generator_output = false` (explicit — matches the engine default, named on
## purpose): `docs/persistence.md` §5 — "World modifications: stored as deltas... only
## what a player changed differs from the generator's output". Saving every generated
## block would duplicate terrain the generator can already reproduce from
## `(seed, coords, generation version)`.
##
## `set_key_cache_enabled(true)`: `VoxelStreamSQLite`'s own doc says key caching
## "speed[s] up loading queries in terrains that only save sparse edited blocks" — exactly
## the shape `save_generator_output = false` produces. Its own doc also requires this be
## called before the stream is used to load, so it happens here, at construction, before
## the stream is ever assigned to a terrain.
##
## `preferred_coordinate_format` is set explicitly to `COORDINATE_FORMAT_STRING_CSD` — the
## engine's own default, but named here as a deliberate placeholder, not an unexamined
## default: it is the one format with no fixed voxel-coordinate range, and this project
## has not yet decided world bounds (brick 050, `docs/voxel-tools.md` §6). Revisit once
## bounds are decided — a fixed-width integer format is smaller/faster if the chosen
## bounds fit its range. Only affects a *new* database; the property's own doc says the
## choice is ignored when opening an existing one.

## Returns null (and logs why) when `database_path` is empty — a programmer/caller error,
## not a runtime condition to paper over.
static func build(database_path: String) -> VoxelStreamSQLite:
	if not Log.check(not database_path.is_empty(), Log.CH_PERSIST,
			"voxel stream database_path must not be empty"):
		return null

	var stream := VoxelStreamSQLite.new()
	stream.database_path = database_path
	stream.preferred_coordinate_format = VoxelStreamSQLite.COORDINATE_FORMAT_STRING_CSD
	stream.save_generator_output = false
	stream.set_key_cache_enabled(true)
	return stream
