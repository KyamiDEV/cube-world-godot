extends TestCase
## `world/generation/underground_material.gd` — what actually occupies a below-surface
## voxel once caves are carved into it (brick 079).
##
## `test_cave_carving.gd` and `test_subsurface_material.gd` already cover the two passes
## this file composes; nothing here re-asserts the carving clip or the topsoil/bedrock rule
## on their own terms. What is specific to `UndergroundMaterial` is the combination itself:
## a hollow voxel must read as air (`""`) regardless of what `SubsurfaceMaterial` would have
## said there, and a solid underground voxel must read exactly what `SubsurfaceMaterial`
## already says.


func _underground_for(name: String, biomes: BiomeRegistry, blocks: BlockRegistry) -> UndergroundMaterial:
	return UndergroundMaterial.for_world(GenerationFixtures.hash_for(name), biomes, blocks)


## A registry holding every classifier id with a real surface and subsurface block —
## `test_subsurface_material.gd`'s own `_complete_biomes()`, reused rather than re-authored.
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


## Grass, dirt and stone — enough to resolve every fixture biome's surface, subsurface and
## `SubsurfaceMaterial.DEEP_BLOCK_ID`.
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
	assert_null(UndergroundMaterial.for_world(null, _complete_biomes(), _small_blocks()))


func test_delegates_binding_failures_to_subsurface_material() -> void:
	# `SubsurfaceMaterial.for_world()` already refuses an unlocked biome registry; 079 does
	# not re-implement that, it just fails the same way through the same call.
	var biomes := BiomeRegistry.new()  # never locked
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	assert_null(UndergroundMaterial.for_world(hash, biomes, _small_blocks()))


func test_binds_to_every_fixture_world_with_the_shipped_catalogs() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	for name in GenerationFixtures.world_names():
		assert_not_null(_underground_for(name, biomes, blocks), "world '%s' builds" % name)


# ---------------------------------------------------------------------------
# The shared determinism floor
# ---------------------------------------------------------------------------

func test_is_deterministic() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var hash := GenerationFixtures.hash_for(GenerationFixtures.WORLD_TYPED)
	var factory := func() -> Callable:
		var underground := UndergroundMaterial.for_world(hash, biomes, blocks)
		return func(voxel: Vector3i) -> String: return underground.block_id_at_voxel(voxel)
	assert_eq(GenerationFixtures.determinism_reason(factory, GenerationFixtures.voxels()), "")


func test_signature_is_pinned() -> void:
	var underground := _underground_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var sampler := func(voxel: Vector3i) -> String: return underground.block_id_at_voxel(voxel)
	assert_eq(GenerationFixtures.signature(sampler, GenerationFixtures.voxels()),
			PINNED_SIGNATURE)


## The digest of `block_id_at_voxel()` over `GenerationFixtures.voxels()` for the `typed`
## world, against the shipped biome and block catalogs.
const PINNED_SIGNATURE := "a9ac004142d5a8bb"


# ---------------------------------------------------------------------------
# Seed sensitivity
# ---------------------------------------------------------------------------
#
# `GenerationFixtures.voxels()` is unsuitable here on its own, for the same reason
# `test_subsurface_material.gd` already found for `SubsurfaceMaterial` alone: most of its y
# values sit at or near 0, and whether that lands above or below a given world's own ground
# is close to a coin flip the fixture was never built to control. Sampling one voxel below
# each column's *own* terraced surface — computed fresh from the pass under test — is the
# same fix, reused rather than re-derived.

func _one_below_surface(underground: UndergroundMaterial) -> Callable:
	return func(column: Vector2i) -> String:
		var surface_y := underground.subsurface().terrace().surface_y(column)
		var voxel := Vector3i(column.x, surface_y - 1, column.y)
		return underground.block_id_at_voxel(voxel)


func test_is_seed_sensitive() -> void:
	var biomes := BiomeCatalog.load_default()
	var blocks := BlockSet.load_default()
	var factory := func(hash: GenerationHash) -> Callable:
		return _one_below_surface(UndergroundMaterial.for_world(hash, biomes, blocks))
	assert_eq(GenerationFixtures.seed_sensitivity_reason(factory, GenerationFixtures.columns()),
			"")


# ---------------------------------------------------------------------------
# The combination — the property no shared fixture check can see
# ---------------------------------------------------------------------------

func test_a_carved_cave_reads_as_air() -> void:
	# `test_cave_carving.gd::KNOWN_HOLLOW_VOXEL`, reused rather than re-swept: underground
	# and CaveMask-hollow on the `typed` world.
	var known_hollow_voxel := Vector3i(-323, 34, -221)
	var underground := _underground_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_true(underground.carving().is_hollow_at(known_hollow_voxel),
			"fixture voxel is no longer CaveCarving-hollow; pick a new one")
	assert_eq(underground.block_id_at_voxel(known_hollow_voxel), "")


func test_a_solid_underground_voxel_reads_its_subsurface_material() -> void:
	# The origin — `test_cave_carving.gd::KNOWN_SOLID_VOXEL`: underground but not hollow, so
	# this must equal whatever `SubsurfaceMaterial` alone says there, not air.
	var known_solid_voxel := Vector3i(0, 0, 0)
	var underground := _underground_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_false(underground.carving().is_hollow_at(known_solid_voxel),
			"fixture voxel is no longer solid; pick a new one")
	var expected := underground.subsurface().block_id_at_voxel(known_solid_voxel)
	assert_ne(expected, "", "fixture voxel should be real ground, not air")
	assert_eq(underground.block_id_at_voxel(known_solid_voxel), expected)


func test_agrees_with_carving_and_subsurface_at_every_sample_voxel() -> void:
	var underground := _underground_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	var carving := underground.carving()
	var subsurface := underground.subsurface()
	for voxel in GenerationFixtures.voxels():
		var expected := "" if carving.is_hollow_at(voxel) else subsurface.block_id_at_voxel(voxel)
		assert_eq(underground.block_id_at_voxel(voxel), expected, "voxel %s" % voxel)


func test_an_above_ground_cave_voxel_stays_air_for_the_surface_reason_not_the_carving_reason() -> void:
	# `test_cave_carving.gd::KNOWN_ABOVE_GROUND_CAVE_VOXEL`: CaveMask alone calls this
	# hollow, but it sits 280 voxels above its own column's terraced surface, so
	# CaveCarving already clips it to false. The combined answer must still be air here —
	# but because SubsurfaceMaterial says "above the surface", not because of the cave.
	var known_above_ground_cave_voxel := Vector3i(1, 344, 2)
	var underground := _underground_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_false(underground.carving().is_hollow_at(known_above_ground_cave_voxel))
	assert_eq(underground.block_id_at_voxel(known_above_ground_cave_voxel), "")


func test_every_below_surface_result_is_air_or_a_known_block_id() -> void:
	var blocks := BlockSet.load_default()
	var underground := _underground_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), blocks)
	for column in GenerationFixtures.columns():
		var surface_y := underground.subsurface().terrace().surface_y(column)
		var voxel := Vector3i(column.x, surface_y - 1, column.y)
		var id := underground.block_id_at_voxel(voxel)
		assert_true(id == "" or blocks.has_block(id),
				"column %s named unknown block '%s'" % [column, id])


# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

func test_exposes_the_passes_underneath() -> void:
	var underground := _underground_for(GenerationFixtures.WORLD_TYPED,
			BiomeCatalog.load_default(), BlockSet.load_default())
	assert_not_null(underground.carving())
	assert_not_null(underground.subsurface())
