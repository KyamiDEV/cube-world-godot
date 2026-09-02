extends TestCase
## Covers world/biomes/biome_definition.gd (brick 067).


func _valid() -> BiomeDefinition:
	var definition := BiomeDefinition.new()
	definition.id = "biome.grassland"
	definition.display_name = "Grassland"
	definition.debug_color = Color8(106, 170, 74)
	return definition


func test_a_well_formed_definition_validates() -> void:
	var definition := _valid()
	assert_eq(definition.validate(), "")
	assert_true(definition.is_valid())


func test_a_fresh_definition_does_not_validate() -> void:
	# The default resource must never pass: an unfilled record reaching the catalog is
	# exactly the failure `validate()` exists to stop, and `id` is what is missing first.
	var definition := BiomeDefinition.new()
	assert_ne(definition.validate(), "")
	assert_false(definition.is_valid())


func test_the_id_must_be_a_stable_id() -> void:
	for bad in ["", "Biome.Grassland", "biome", "biome..grassland", "biome.9grass"]:
		var definition := _valid()
		definition.id = bad
		assert_ne(definition.validate(), "", "'%s' must be rejected" % bad)


func test_the_id_must_be_in_the_biome_domain() -> void:
	var definition := _valid()
	definition.id = "block.grass"
	var problem := definition.validate()
	assert_ne(problem, "")
	assert_true(problem.contains("'biome' domain"), problem)


func test_the_display_name_is_required() -> void:
	var definition := _valid()
	definition.display_name = ""
	assert_ne(definition.validate(), "")


func test_the_debug_color_must_be_opaque() -> void:
	# A translucent swatch on an overlay reads as a blend of two biomes, which is the one
	# thing a debug colour must never be able to look like.
	var definition := _valid()
	definition.debug_color = Color(0.4, 0.7, 0.3, 0.5)
	var problem := definition.validate()
	assert_ne(problem, "")
	assert_true(problem.contains("opaque"), problem)


func test_the_schema_does_not_know_the_partition() -> void:
	# Deliberate: `BiomeDefinition` validates grammar and domain only. Whether an id is one
	# `BiomeClassifier` can produce is `BiomeRegistry`'s check, so the record shape stays
	# usable for a biome the classifier has not learned yet (080's aquatic biome, say).
	var definition := _valid()
	definition.id = "biome.coast"
	assert_false(BiomeClassifier.is_biome_id(definition.id))
	assert_eq(definition.validate(), "")
