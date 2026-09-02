extends TestCase
## `world/generation/subsurface_material.gd` — what lies under the surface block at a column
## (brick 076).
##
## `SurfaceMaterial` (075), `TerracePass` (063) and `BiomeTransition` (074) stay exactly as
## tested in their own files; nothing here re-asserts the partition, the terraced height or
## the blend weight. This file is about the three things 076 adds on top:
## `BiomeDefinition.subsurface_block_id`, the fixed `DEEP_BLOCK_ID` bedrock, and the
## depth-based rule between them.


func _subsurface_for(name: String, biomes: BiomeRegistry, blocks: BlockRegistry) -> SubsurfaceMaterial:
	return SubsurfaceMaterial.for_world(GenerationFixtures.hash_for(name), biomes, blocks)


## A registry holding every classifier id, each with a real surface block and a real
## subsurface block from a small in-memory block registry — `test_surface_material.gd`'s
## `_complete_biomes()`, extended with the field this brick adds.
func _complete_biomes(subsurface_block_id: String = "block.dirt") -> BiomeRegistry:
	var registry := BiomeRegistry.new()
	var step := 0
	for id in BiomeClassifier.IDS:
		var definition := BiomeDefinition.new()
		definition.id = id
		definition.display_name = StableId.leaf_of(id).capitalize()
		definition.debug_color = Color(step * 0.2, 1.0 - step * 0.2, 0.0)
		definition.surface_block_id = "block.grass"
		definition.subsurface_block_id = subsurface_block_id
		registry.register_biome(definition)
		step += 1
	registry.lock()
	return registry


## Grass, dirt and stone — enough to resolve every fixture biome's surface block, subsurface
## block and `SubsurfaceMaterial.DEEP_BLOCK_ID`.
func _small_blocks() -> BlockRegistry:
	var registry := BlockRegistry.new()
	for id in ["block.grass", "block.dirt", "block.stone"]:
		var definition := BlockDefinition.new()
		definition.id = id
		definition.display_name = StableId.leaf_of(id).capitalize()
		definition.texture_top = "res://assets/textures/blocks/grass_top.png"
		definition.texture_side = "res://assets/textures/blocks/grass_side.png"
		definition.texture_bottom = "res://assets/textures/blocks/dirt.png"
		definition.footstep_tag = "stone"
		registry.register_block(definition)
	registry.lock()
	return registry


# ---------------------------------------------------------------------------
# Binding
# ---------------------------------------------------------------------------

func test_requires_a_world_binding() -> void:
	assert_null(SubsurfaceMaterial.for_world(null, _complete_biomes(), _small_blocks()))


func test_delegates_binding_failures_to_surface_material() -> void:
	# `SurfaceMaterial.for_world()` already refuses an unlocked registry, a registry that
	# fails `self_check()`, and a surface block that does not resolve; 076 does not
	# re-implement any of that, it just fails the same way through the same call.
	var biomes := BiomeRegistry.new()  # never locked
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_null(SubsurfaceMaterial.for_world(hash, biomes, _small_blocks()))


func test_requires_every_subsurface_block_to_resolve() -> void:
	var biomes := _complete_biomes("block.does_not_exist")
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_null(SubsurfaceMaterial.for_world(hash, biomes, _small_blocks()))


func test_requires_the_deep_block_to_resolve() -> void:
	var blocks := BlockRegistry.new()
	var grass := BlockDefinition.new()
	grass.id = "block.grass"
	grass.display_name = "Grass"
	grass.texture_top = "res://assets/textures/blocks/grass_top.png"
	grass.texture_side = "res://assets/textures/blocks/grass_side.png"
	grass.texture_bottom = "res://assets/textures/blocks/dirt.png"
	grass.footstep_tag = "grass"
	blocks.register_block(grass)
	var dirt := BlockDefinition.new()
	dirt.id = "block.dirt"
	dirt.display_name = "Dirt"
	dirt.texture_top = "res://assets/textures/blocks/dirt.png"
	dirt.texture_side = "res://assets/textures/blocks/dirt.png"
	dirt.texture_bottom = "res://assets/textures/blocks/dirt.png"
	dirt.footstep_tag = "dirt"
	blocks.register_block(dirt)
	blocks.lock()  # no block.stone at all
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_null(SubsurfaceMaterial.for_world(hash, _complete_biomes(), blocks))


func test_binds_to_every_fixture_world_with_the_shipped_catalogs() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	for name in GenerationFixtures.world_names():
		assert_not_null(_subsurface_for(name, biomes, blocks), "world '%s' builds" % name)


# ---------------------------------------------------------------------------
# The cross-domain check
# ---------------------------------------------------------------------------

func test_subsurface_block_reason_for_reports_a_missing_subsurface_block() -> void:
	var biomes := _complete_biomes("block.does_not_exist")
	var reason := SubsurfaceMaterial.subsurface_block_reason_for(biomes, _small_blocks())
	assert_ne(reason, "")
	assert_true(reason.contains("block.does_not_exist"), reason)


func test_subsurface_block_reason_for_reports_a_missing_deep_block() -> void:
	var blocks := BlockRegistry.new()
	var dirt := BlockDefinition.new()
	dirt.id = "block.dirt"
	dirt.display_name = "Dirt"
	dirt.texture_top = "res://assets/textures/blocks/dirt.png"
	dirt.texture_side = "res://assets/textures/blocks/dirt.png"
	dirt.texture_bottom = "res://assets/textures/blocks/dirt.png"
	dirt.footstep_tag = "dirt"
	blocks.register_block(dirt)
	blocks.lock()
	var reason := SubsurfaceMaterial.subsurface_block_reason_for(_complete_biomes(), blocks)
	assert_ne(reason, "")
	assert_true(reason.contains(SubsurfaceMaterial.DEEP_BLOCK_ID), reason)


func test_subsurface_block_reason_for_is_clean_when_every_block_resolves() -> void:
	assert_eq(SubsurfaceMaterial.subsurface_block_reason_for(
			_complete_biomes("block.dirt"), _small_blocks()), "")


func test_the_shipped_catalog_names_only_real_subsurface_blocks() -> void:
	assert_eq(SubsurfaceMaterial.subsurface_block_reason_for(
			BiomeCatalog.load_default(), BlockSet.load_default()), "")


# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------

func test_at_or_above_the_surface_is_empty() -> void:
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var subsurface := SubsurfaceMaterial.for_world(hash, biomes, blocks)
	var terrace := TerracePass.for_world(hash)
	for column in GenerationFixtures.columns():
		var surface_y := terrace.surface_y(column)
		assert_eq(subsurface.block_id_at(column, surface_y), "", "column %s at the surface" % column)
		assert_eq(subsurface.block_id_at(column, surface_y + 1), "",
				"column %s above the surface" % column)
		assert_eq(subsurface.block_id_at(column, surface_y + 50), "",
				"column %s well above the surface" % column)


func test_selection_agrees_with_the_surfaces_own_biome_and_the_depth_rule() -> void:
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var subsurface := SubsurfaceMaterial.for_world(hash, biomes, blocks)
	var terrace := TerracePass.for_world(hash)
	for column in GenerationFixtures.columns():
		var surface_y := terrace.surface_y(column)
		var biome := biomes.get_biome(subsurface.surface().biome_id_at(column))
		for depth in [1, SubsurfaceMaterial.SUBSURFACE_DEPTH_VOXELS]:
			var expected := biome.subsurface_block_id
			assert_eq(subsurface.block_id_at(column, surface_y - depth), expected,
					"column %s depth %d" % [column, depth])
		for depth in [SubsurfaceMaterial.SUBSURFACE_DEPTH_VOXELS + 1,
				SubsurfaceMaterial.SUBSURFACE_DEPTH_VOXELS + 20]:
			assert_eq(subsurface.block_id_at(column, surface_y - depth),
					SubsurfaceMaterial.DEEP_BLOCK_ID, "column %s depth %d" % [column, depth])


func test_never_puts_a_neighbors_topsoil_under_the_wrong_surface() -> void:
	# 076's whole reason for reading `biome_id_at()` instead of re-dithering: the topsoil at
	# a column must be the block belonging to whichever biome actually won that column's
	# surface, at every fixture column of every fixture world — not just the one this file's
	# own comment argues about.
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	for name in GenerationFixtures.world_names():
		var hash := GenerationFixtures.hash_for(name)
		var subsurface := SubsurfaceMaterial.for_world(hash, biomes, blocks)
		var terrace := TerracePass.for_world(hash)
		for column in GenerationFixtures.columns():
			var surface_y := terrace.surface_y(column)
			var winning_id := subsurface.surface().biome_id_at(column)
			var expected := biomes.get_biome(winning_id).subsurface_block_id
			assert_eq(subsurface.block_id_at(column, surface_y - 1), expected,
					"%s column %s" % [name, column])


func test_a_voxel_reads_its_own_column_and_y() -> void:
	var subsurface := _subsurface_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	for voxel in GenerationFixtures.voxels():
		var from_voxel := subsurface.block_id_at_voxel(voxel)
		var from_column := subsurface.block_id_at(GenerationGrid.voxel_to_column(voxel), voxel.y)
		assert_eq(from_voxel, from_column, "voxel %s" % voxel)


func test_every_below_surface_result_is_a_known_block_id() -> void:
	var blocks := BlockSet.load_default()
	var subsurface := _subsurface_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), blocks)
	var terrace := subsurface.terrace()
	for column in GenerationFixtures.columns():
		var surface_y := terrace.surface_y(column)
		var id := subsurface.block_id_at(column, surface_y - 1)
		assert_true(blocks.has_block(id), "column %s named unknown block '%s'" % [column, id])


# ---------------------------------------------------------------------------
# The shared determinism floor
# ---------------------------------------------------------------------------
#
# `GenerationFixtures.voxels()` is unsuitable here on its own: most of its y values sit at
# or near 0, and whether that is above or below a given world's ground is a coin flip this
# fixture was never built to control, so two different seeds can easily agree at "above the
# surface" on every one of them (a real failure this file's first draft hit). Sampling one
# voxel below each column's *own* terraced surface — computed fresh from the pass under
# test, not baked into the sample — is what `test_every_below_surface_result_is_a_known_
# block_id` above already does for the same reason; the determinism floor reuses it.

func _one_below_surface(subsurface: SubsurfaceMaterial) -> Callable:
	return func(column: Vector2i) -> String:
		return subsurface.block_id_at(column, subsurface.terrace().surface_y(column) - 1)


func test_is_deterministic() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory := func() -> Callable:
		return _one_below_surface(SubsurfaceMaterial.for_world(hash, biomes, blocks))
	assert_eq(GenerationFixtures.determinism_reason(factory, GenerationFixtures.columns()), "")


func test_is_seed_sensitive() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var factory := func(hash: GenerationHash) -> Callable:
		return _one_below_surface(SubsurfaceMaterial.for_world(hash, biomes, blocks))
	assert_eq(GenerationFixtures.seed_sensitivity_reason(factory, GenerationFixtures.columns()),
			"")


func test_signature_is_pinned() -> void:
	var subsurface := _subsurface_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_eq(GenerationFixtures.signature(_one_below_surface(subsurface),
			GenerationFixtures.columns()), PINNED_SIGNATURE)


## The digest of "one voxel below the surface" over `GenerationFixtures.columns()` for the
## `typed` world, against the shipped biome and block catalogs. Filled in from a real run
## rather than guessed — `GenerationFixtures.signature()`'s own reason.
const PINNED_SIGNATURE := "58988f30d866891d"


# ---------------------------------------------------------------------------
# The constant
# ---------------------------------------------------------------------------

func test_self_check_passes() -> void:
	assert_eq(SubsurfaceMaterial.self_check(), "")


func test_the_depth_is_strictly_under_one_terrace() -> void:
	# The legibility property the class comment argues for: a full-terrace riser
	# (`TerracePass.max_riser_voxels()`) must expose bedrock, not just topsoil.
	assert_true(SubsurfaceMaterial.SUBSURFACE_DEPTH_VOXELS < TerracePass.TERRACE_HEIGHT_VOXELS)


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

func test_exposes_the_passes_underneath() -> void:
	var subsurface := _subsurface_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_not_null(subsurface.surface())
	assert_not_null(subsurface.terrace())
	assert_not_null(subsurface.biomes())
