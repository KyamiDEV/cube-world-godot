extends TestCase
## `world/generation/world_generator.gd` — the Phase D passes assembled into a real
## `VoxelGenerator` (brick 091b).
##
## Every pass this file composes already has its own test file, and none of that is re-asserted
## here. What is specific to `WorldGenerator` is the **composition**: which surface each
## question is answered against, the precedence between a structure and the terrain under it,
## and the fact that a `VoxelBuffer` comes back holding exactly what the content query says it
## should. The engine actually calling `_generate_block()` is
## `tests/integration/test_world_generation.gd`'s question, not this file's.
##
## The fixture voxels below were found by sweeping the `typed` world at this brick and are
## named rather than re-derived, `test_cave_carving.gd`/`test_underground_material.gd`'s own
## convention: each assertion states the property first and uses the fixture only to reach a
## place where the property is observable.

## Region (-3, -4) of the `typed` world carries a structure: anchor (-2666, -3701), base_y 80,
## half extent 7, wall height 8.
const STRUCTURE_REGION := Vector2i(-3, -4)
const STRUCTURE_ANCHOR := Vector2i(-2666, -3701)

## A pad column of a different `typed`-world site whose ground the levelling cut by one riser.
const LEVELLED_COLUMN := Vector2i(-4392, -2994)

## §22.2's own worked case: a real river column, carved a riser below its terrace plane.
const RIVER_COLUMN := Vector2i(94139, 69581)

## `test_cave_carving.gd::KNOWN_HOLLOW_VOXEL`, reused rather than re-swept.
const CAVE_VOXEL := Vector3i(-323, 34, -221)


func _generator(name: String = GenerationFixtures.WORLD_TYPED) -> WorldGenerator:
	return WorldGenerator.for_world(GenerationFixtures.hash_for(name),
			BiomeCatalog.load_default(), BlockSet.load_default())


func _buffer(size: int = 16) -> VoxelBuffer:
	var buffer := VoxelBuffer.new()
	buffer.create(size, size, size)
	return buffer


# ---------------------------------------------------------------------------
# Binding
# ---------------------------------------------------------------------------

func test_requires_a_world_binding() -> void:
	assert_null(WorldGenerator.for_world(null, BiomeCatalog.load_default(),
			BlockSet.load_default()))


func test_requires_a_locked_block_registry() -> void:
	assert_null(WorldGenerator.for_world(GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED),
			BiomeCatalog.load_default(), BlockRegistry.new()))


func test_delegates_binding_failures_to_the_passes_underneath() -> void:
	# `SurfaceMaterial.for_world()` already refuses an unlocked biome registry; this file does
	# not re-implement that, it fails the same way through the same call.
	assert_null(WorldGenerator.for_world(GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED),
			BiomeRegistry.new(), BlockSet.load_default()))


func test_binds_to_every_fixture_world_with_the_shipped_catalogs() -> void:
	for name in GenerationFixtures.world_names():
		assert_not_null(_generator(name), "world '%s' builds" % name)


func test_binds_from_a_world_seed_directly() -> void:
	var generator := WorldGenerator.for_seed(
			GenerationFixtures.world(GenerationFixtures.WORLD_TYPED),
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_not_null(generator)
	assert_eq(generator.world_seed().value,
			GenerationFixtures.world(GenerationFixtures.WORLD_TYPED).value)


func test_reports_the_generation_version_its_output_belongs_to() -> void:
	# The version boundary §31.6 crosses: from this brick on, a world's output is tied to it.
	assert_eq(_generator().generation_version(), GenerationVersion.CURRENT)


func test_self_check_passes_for_the_shipped_catalogs() -> void:
	assert_eq(_generator().self_check(), "")


func test_every_fixed_block_id_a_pass_can_emit_is_registered() -> void:
	var blocks := BlockSet.load_default()
	for id in WorldGenerator.emitted_block_ids():
		assert_true(blocks.has_block(id), "'%s' is emitted but not registered" % id)


# ---------------------------------------------------------------------------
# The shared determinism floor
# ---------------------------------------------------------------------------

func test_is_deterministic() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var world_hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory := func() -> Callable:
		var generator := WorldGenerator.for_world(world_hash, biomes, blocks)
		return func(voxel: Vector3i) -> String: return generator.block_id_at_voxel(voxel)
	assert_eq(GenerationFixtures.determinism_reason(factory, GenerationFixtures.voxels()), "")


func test_signature_is_pinned() -> void:
	var generator := _generator()
	var sampler := func(voxel: Vector3i) -> String: return generator.block_id_at_voxel(voxel)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.voxels()),
			PINNED_SIGNATURE)


## The digest of `block_id_at_voxel()` over `GenerationFixtures.voxels()` for the `typed` world,
## against the shipped biome and block catalogs. **Changing this is a generation version bump**
## — §31.6, and the first pin in the project for which that is literally true.
##
## It equals `test_underground_material.gd::PINNED_SIGNATURE` today, and that is a real result
## rather than a copied constant: none of the fixture voxels sits on a surface, on a pad or in
## a channel, so at all fifteen of them the assembled generator returns exactly what 079 alone
## already did. The composition-specific behaviour is pinned by the named-fixture tests below,
## not by this digest.
const PINNED_SIGNATURE := "a9ac004142d5a8bb"


## `GenerationFixtures.voxels()` clusters near y = 0, which is above or below a given world's
## ground close to a coin flip — `test_underground_material.gd`'s own finding. Sampling the
## cover block at each column's *own* ground is the same fix, reused.
func _cover_sampler(generator: WorldGenerator) -> Callable:
	return func(column: Vector2i) -> String:
		return generator.block_id_at_voxel(
				Vector3i(column.x, generator.column_at(column).ground_y, column.y))


func test_is_seed_sensitive() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var factory := func(world_hash: GenerationHash) -> Callable:
		return _cover_sampler(WorldGenerator.for_world(world_hash, biomes, blocks))
	assert_eq(GenerationFixtures.seed_sensitivity_reason(factory, GenerationFixtures.columns()),
			"")


# ---------------------------------------------------------------------------
# The resolved column
# ---------------------------------------------------------------------------

func test_every_resolved_column_is_internally_consistent() -> void:
	var generator := _generator()
	for column in GenerationFixtures.columns():
		assert_eq(generator.column_at(column).validate(), "", "column %s" % column)


func test_ground_follows_the_water_carved_chain_where_no_structure_stands() -> void:
	var generator := _generator()
	var ground := generator.ground()
	for column in GenerationFixtures.columns():
		var plan := generator.column_at(column)
		if plan.has_structure():
			continue
		assert_eq(plan.ground_y, ground.surface_y(column),
				"column %s must fill to LakePass, not TerracePass" % column)


func test_a_river_column_keeps_its_carved_bed() -> void:
	# The failure this pins: reading `StructureGenerator.surface_y_at()` for the ground would
	# read `TerracePass` internally and silently un-carve the channel.
	var generator := _generator()
	var plan := generator.column_at(RIVER_COLUMN)
	assert_true(generator.ground().river().is_river_at(RIVER_COLUMN),
			"fixture column is no longer a river; pick a new one")
	assert_eq(plan.ground_shift(), -RiverPass.CARVE_DEPTH_VOXELS)
	assert_eq(plan.ground_y, generator.ground().surface_y(RIVER_COLUMN))


func test_topsoil_follows_the_carved_bed_not_the_terrace_plane() -> void:
	# The concrete consequence of `WorldColumn.depth_at()`: the voxel under a river bed is
	# topsoil, not the bedrock a terrace-measured depth of 9 would have returned.
	var generator := _generator()
	var plan := generator.column_at(RIVER_COLUMN)
	var under_bed := generator.block_id_in_column(plan, plan.ground_y - 1)
	assert_eq(under_bed, generator.subsurface().block_id_for_depth(RIVER_COLUMN, 1))
	assert_ne(under_bed, generator.subsurface().block_id_at(RIVER_COLUMN, plan.ground_y - 1),
			"a terrace-measured depth would call this voxel bedrock; if the two now agree, the "
			+ "fixture column's biome no longer distinguishes them — pick a new one")


func test_a_cut_pad_column_is_air_above_its_levelled_ground() -> void:
	var generator := _generator()
	var plan := generator.column_at(LEVELLED_COLUMN)
	assert_true(plan.has_structure(), "fixture column is no longer on a pad; pick a new one")
	assert_true(plan.ground_shift() < 0, "fixture column is no longer cut; pick a new one")
	assert_ne(generator.block_id_in_column(plan, plan.ground_y), "",
			"the levelled surface itself is solid ground")
	for y in range(plan.ground_y + 1, plan.terrace_y + 1):
		assert_eq(generator.block_id_in_column(plan, y), "",
				"the levelling removed y=%d; it must not generate back" % y)


func test_a_filled_pad_column_has_no_gap_over_the_terrace_plane() -> void:
	# The fill direction is rare enough (§30.6) that no natural fixture in this file's own
	# region carries one, so it is exercised against a hand-built plan at a real column. This is
	# the direction that breaks if depth is ever measured from `terrace_y` again:
	# `SubsurfaceMaterial` would call every voxel above the terrace plane "above the surface"
	# and hand back air, punching a hole straight through the plinth.
	var generator := _generator()
	var natural := generator.column_at(LEVELLED_COLUMN)
	var raised := natural.terrace_y + TerracePass.TERRACE_HEIGHT_VOXELS
	var plan := WorldColumn.new(LEVELLED_COLUMN, raised, natural.terrace_y, natural.site)
	for y in range(natural.terrace_y + 1, raised + 1):
		var voxel := Vector3i(LEVELLED_COLUMN.x, y, LEVELLED_COLUMN.y)
		if StructureGenerator.part_of(plan.site, voxel) != StructureGenerator.Part.NONE:
			continue
		assert_ne(generator.block_id_in_column(plan, y), "",
				"filled ground has a hole at y=%d" % y)


# ---------------------------------------------------------------------------
# The five-step order
# ---------------------------------------------------------------------------

func test_air_above_the_ground() -> void:
	var generator := _generator()
	for column in GenerationFixtures.columns():
		var plan := generator.column_at(column)
		if plan.has_structure():
			continue
		assert_eq(generator.block_id_in_column(plan, plan.ground_y + 1), "", "column %s" % column)


func test_the_cover_chain_answers_the_surface_voxel() -> void:
	var generator := _generator()
	for column in GenerationFixtures.columns():
		var plan := generator.column_at(column)
		if plan.has_structure():
			continue
		assert_eq(generator.block_id_in_column(plan, plan.ground_y),
				generator.cover().block_id_at(column), "column %s" % column)


func test_the_surface_voxel_is_always_a_registered_block() -> void:
	var blocks := BlockSet.load_default()
	var generator := _generator()
	for column in GenerationFixtures.columns():
		var plan := generator.column_at(column)
		var id := generator.block_id_in_column(plan, plan.ground_y)
		assert_true(blocks.has_block(id), "column %s covered by unknown block '%s'" % [column, id])


func test_a_carved_cave_reads_as_air() -> void:
	var generator := _generator()
	assert_true(generator.carving().is_hollow_at(CAVE_VOXEL),
			"fixture voxel is no longer CaveCarving-hollow; pick a new one")
	assert_eq(generator.block_id_at_voxel(CAVE_VOXEL), "")


func test_caves_are_clipped_against_the_terrace_plane_not_the_moved_ground() -> void:
	# §31.1: shifting the cave clip with the ground would move a cavern rather than the ground
	# above it, and would let a filled pad come back carved.
	var generator := _generator()
	for column in GenerationFixtures.columns():
		var plan := generator.column_at(column)
		for depth in range(1, 24):
			var y := plan.ground_y - depth
			var expected_air := generator.carving().is_hollow_for(
					Vector3i(column.x, y, column.y), plan.terrace_y)
			var is_air := generator.block_id_in_column(plan, y).is_empty()
			assert_eq(is_air, expected_air, "column %s at y=%d" % [column, y])


func test_a_structure_floor_and_walls_are_masonry() -> void:
	var generator := _generator()
	var site := generator.structures().site_at(STRUCTURE_REGION)
	assert_not_null(site, "fixture region no longer carries a structure; pick a new one")
	var wall_column := site.anchor_column + Vector2i(site.half_extent_voxels, 0)
	var plan := generator.column_at(wall_column)
	assert_true(site.is_wall_column(wall_column))
	for y in range(site.base_y, site.top_y() + 1):
		assert_eq(generator.block_id_in_column(plan, y), StructureGenerator.STRUCTURE_BLOCK_ID,
				"wall column at y=%d" % y)
	assert_eq(generator.block_id_in_column(plan, site.top_y() + 1), "", "above the wall crown")


func test_a_structure_interior_is_carved_air() -> void:
	# The failure this pins: without honouring `clears_terrain_at()`, a plinth cut into a
	# hillside generates solid and reads as a stone block rather than a building.
	var generator := _generator()
	var site := generator.structures().site_at(STRUCTURE_REGION)
	assert_not_null(site)
	var plan := generator.column_at(site.anchor_column)
	assert_eq(generator.block_id_in_column(plan, site.base_y),
			StructureGenerator.STRUCTURE_BLOCK_ID, "the floor slab under the interior")
	for y in range(site.base_y + 1, site.top_y() + 1):
		assert_eq(generator.block_id_in_column(plan, y), "", "interior at y=%d" % y)


func test_a_structure_wins_over_the_terrain_at_every_part_it_claims() -> void:
	var generator := _generator()
	var site := generator.structures().site_at(STRUCTURE_REGION)
	assert_not_null(site)
	var checked := 0
	for dz in range(-site.half_extent_voxels, site.half_extent_voxels + 1):
		for dx in range(-site.half_extent_voxels, site.half_extent_voxels + 1):
			var column := site.anchor_column + Vector2i(dx, dz)
			var plan := generator.column_at(column)
			for y in range(site.base_y, site.top_y() + 1):
				var part := StructureGenerator.part_of(site, Vector3i(column.x, y, column.y))
				var id := generator.block_id_in_column(plan, y)
				if part == StructureGenerator.Part.FLOOR or part == StructureGenerator.Part.WALL:
					assert_eq(id, StructureGenerator.STRUCTURE_BLOCK_ID)
				elif part == StructureGenerator.Part.INTERIOR:
					assert_eq(id, "")
				checked += 1
	assert_true(checked > 0, "the footprint sweep must actually visit voxels")


# ---------------------------------------------------------------------------
# Voxel values
# ---------------------------------------------------------------------------

func test_air_is_voxel_value_zero() -> void:
	assert_eq(WorldGenerator.AIR_VOXEL_VALUE, 0)
	assert_eq(_generator().voxel_value_of(""), 0)


func test_every_block_value_is_its_network_index_plus_one() -> void:
	var blocks := BlockSet.load_default()
	var generator := _generator()
	for id in blocks.ids():
		assert_eq(generator.voxel_value_of(id), blocks.network_index(id) + 1, id)


func test_an_unknown_block_reads_as_air_rather_than_as_another_block() -> void:
	assert_eq(_generator().voxel_value_of("block.does.not.exist"),
			WorldGenerator.AIR_VOXEL_VALUE)


func test_uses_only_the_type_channel() -> void:
	# 039's own trap: `VoxelGeneratorFlat.channel` defaults to CHANNEL_SDF, which a blocky
	# mesher cannot read.
	assert_eq(_generator()._get_used_channels_mask(), 1 << VoxelBuffer.CHANNEL_TYPE)


# ---------------------------------------------------------------------------
# The buffer write
# ---------------------------------------------------------------------------

func test_a_filled_buffer_matches_the_content_query_voxel_for_voxel() -> void:
	var generator := _generator()
	# 8³ rather than a full 16³ chunk: `block_id_at_voxel()` re-resolves the whole column every
	# call (that is the point of `column_at()` existing), so the cross-check costs one full
	# column resolution per voxel and 4096 of them is minutes, not seconds.
	var origin := Vector3i(0, generator.column_at(Vector2i(0, 0)).ground_y - 4, 0)
	var buffer := _buffer(8)
	generator.fill_buffer(buffer, origin)
	for z in 8:
		for x in 8:
			for y in 8:
				var voxel := origin + Vector3i(x, y, z)
				assert_eq(buffer.get_voxel(x, y, z, VoxelBuffer.CHANNEL_TYPE),
						generator.voxel_value_of(generator.block_id_at_voxel(voxel)),
						"voxel %s" % voxel)


func test_a_buffer_above_the_ground_is_entirely_air() -> void:
	var generator := _generator()
	var buffer := _buffer()
	generator.fill_buffer(buffer, Vector3i(0, ErosionPass.MAXIMUM_VOXELS + 16, 0))
	for z in 16:
		for x in 16:
			for y in 16:
				assert_eq(buffer.get_voxel(x, y, z, VoxelBuffer.CHANNEL_TYPE),
						WorldGenerator.AIR_VOXEL_VALUE)


func test_a_buffer_below_the_deepest_ground_is_entirely_solid() -> void:
	# Below `ErosionPass.MINIMUM_VOXELS` every column is underground, so only a cave can be
	# air — and `CaveMask` never carves everything.
	var generator := _generator()
	var buffer := _buffer()
	var origin := Vector3i(0, ErosionPass.MINIMUM_VOXELS - 64, 0)
	generator.fill_buffer(buffer, origin)
	var solid := 0
	for z in 16:
		for x in 16:
			for y in 16:
				if buffer.get_voxel(x, y, z, VoxelBuffer.CHANNEL_TYPE) \
						!= WorldGenerator.AIR_VOXEL_VALUE:
					solid += 1
	assert_true(solid > 0, "deep ground must not generate empty")


func test_a_buffer_the_engine_asks_for_at_a_higher_lod_is_left_alone() -> void:
	# `VoxelTerrain` is fixed-LOD and never asks; generating the wrong scale of world would be
	# worse than generating nothing.
	var generator := _generator()
	var buffer := _buffer()
	var origin := Vector3i(0, generator.column_at(Vector2i(0, 0)).ground_y - 8, 0)
	generator._generate_block(buffer, origin, 1)
	assert_eq(buffer.get_voxel(0, 0, 0, VoxelBuffer.CHANNEL_TYPE),
			WorldGenerator.AIR_VOXEL_VALUE)


func test_the_engine_entry_point_agrees_with_fill_buffer() -> void:
	var generator := _generator()
	var origin := Vector3i(0, generator.column_at(Vector2i(0, 0)).ground_y - 8, 0)
	var direct := _buffer()
	var virtual := _buffer()
	generator.fill_buffer(direct, origin)
	generator._generate_block(virtual, origin, 0)
	for z in 16:
		for x in 16:
			for y in 16:
				assert_eq(virtual.get_voxel(x, y, z, VoxelBuffer.CHANNEL_TYPE),
						direct.get_voxel(x, y, z, VoxelBuffer.CHANNEL_TYPE))


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

func test_exposes_the_passes_underneath() -> void:
	var generator := _generator()
	assert_not_null(generator.generation_hash())
	assert_not_null(generator.blocks())
	assert_not_null(generator.ground())
	assert_not_null(generator.cover())
	assert_not_null(generator.carving())
	assert_not_null(generator.subsurface())
	assert_not_null(generator.structures())
