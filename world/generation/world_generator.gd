class_name WorldGenerator
extends VoxelGeneratorScript
## The first thing in this project that writes a voxel: the Phase D passes assembled into a
## real Voxel Tools generator (backlog brick 091b).
##
## Bricks 056–091 built twenty-odd deterministic *content queries* and every one of them ended
## its own docs with the same sentence — "the moment some later brick's `VoxelGenerator` calls
## this to fill a `VoxelBuffer`, these constants become pinned generation inputs". No brick
## owned that call: 091–094 are all "*initial* &lt;kind&gt; generator", and `docs/world-generation.md`
## §30.8 recorded the gap rather than letting 091 quietly grow into it. This file is that
## missing brick. **The boundary those twenty sections named is crossed here** (§31.6).
##
## ```gdscript
## var generator := WorldGenerator.for_seed(WorldSeed.from_text("cubeworld"),
##         BiomeCatalog.load_default(), BlockSet.load_default())
## terrain.generator = generator          # or VoxelTerrainBuilder.build_world(), 039/091b
## generator.block_id_at_voxel(voxel)     # the same answer, without an engine buffer
## ```
##
## ## What it composes, and in what order
##
## ```text
## column_at(column) -- resolved once per column, cached in a WorldColumn (§31.1)
##     terrace_y  = TerracePass.surface_y(column)       -- what caves are clipped against
##     natural_y  = LakePass.surface_y(column)          -- terrace, minus river and lake risers
##     ground_y   = StructureGenerator.surface_y_for(site, column, natural_y)  -- if a pad covers it
##
## block_id_in_column(plan, y)
##     1. StructureGenerator.part_of()  FLOOR/WALL -> stone, INTERIOR -> air   (§30.1, wins)
##     2. y > ground_y                                    -> air
##     3. y == ground_y  -> SnowlineMaterial.block_id_at() -- snow / shore / biome surface
##     4. CaveCarving.is_hollow_for(voxel, terrace_y)      -> air               (§17)
##     5. SubsurfaceMaterial.block_id_for_depth(column, ground_y - y)           (§15)
## ```
##
## The structure wins over the terrain in both directions, which is the whole point of
## `clears_terrain_at()` (§30): a plinth cut into a hillside must carve its own interior, or it
## generates solid and reads as a stone block rather than a building.
##
## ## Why the ground is `LakePass`, not `TerracePass`
##
## Three separate passes have a claim on "where the ground is", and they compose in one order:
## `TerracePass` quantises it (063), `RiverPass`/`LakePass` cut whole risers out of channels and
## basins (081/082), and `StructureGenerator` levels a building pad in both directions (091).
## `LakePass.surface_y()` is the deepest point of the first chain, so it is what a generator
## fills to; the structure levelling then composes **over** that rather than over
## `TerracePass`, via `StructureGenerator.surface_y_for()`. §30.4's own instruction was "read
## `surface_y_at()`, never `TerracePass.surface_y()`", and this is that instruction with rivers
## kept: `surface_y_at()` reads `TerracePass` internally because 091 had no reason to know about
## channels, and using it directly here would silently un-carve a river running through a pad.
## Every term stays an exact terrace multiple, so `ground_y` still lands on a terrace plane.
##
## ## What it does not place: water
##
## Nothing fills an ocean, a river or a lake with anything. That is not an oversight — it is
## §19.8/§20.8/§21.8/§22.8's own repeated boundary ("a water block, or any `VoxelGenerator`
## write"), and the block set genuinely has no water block: `data/blocks/` ships grass, dirt,
## stone, sand and snow (038/084/085). A wet column generates exactly the ground the terrain
## chain produces, with air above it, and `ShorelineMaterial` still sands its edges. Adding a
## transparent, non-solid block kind and deciding how it interacts with `VoxelMesherBlocky`'s
## culling and with `VoxelBoxMover` is a content brick of its own, not a line in this one
## (§31.7).
##
## ## Threading
##
## `_generate_block()` runs on Voxel Tools worker threads. Every field below is assigned once
## in `for_world()` and never written again; every pass underneath is a stateless `RefCounted`
## that samples noise from immutable inputs; `_voxel_values` is built before the object is
## returned and only read afterwards. There is no cache, no lazy field and no `Log` call on the
## fill path — §30.5's own warning that "a mutable cache on a shared pass object is a data race,
## not an optimisation", honoured. The one per-chunk cache that does exist, `WorldColumn`, is a
## fresh object per column owned by the calling thread's own stack frame.
##
## Contract: `docs/world-generation.md` §31.

## The voxel value meaning air, on `VoxelBuffer.CHANNEL_TYPE`. `0` by the convention brick 037
## fixed when `BlockyLibraryBuilder` inserted air at library index 0 — every block's value is
## `BlockRegistry.network_index(id) + 1`, so `0` belongs to no block and never can.
const AIR_VOXEL_VALUE := 0

var _hash: GenerationHash
var _ground: LakePass
var _cover: SnowlineMaterial
var _carving: CaveCarving
var _subsurface: SubsurfaceMaterial
var _structures: StructureGenerator
var _blocks: BlockRegistry

## Block id -> voxel value, resolved once at construction. Not an optimisation for its own
## sake: it keeps the `+1` offset in exactly one place *and* keeps `BlockRegistry`'s dictionary
## lookups off the per-voxel path on a worker thread.
var _voxel_values: Dictionary = {}


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds world generation to one world and one loaded content set, or returns null (logged)
## when any pass underneath cannot be built. **The supported entry point.**
##
## Builds its own copy of every pass, the reason every `for_world()` since 062 gives: they are
## stateless and small, and a shared instance would be a second way for two passes to disagree
## about which world they are generating. Each one validates its own registries
## (`SurfaceMaterial`'s surface blocks, `SubsurfaceMaterial`'s subsurface + bedrock,
## `ShorelineMaterial`'s sand, `SnowlineMaterial`'s snow, `StructureGenerator`'s masonry), so
## this file adds no block check of its own — by the time all five have accepted the catalogs,
## every id this generator can emit is registered, which `self_check()` then asserts rather
## than assumes.
static func for_world(p_hash: GenerationHash, p_biomes: BiomeRegistry,
		p_blocks: BlockRegistry) -> WorldGenerator:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build world generation without a world binding"):
		return null
	if not Log.check(p_blocks != null and p_blocks.is_locked(), Log.CH_GEN,
			"world generation needs a locked block registry"):
		return null

	var bound_ground := LakePass.for_world(p_hash)
	if bound_ground == null:
		return null
	var bound_cover := SnowlineMaterial.for_world(p_hash, p_biomes, p_blocks)
	if bound_cover == null:
		return null
	var bound_carving := CaveCarving.for_world(p_hash)
	if bound_carving == null:
		return null
	var bound_subsurface := SubsurfaceMaterial.for_world(p_hash, p_biomes, p_blocks)
	if bound_subsurface == null:
		return null
	var bound_structures := StructureGenerator.for_world(p_hash, p_biomes, p_blocks)
	if bound_structures == null:
		return null

	var generator := WorldGenerator.new()
	generator._hash = p_hash
	generator._ground = bound_ground
	generator._cover = bound_cover
	generator._carving = bound_carving
	generator._subsurface = bound_subsurface
	generator._structures = bound_structures
	generator._blocks = p_blocks
	generator._voxel_values = _voxel_value_table(p_blocks)

	var problem := generator.self_check()
	if not Log.check(problem.is_empty(), Log.CH_GEN,
			"world generation is internally inconsistent", {"reason": problem}):
		return null
	return generator


## The same binding from a `WorldSeed` rather than an already-built `GenerationHash` — the form
## a scene or a save loader has, since a world's identity is what it persists (056).
## `GenerationHash.for_world()` refuses a seed this build cannot reproduce, and logs why.
static func for_seed(p_world_seed: WorldSeed, p_biomes: BiomeRegistry,
		p_blocks: BlockRegistry) -> WorldGenerator:
	var bound_hash := GenerationHash.for_world(p_world_seed)
	if bound_hash == null:
		return null
	return for_world(bound_hash, p_biomes, p_blocks)


## Block id -> voxel value for every registered block, applying 037's `+1` offset once.
static func _voxel_value_table(p_blocks: BlockRegistry) -> Dictionary:
	var table := {}
	for id in p_blocks.ids():
		table[id] = p_blocks.network_index(id) + 1
	return table


# ---------------------------------------------------------------------------
# The content query
# ---------------------------------------------------------------------------

## Resolves everything the whole vertical stack at `column` needs, once — see `WorldColumn`.
##
## This is the expensive call: `LakePass.surface_y()` runs the entire height chain and
## `site_for_column()` scans nine regions. A chunk fill makes it once per column and reads the
## result 16 times; a caller that wants a single voxel and does not care uses
## `block_id_at_voxel()`.
func column_at(column: Vector2i) -> WorldColumn:
	var terrace_y := _ground.river().terrace().surface_y(column)
	var natural_y := _ground.surface_y(column)
	var site := _structures.site_for_column(column)
	var ground_y := natural_y
	if site != null:
		ground_y = StructureGenerator.surface_y_for(site, column, natural_y)
	return WorldColumn.new(column, ground_y, terrace_y, site)


## The block covering a column's `ground_y` — the full cover chain (`SnowlineMaterial` over
## `ShorelineMaterial` over `SurfaceMaterial`).
##
## Deliberately **not** a `WorldColumn` field, resolved on demand instead: `ShorelineMaterial`
## asks four neighbouring columns whether they are wet (084), and each of those runs its own
## full height chain, so the cover costs several times what the ground does. Exactly one voxel
## per column ever needs it, and a chunk that is all sky or all underground needs it for none
## of them — the early-out above and the `y == ground_y` branch below keep it off both paths.
func cover_block_id_at(column: Vector2i) -> String:
	return _cover.block_id_at(column)


## The block id at height `y` in an already-resolved column, or `""` for air. The one function
## the fill loop actually runs per voxel; see the class comment for the five-step order.
##
## Every pass it reaches is given a number `plan` already holds, so nothing underneath
## re-derives the column's surface height — see `WorldColumn` for what that redundancy cost
## before the resolved-input forms existed.
func block_id_in_column(plan: WorldColumn, y: int) -> String:
	var voxel := Vector3i(plan.column.x, y, plan.column.y)

	if plan.site != null:
		var part := StructureGenerator.part_of(plan.site, voxel)
		if part == StructureGenerator.Part.FLOOR or part == StructureGenerator.Part.WALL:
			return StructureGenerator.STRUCTURE_BLOCK_ID
		if part == StructureGenerator.Part.INTERIOR:
			# `clears_terrain_at()` (§30): enclosed air the terrain must not fill, or a plinth
			# cut into a hillside generates solid.
			return ""

	if y > plan.ground_y:
		return ""
	if y == plan.ground_y:
		return cover_block_id_at(plan.column)
	if _carving.is_hollow_for(voxel, plan.terrace_y):
		return ""
	return _subsurface.block_id_for_depth(plan.column, plan.depth_at(y))


## The block id at one voxel, resolving its column first. Pure and order-free, every Phase D
## pass's own contract — the form tests and debug overlays want, not the form a chunk fill
## wants (it re-resolves the column every call).
func block_id_at_voxel(voxel: Vector3i) -> String:
	return block_id_in_column(column_at(GenerationGrid.voxel_to_column(voxel)), voxel.y)


## The `VoxelBuffer.CHANNEL_TYPE` value for a block id, `AIR_VOXEL_VALUE` for `""`.
##
## An id no registry knows also reads as air rather than as some other block: a hole is a
## visible, diagnosable failure, where a silently wrong value would be a block placed by
## nobody. `self_check()` makes the case unreachable for a live generator.
func voxel_value_of(block_id: String) -> int:
	if block_id.is_empty():
		return AIR_VOXEL_VALUE
	return int(_voxel_values.get(block_id, AIR_VOXEL_VALUE))


# ---------------------------------------------------------------------------
# The buffer write
# ---------------------------------------------------------------------------

## Fills `out_buffer` with the world at `origin_in_voxels`, on `VoxelBuffer.CHANNEL_TYPE`.
##
## Public and engine-free on purpose: `_generate_block()` is a virtual only Voxel Tools calls,
## so a test that wants to assert what actually lands in a buffer would otherwise need a live
## streaming terrain. Everything the engine path does happens here.
##
## The buffer is explicitly filled with air first rather than trusting the caller's
## zero-initialisation, then only non-air voxels are written — most chunks in a voxel world are
## sky, and the per-column `top_y()` early-out skips those without asking about a single voxel.
func fill_buffer(out_buffer: VoxelBuffer, origin_in_voxels: Vector3i) -> void:
	var size := out_buffer.get_size()
	out_buffer.fill(AIR_VOXEL_VALUE, VoxelBuffer.CHANNEL_TYPE)

	for local_z in size.z:
		for local_x in size.x:
			var plan := column_at(Vector2i(origin_in_voxels.x + local_x,
					origin_in_voxels.z + local_z))
			if origin_in_voxels.y > plan.top_y():
				continue
			for local_y in size.y:
				var value := voxel_value_of(
						block_id_in_column(plan, origin_in_voxels.y + local_y))
				if value != AIR_VOXEL_VALUE:
					out_buffer.set_voxel(value, local_x, local_y, local_z,
							VoxelBuffer.CHANNEL_TYPE)


## Voxel Tools' generation entry point. Runs on a worker thread — see the class comment.
##
## `lod` is ignored above 0 rather than downsampled: the project's terrain node is
## `VoxelTerrain`, which is fixed-LOD and only ever asks for LOD 0 (`docs/voxel-tools.md` §5).
## A `VoxelLodTerrain` would need a real downsampling policy, which is a Phase L/streaming
## question, not something to fake here by generating the wrong scale of world.
func _generate_block(out_buffer: VoxelBuffer, origin_in_voxels: Vector3i, lod: int) -> void:
	if lod != 0:
		return
	fill_buffer(out_buffer, origin_in_voxels)


## Only `CHANNEL_TYPE` — this is a blocky world. The `VoxelGeneratorFlat` placeholder it
## replaces had to be told the same thing explicitly (039: `channel` defaults to `CHANNEL_SDF`).
func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE


# ---------------------------------------------------------------------------
# Shape of the generator
# ---------------------------------------------------------------------------

## The world binding every pass underneath shares. Read-only by convention.
func generation_hash() -> GenerationHash:
	return _hash


## The seed this generator produces, for a caller writing world metadata (103).
func world_seed() -> WorldSeed:
	return _hash.world_seed


## The generation algorithm version this generator's output belongs to — the number a world
## save must record so a later build can tell whether it may still stream the same world
## (§31.6, `GenerationVersion`).
func generation_version() -> int:
	return _hash.world_seed.generation_version


## The block registry every voxel value came from. Read-only by convention.
func blocks() -> BlockRegistry:
	return _blocks


## The full ground-height chain (`LakePass` over `RiverPass` over `TerracePass`), for a consumer
## that wants the natural surface with no structure levelling applied.
func ground() -> LakePass:
	return _ground


## The surface cover chain (`SnowlineMaterial` over `ShorelineMaterial` over `SurfaceMaterial`).
func cover() -> SnowlineMaterial:
	return _cover


## The cave clip, for a consumer that wants the raw hollow answer.
func carving() -> CaveCarving:
	return _carving


## The subsurface material rules. A caller asking this directly wants
## `block_id_for_depth(column, plan.depth_at(y))`, not `block_id_at(column, y)`, wherever the
## ground has moved — see `WorldColumn`.
func subsurface() -> SubsurfaceMaterial:
	return _subsurface


## The structure pass, for a consumer that wants sites, pads or parts directly.
func structures() -> StructureGenerator:
	return _structures


# ---------------------------------------------------------------------------
# Self-check
# ---------------------------------------------------------------------------

## Empty string when this generator can actually emit every block its passes can name and the
## voxel-value convention still holds, otherwise the reason.
##
## An instance check rather than a static one, unlike every other `self_check()` in Phase D:
## what could go wrong here is not a constant drifting, it is a *registry* that does not carry
## a block some pass names, or 037's `+1` offset drifting apart from `BlockyLibraryBuilder`.
## Both need the live registry to see. Run by `for_world()` before the object is returned, so a
## generator that exists has already passed it.
func self_check() -> String:
	if AIR_VOXEL_VALUE != 0:
		return "AIR_VOXEL_VALUE (%d) is not 0; 037 reserves library index 0 for air" % AIR_VOXEL_VALUE
	for id in _blocks.ids():
		var value: int = _voxel_values.get(id, AIR_VOXEL_VALUE)
		if value != _blocks.network_index(id) + 1:
			return "block '%s' maps to voxel value %d, not network_index + 1" % [id, value]
		if value == AIR_VOXEL_VALUE:
			return "block '%s' maps to the air value; the +1 offset is gone" % id
	for id in emitted_block_ids():
		if not _blocks.has_block(id):
			return "a pass can emit block '%s', which the block registry has no record for" % id
	return ""


## Every block id some pass under this generator can put in a buffer, other than a biome's own
## `surface_block_id`/`subsurface_block_id` (those are validated by the passes that own them,
## against the same registry, before this object exists).
##
## Listed rather than discovered: these are the four fixed ids scattered across four files as
## their own constants, and a fifth appearing without a line here would be exactly the silent
## divergence `self_check()` is for.
static func emitted_block_ids() -> PackedStringArray:
	return PackedStringArray([
		SubsurfaceMaterial.DEEP_BLOCK_ID,      # 076 — bedrock
		ShorelineMaterial.SHORE_BLOCK_ID,      # 084 — beaches
		SnowlineMaterial.SNOW_BLOCK_ID,        # 085 — snow caps
		StructureGenerator.STRUCTURE_BLOCK_ID, # 091 — masonry
	])
