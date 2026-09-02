class_name BiomeClassifier
extends RefCounted
## Which biome a world column belongs to (backlog brick 066).
##
## The first field in Phase D whose answer is an **id** rather than a number, and the
## first consumer of both climate axes at once. It says one thing per column — the stable
## ID of the biome that column is in — and it says nothing about what that biome *is*:
## which blocks it puts on the ground, what grows on it and what walks around on it are
## brick 067's catalog and 068–073's per-biome content.
##
## ```gdscript
## var biomes := BiomeClassifier.for_world(GenerationHash.for_world(world_seed))
## var id := biomes.at(column)       # e.g. "biome.forest"
## ```
##
## ## The partition
##
## Three inputs, five thresholds, six ids, and a **decision list**: the first rule that
## matches wins, and the last one matches everything, so the classifier is total by
## construction rather than by a range check.
##
## | # | Rule | Id |
## |---|---|---|
## | 1 | `ruggedness >= RUGGEDNESS_MOUNTAIN` | `biome.mountain` |
## | 2 | `temperature < TEMPERATURE_COLD` | `biome.snow` |
## | 3 | `humidity < HUMIDITY_ARID` | `biome.desert` |
## | 4 | `humidity >= HUMIDITY_WETLAND` | `biome.wetland` |
## | 5 | `humidity >= HUMIDITY_WOODED` | `biome.forest` |
## | 6 | — | `biome.grassland` |
##
## The **order** carries as much of the design as the numbers do, and two places in it are
## deliberate:
##
## - **Relief outranks climate.** A column rugged enough to be a mountain is a mountain in
##   any weather, because that is the one input a player can see from a distance. A hot
##   mountain and a cold one are 072's problem and 067 can still split the id; a mountain
##   classified as a swamp because it happens to be wet is a bug you can walk into.
## - **Cold outranks dry and wet.** Cold-and-dry is tundra and cold-and-wet is taiga; with
##   six baseline biomes and one of them named `snow`, both of those are the snow biome.
##   Putting the cold test above the humidity tests is what says so, rather than three
##   extra thresholds saying it less clearly.
##
## ## Where the numbers come from
##
## None of the five thresholds was fitted to make the six shares come out even, and the
## measurement is the interesting part: they still do (`docs/world-generation.md` §11.4).
## Over the climate-scale sweep on 12 seeds every biome holds between **14.3% and 21.0%**
## of the world against an even 16.7%. That falls out of the fields rather than out of
## tuning — `spread()` leaves each climate axis with about a quarter of the world below
## `0.2` and a quarter above `0.8` (§10.2), so `0.2 / 0.5 / 0.8` cuts an axis into four
## near-equal parts.
##
## | Threshold | Anchor |
## |---|---|
## | `TEMPERATURE_COLD`, `HUMIDITY_ARID`, `HUMIDITY_WETLAND` | the **reference's own literals**: the original reads climate on a bare `[0, 1]` scale against `< 0.2` and `> 0.8` (`docs/reference/terrain-climate-blend.md` claim 5) |
## | `HUMIDITY_WOODED` | the field's own middle, `ElevationField.SHORE_MIDPOINT`'s neutral choice |
## | `RUGGEDNESS_MOUNTAIN` | derived: the ruggedness at which `ErosionPass.ruggedness_weight()` reaches the middle of *its* range, i.e. where a column starts keeping more than half its relief amplitude |
##
## ## What it deliberately does not read
##
## - **`Continentalness`, and so coastal wetness.** Brick 065 left a coastal-wetness term
##   to 066 or 074 on the condition that it be visible rather than baked into the humidity
##   axis (`docs/world-generation.md` §10.1). 066 declines it too, for a reason of its own:
##   a coast is a place you can only see once there is water in it, and the waterline is
##   brick 080. A `biome.coast` drawn on continentalness alone would put a biome boundary
##   where nothing on the ground changes. §11.6.
## - **Ground height, and so sea level.** Same argument, same brick. `ErosionPass` is held
##   for its ruggedness layer, not for `at()`.
## - **Anything that is not a pure function of `(seed, column)`.** Server and client both
##   classify, and neither sends the result
##   (`docs/reference/world-generation-authority.md`).
##
## Thresholds are pinned constants rather than arguments, for the reason `Continentalness`
## gives: they are part of every world made with them, so changing one is a generation
## version bump (`docs/world-generation.md` §2.1), not a tuning knob.
##
## Contract: `docs/world-generation.md` §11. Reference:
## `docs/reference/terrain-climate-blend.md` claim 5.

# ---------------------------------------------------------------------------
# The ids
# ---------------------------------------------------------------------------
#
# Stable IDs under the `biome` domain (`core/ids/stable_id.gd`, `CLAUDE.md` §9), because
# a biome id ends up in a save file and in a debug log. Brick 067 keys its catalog on
# exactly these strings; 068–073 fill one each. The set is closed here rather than in the
# catalog so that `classify()` can be total — a classifier that could answer with an id
# the catalog has never heard of has no useful failure mode.

const GRASSLAND := "biome.grassland"
const FOREST := "biome.forest"
const DESERT := "biome.desert"
const SNOW := "biome.snow"
const MOUNTAIN := "biome.mountain"

## The wet biome — swamp, marsh, bog. Named for the climate rather than for water, because
## nothing here knows where the water is: brick 080 places the waterline, and an *aquatic*
## biome (open sea, lake bed) is a height decision that belongs with it.
const WETLAND := "biome.wetland"

## Every id `at()` can return, in the order the rules below test for them. Fixed: a
## consumer may index into it, and 067's catalog is expected to cover exactly this set.
const IDS: PackedStringArray = [MOUNTAIN, SNOW, DESERT, WETLAND, FOREST, GRASSLAND]

# ---------------------------------------------------------------------------
# The thresholds
# ---------------------------------------------------------------------------

## Ruggedness at or above which a column is `MOUNTAIN`, on `ErosionPass`' **raw** `[0, 1]`
## ruggedness layer: `1 / sqrt(2)`.
##
## Derived rather than picked. `ErosionPass.ruggedness_weight(r)` is
## `RUGGEDNESS_FLOOR + (1 - RUGGEDNESS_FLOOR) * r²` — how much of its 128-voxel relief
## amplitude a column is allowed to keep — and the middle of that weight's own range sits
## at `r² = 0.5`. So the rule reads "a column that keeps more than half the relief in the
## world is a mountain", which is a statement about terrain a player walks on rather than
## about a noise value, and it moves with `ErosionPass` if that pass is ever retuned.
## `test_the_mountain_threshold_is_where_relief_starts_winning` asserts the identity.
##
## The raw layer, not `ruggedness_at()`: squaring is monotone, so both give the same
## partition, and reading the raw field keeps the threshold on the scale the number is
## quoted on. Measured share: 14.3% – 16.2% of the world (`docs/world-generation.md` §11.4).
const RUGGEDNESS_MOUNTAIN := 0.7071067811865476

## Temperature below which a column is `SNOW`.
##
## The reference's own literal. `terrain-climate-blend.md` claim 5 reads the original
## consuming climate on a bare `[0, 1]` scale against `< 0.2` and `> 0.8`; we cannot reuse
## its climate *mechanism* (`docs/world-generation.md` §9.3), but the scale it reads the
## result on is exactly ours, and its idea of "cold" is the one piece of its classification
## that survived the read.
const TEMPERATURE_COLD := 0.2

## Humidity at or above which a column is `WETLAND`. The reference's other literal
## (claim 5: humidity `> 0.8` gates a second lookup in `World_generateRegionSite`).
const HUMIDITY_WETLAND := 0.8

## Humidity below which a column is `DESERT` (unless it is colder than `TEMPERATURE_COLD`,
## which is tested first).
##
## `1 - HUMIDITY_WETLAND`: the dry mirror of the same reference literal, so the two ends of
## the humidity axis are cut symmetrically. Written as the subtraction rather than as
## `0.2` so the symmetry cannot be broken by editing one of the two, and
## `test_the_dry_and_wet_cuts_are_symmetric` asserts what that buys.
const HUMIDITY_ARID := 1.0 - HUMIDITY_WETLAND

## Humidity at or above which an otherwise ordinary column is `FOREST` rather than
## `GRASSLAND`.
##
## The field's own middle, and the only threshold here with no reference anchor. The
## neutral choice, for the reason `ElevationField.SHORE_MIDPOINT` is 0.5: how much of the
## world is wooded is a consequence of the humidity field's measured distribution, not a
## number pre-baked to hit a target. `HumidityField` is centred on `0.5` by construction —
## `spread()` fixes it (`docs/world-generation.md` §10.2) — so this cuts the temperate
## band in half.
const HUMIDITY_WOODED := 0.5

var _temperature: TemperatureField
var _humidity: HumidityField
var _erosion: ErosionPass


func _init(p_temperature: TemperatureField, p_humidity: HumidityField,
		p_erosion: ErosionPass) -> void:
	_temperature = p_temperature
	_humidity = p_humidity
	_erosion = p_erosion


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds the classifier to one world, or returns null (logged) when the binding is missing
## or any field under it cannot be built. **The supported entry point.**
##
## Takes a `GenerationHash` for `Continentalness.for_world()`'s reason: the hash is where a
## world this build cannot reproduce is already refused (`docs/world-generation.md` §3.2).
static func for_world(p_hash: GenerationHash) -> BiomeClassifier:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build the biome classifier without a world binding"):
		return null
	var temperature := TemperatureField.for_world(p_hash)
	if temperature == null:
		return null
	var humidity := HumidityField.for_world(p_hash)
	if humidity == null:
		return null
	var erosion := ErosionPass.for_world(p_hash)
	if erosion == null:
		return null
	return BiomeClassifier.new(temperature, humidity, erosion)


# ---------------------------------------------------------------------------
# Classification
# ---------------------------------------------------------------------------

## The biome id of a world column — one of `IDS`, always.
func at(column: Vector2i) -> String:
	return classify(_temperature.at(column), _humidity.at(column),
			_erosion.ruggedness_noise_at(column))


## The same answer, asked at a voxel. Y is dropped, exactly as the climate fields drop it:
## a biome is a property of the column, and a cave is under the same weather — and for now
## in the same biome — as the grass above it. Brick 077's caves may want to say otherwise;
## they will do it by reading this and deciding differently, not by making it 3D.
func at_voxel(voxel: Vector3i) -> String:
	return at(GenerationGrid.voxel_to_column(voxel))


## The three inputs behind `at()`, as `(temperature, humidity, ruggedness)` — for a debug
## probe that wants to know *why* a column classified the way it did, and for brick 074,
## which needs the distance to a threshold rather than the side of it.
func sample_at(column: Vector2i) -> Vector3:
	return Vector3(_temperature.at(column), _humidity.at(column),
			_erosion.ruggedness_noise_at(column))


## The partition itself: three `[0, 1]` inputs to one id, with no world attached.
##
## Static and pure, for `ErosionPass.ruggedness_weight()`'s reason — the rules are part of
## the world's definition, and asserting them exhaustively over the unit cube is worth
## doing without hunting for a column that happens to sit in each of six biomes. It is also
## what makes the totality claim checkable: there is no input this does not answer.
static func classify(temperature: float, humidity: float, ruggedness: float) -> String:
	if ruggedness >= RUGGEDNESS_MOUNTAIN:
		return MOUNTAIN
	if temperature < TEMPERATURE_COLD:
		return SNOW
	if humidity < HUMIDITY_ARID:
		return DESERT
	if humidity >= HUMIDITY_WETLAND:
		return WETLAND
	if humidity >= HUMIDITY_WOODED:
		return FOREST
	return GRASSLAND


## True when `id` is one this classifier can produce. Brick 067's catalog validates
## against it; a debug command that takes a biome name rejects a typo with it.
static func is_biome_id(id: String) -> bool:
	return IDS.has(id)


# ---------------------------------------------------------------------------
# Shape of the classifier
# ---------------------------------------------------------------------------

## The fields underneath, for a debug probe or a pass that wants the numbers rather than
## the id. Read-only by convention: none of the three holds mutable state.
##
## Suffixed, where `ErosionPass.elevation()` and `TerracePass.erosion()` are not: in this
## file `temperature` and `humidity` are the names of `classify()`'s **values**, and an
## accessor sharing a name with a parameter is a shadowing warning here and a confusing
## read everywhere.
func temperature_field() -> TemperatureField:
	return _temperature


func humidity_field() -> HumidityField:
	return _humidity


## Held for its **ruggedness layer**, not for its height: this classifier never asks where
## the ground is (`docs/world-generation.md` §11.6). Brick 072 will.
func erosion_pass() -> ErosionPass:
	return _erosion


## The narrowest a purely climatic biome band can be, in voxels.
##
## Derived, not measured: both climate axes state their own
## `minimum_climate_span_voxels()` — the shortest distance over which either could cross
## its *whole* range — and the closest two cuts on one axis are `HUMIDITY_WOODED` and
## either humidity neighbour, `0.3` apart. A floor on band width, not a promise about what
## the map looks like: the mountain rule is on a much finer field, so a mountain edge can
## and does cut a climate band into shorter pieces (`docs/world-generation.md` §11.5).
func minimum_climate_band_voxels() -> float:
	return minf(_temperature.minimum_climate_span_voxels(),
			_humidity.minimum_climate_span_voxels()) * narrowest_climate_gap()


## The smallest gap between two cuts on one climate axis, in field units. Temperature has a
## single cut, so the humidity axis is what sets it.
static func narrowest_climate_gap() -> float:
	return minf(HUMIDITY_WOODED - HUMIDITY_ARID, HUMIDITY_WETLAND - HUMIDITY_WOODED)


## Empty string when the partition is coherent, otherwise the reason.
##
## Same shape and same purpose as `GenerationVersion.self_check()` and
## `GenerationFixtures.self_check()`: a threshold table that has quietly drifted — two ids
## colliding, the humidity cuts out of order, the mountain rule detached from the pass it
## was derived from — makes every biome in the world wrong while every individual test
## still passes.
static func self_check() -> String:
	if IDS.size() != 6:
		return "expected 6 biome ids, found %d" % IDS.size()
	var seen: Dictionary = {}
	for id in IDS:
		if seen.has(id):
			return "biome id '%s' is listed twice" % id
		seen[id] = true
		var invalid := StableId.validate(id)
		if not invalid.is_empty():
			return "biome id '%s' is not a stable id: %s" % [id, invalid]
		if StableId.domain_of(id) != "biome":
			return "biome id '%s' is not in the 'biome' domain" % id
	if not (HUMIDITY_ARID < HUMIDITY_WOODED and HUMIDITY_WOODED < HUMIDITY_WETLAND):
		return "the humidity cuts are out of order: %s, %s, %s" % [
				HUMIDITY_ARID, HUMIDITY_WOODED, HUMIDITY_WETLAND]
	if not is_equal_approx(HUMIDITY_ARID + HUMIDITY_WETLAND, 1.0):
		return "the dry and wet cuts are not symmetric: %s + %s" % [
				HUMIDITY_ARID, HUMIDITY_WETLAND]
	var mountain_weight := ErosionPass.ruggedness_weight(RUGGEDNESS_MOUNTAIN)
	var midpoint := (ErosionPass.RUGGEDNESS_FLOOR + 1.0) * 0.5
	if absf(mountain_weight - midpoint) > 1e-12:
		return ("the mountain threshold %s no longer sits at the middle of the "
				+ "ruggedness weight (%s, expected %s)") % [
						RUGGEDNESS_MOUNTAIN, mountain_weight, midpoint]
	return ""
