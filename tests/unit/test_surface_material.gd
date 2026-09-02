extends TestCase
## `world/generation/surface_material.gd` — which block covers the ground at a column
## (brick 075).
##
## `BiomeTransition` (074) and its inputs stay exactly as tested in
## `test_biome_transition.gd`; nothing here re-asserts the partition or the blend weight.
## This file is about the two things 075 adds on top: `BiomeDefinition.surface_block_id`
## and the deterministic dither that picks between a primary's and a neighbor's.


func _surface_for(name: String, biomes: BiomeRegistry, blocks: BlockRegistry) -> SurfaceMaterial:
	return SurfaceMaterial.for_world(GenerationFixtures.hash_for(name), biomes, blocks)


## A registry holding every classifier id, each pointing at a real block from a small
## in-memory block registry — mirrors `test_biome_registry.gd`'s `_complete()`, extended
## with the field that brick adds.
func _complete_biomes(block_id: String = "block.grass") -> BiomeRegistry:
	var registry := BiomeRegistry.new()
	var step := 0
	for id in BiomeClassifier.IDS:
		var definition := BiomeDefinition.new()
		definition.id = id
		definition.display_name = StableId.leaf_of(id).capitalize()
		definition.debug_color = Color(step * 0.2, 1.0 - step * 0.2, 0.0)
		definition.surface_block_id = block_id
		definition.subsurface_block_id = "block.dirt"
		registry.register_biome(definition)
		step += 1
	registry.lock()
	return registry


func _small_blocks() -> BlockRegistry:
	var registry := BlockRegistry.new()
	var definition := BlockDefinition.new()
	definition.id = "block.grass"
	definition.display_name = "Grass"
	definition.texture_top = "res://assets/textures/blocks/grass_top.png"
	definition.texture_side = "res://assets/textures/blocks/grass_side.png"
	definition.texture_bottom = "res://assets/textures/blocks/dirt.png"
	definition.footstep_tag = "grass"
	registry.register_block(definition)
	registry.lock()
	return registry


# ---------------------------------------------------------------------------
# Binding
# ---------------------------------------------------------------------------

func test_requires_a_world_binding() -> void:
	assert_null(SurfaceMaterial.for_world(null, _complete_biomes(), _small_blocks()))


func test_requires_a_locked_biome_registry() -> void:
	var biomes := BiomeRegistry.new()  # never locked
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_null(SurfaceMaterial.for_world(hash, biomes, _small_blocks()))


func test_requires_a_locked_block_registry() -> void:
	var blocks := BlockRegistry.new()  # never locked
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_null(SurfaceMaterial.for_world(hash, _complete_biomes(), blocks))


func test_requires_a_complete_biome_registry() -> void:
	var biomes := BiomeRegistry.new()
	var definition := BiomeDefinition.new()
	definition.id = BiomeClassifier.GRASSLAND
	definition.display_name = "Grassland"
	definition.debug_color = Color8(106, 170, 74)
	definition.surface_block_id = "block.grass"
	biomes.register_biome(definition)
	biomes.lock()  # locked, but missing five of six biomes
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_null(SurfaceMaterial.for_world(hash, biomes, _small_blocks()))


func test_requires_every_surface_block_to_resolve() -> void:
	var biomes := _complete_biomes("block.does_not_exist")
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_null(SurfaceMaterial.for_world(hash, biomes, _small_blocks()))


func test_binds_to_every_fixture_world_with_the_shipped_catalogs() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	for name in GenerationFixtures.world_names():
		assert_not_null(_surface_for(name, biomes, blocks), "world '%s' builds" % name)


# ---------------------------------------------------------------------------
# The cross-domain check
# ---------------------------------------------------------------------------

func test_surface_block_reason_for_reports_a_missing_block() -> void:
	var biomes := _complete_biomes("block.does_not_exist")
	var reason := SurfaceMaterial.surface_block_reason_for(biomes, _small_blocks())
	assert_ne(reason, "")
	assert_true(reason.contains("block.does_not_exist"), reason)


func test_surface_block_reason_for_is_clean_when_every_block_resolves() -> void:
	assert_eq(SurfaceMaterial.surface_block_reason_for(
			_complete_biomes("block.grass"), _small_blocks()), "")


func test_the_shipped_catalog_names_only_real_blocks() -> void:
	assert_eq(SurfaceMaterial.surface_block_reason_for(
			BiomeCatalog.load_default(), BlockSet.load_default()), "")


# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------

func test_selection_agrees_with_the_blend_and_the_roll() -> void:
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var surface := SurfaceMaterial.for_world(hash, biomes, blocks)
	for column in GenerationFixtures.columns():
		var blend := surface.transition().blend_at(column)
		var expected: String = biomes.get_biome(blend["primary"]).surface_block_id
		var neighbor_id: String = blend["neighbor"]
		var weight: float = blend["neighbor_weight"]
		if not neighbor_id.is_empty() and weight > 0.0:
			var roll := hash.value01_column(column, WorldHash.SALT_SURFACE_MATERIAL)
			if roll < weight:
				expected = biomes.get_biome(neighbor_id).surface_block_id
		assert_eq(surface.block_id_at(column), expected, "column %s" % column)


func test_biome_id_at_agrees_with_block_id_at() -> void:
	# `biome_id_at()` (076's reason for existing) must always name the same biome whose
	# `surface_block_id` `block_id_at()` returned — the two are not allowed to answer from
	# two different rolls.
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var surface := SurfaceMaterial.for_world(hash, biomes, blocks)
	for column in GenerationFixtures.columns():
		var id := surface.biome_id_at(column)
		assert_true(biomes.has_biome(id), "column %s named unknown biome '%s'" % [column, id])
		assert_eq(surface.block_id_at(column), biomes.get_biome(id).surface_block_id,
				"column %s" % column)


func test_a_voxel_reads_its_own_column() -> void:
	var surface := _surface_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	for voxel in GenerationFixtures.voxels():
		var from_voxel := surface.block_id_at_voxel(voxel)
		var from_column := surface.block_id_at(GenerationGrid.voxel_to_column(voxel))
		assert_eq(from_voxel, from_column, "voxel %s" % voxel)


func test_every_result_is_a_known_block_id() -> void:
	var blocks := BlockSet.load_default()
	var surface := _surface_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), blocks)
	for column in GenerationFixtures.columns():
		var id := surface.block_id_at(column)
		assert_true(blocks.has_block(id), "column %s named unknown block '%s'" % [column, id])


# ---------------------------------------------------------------------------
# The shared determinism floor
# ---------------------------------------------------------------------------

func test_is_deterministic() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory := func() -> Callable:
		var surface := SurfaceMaterial.for_world(hash, biomes, blocks)
		return func(column: Vector2i) -> String: return surface.block_id_at(column)
	assert_eq(GenerationFixtures.determinism_reason(factory, GenerationFixtures.columns()), "")


func test_is_seed_sensitive() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var factory := func(hash: GenerationHash) -> Callable:
		var surface := SurfaceMaterial.for_world(hash, biomes, blocks)
		return func(column: Vector2i) -> String: return surface.block_id_at(column)
	assert_eq(GenerationFixtures.seed_sensitivity_reason(factory, GenerationFixtures.columns()),
			"")


func test_signature_is_pinned() -> void:
	var surface := _surface_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var sampler := func(column: Vector2i) -> String: return surface.block_id_at(column)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.columns()),
			PINNED_SIGNATURE)


## The digest of `block_id_at()` over `GenerationFixtures.columns()` for the `typed` world,
## against the shipped biome and block catalogs. Filled in from a real run rather than
## guessed — `GenerationFixtures.signature()`'s own reason: pinning a hundred individual
## expected values is how a test file stops being read.
const PINNED_SIGNATURE := "671f7833af3596ab"
