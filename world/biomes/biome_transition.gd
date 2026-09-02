class_name BiomeTransition
extends RefCounted
## How close a column sits to a different biome, and which one (backlog brick 074).
##
## `BiomeClassifier` (066) already says its own reason for this file: `sample_at()` exists
## "for brick 074, which needs the distance to a threshold rather than the side of it." This
## is that consumer — a second, presentation-facing question over the same three inputs, for
## 075's material blend and Phase J's terrain tint. It never answers *which* biome a column
## is in; `BiomeClassifier.at()` stays the only source of truth for that.
##
## ```gdscript
## var transition := BiomeTransition.for_world(GenerationHash.for_world(world_seed))
## var neighbor := transition.neighbor_at(column)         # "" or a second biome id
## var weight := transition.neighbor_weight_at(column)    # [0, 0.5], 0 away from any edge
## ```
##
## ## The neighbor: asking the real function, not re-deriving it
##
## `classify()` is a decision list, not five independent range checks (§11.3), so "the
## nearest threshold" is not always the nearest *relevant* one — flipping a threshold a
## short-circuited rule never reaches changes nothing. Rather than re-encoding the decision
## list's precedence a second time, `nearest_boundary()` nudges one input at a time to just
## the other side of each of the five thresholds and asks `BiomeClassifier.classify()` again.
## A nudge that leaves the answer unchanged is not a boundary this column is near, in the
## only sense that matters here; a nudge that changes it is exactly the neighbor 075 needs,
## found without hand-coding which rule dominates which. The smallest such distance, across
## all five thresholds, wins.
##
## ## The blend width
##
## `TRANSITION_WIDTH = 0.15`, half of `BiomeClassifier.narrowest_climate_gap()` (`0.3`, the
## humidity axis's tightest cut spacing, §11.2) — half, not the whole gap, for the "coarser
## than what it weights" reason a weight field owes the thing it modulates (§7.3): a column
## exactly centred in the *narrowest possible* climate band blends fully into each neighbor
## right at that band's own edges and the two blend zones meet, at zero, at the band's
## midpoint, rather than overlapping into a three-way mix nothing asked for. Wider bands have
## slack; this is a floor on the blend, not a promise about every band's width — the same
## honesty §11.5 already states about the boundaries themselves.
##
## One constant for all five thresholds, including the ruggedness cut, which is an honest
## simplification rather than an exact one: temperature and humidity share a measured scale
## (`spread()`, §9.4/§10.2) that the ruggedness cut does not — it is a single threshold
## against a ceiling, not a gap between two cuts on its own axis (§11.2). Reusing the climate
## width is the least invented number available, not a measured property of the ruggedness
## layer. If the mountain edge ever needs its own width, that is 072's or 085's call to make,
## not a reason to invent a second constant here for a case nothing yet reads.
##
## ## Not a generation version bump
##
## §12.6's argument, unchanged. Nothing here is generation: no hash, no salt, no noise layer,
## no new field. `BiomeClassifier.at()` is untouched and still asserted at its pinned
## signature; this reads the same three inputs a second way and never feeds its answer back
## into anything that decides where a voxel goes.
##
## ## Reference
##
## None. §12.5 already found the original's biome is a *continuous colour* —
## `Terrain_computeBiomeColor` blends temperature/humidity/height straight into RGBA with no
## discrete id anywhere — so there is no boundary-blending mechanism to diverge from, only
## the same "continuous under the hood" property arrived at from the opposite direction: a
## discrete id for everything that needs one (saves, quests, logs, §12.5), and a blend weight
## for the one thing here that reads like the original — a tint that does not jump.
##
## Contract: `docs/world-generation.md` §13.

## Half of `BiomeClassifier.narrowest_climate_gap()`. See the class comment. Not computed as
## a const expression — a call is not one (`generate_biome_catalog.gd`'s reason, brick 067) —
## so the derivation is asserted at runtime, in `self_check()` and in the test file, rather
## than trusted from a comment.
const TRANSITION_WIDTH := 0.15

## The nudge used to find "just below" a high threshold or "just above" a low one. GDScript
## has no exact floating-point predecessor operator, and every value `classify()` compares is
## in `[0, 1]`, so a fixed epsilon far below the field's own step size flips a `>=`/`<` test
## without landing on a second threshold by accident.
const FLIP_EPSILON := 1e-9

var _classifier: BiomeClassifier


func _init(p_classifier: BiomeClassifier) -> void:
	_classifier = p_classifier


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds the transition to one world, or returns null (logged) when the binding is missing
## or the classifier underneath it cannot be built. **The supported entry point.**
static func for_world(p_hash: GenerationHash) -> BiomeTransition:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build the biome transition without a world binding"):
		return null
	var biomes := BiomeClassifier.for_world(p_hash)
	if biomes == null:
		return null
	return BiomeTransition.new(biomes)


# ---------------------------------------------------------------------------
# Blending
# ---------------------------------------------------------------------------

## The second biome id blending in at `column`, or `""` when the column sits farther than
## `TRANSITION_WIDTH` from every threshold. Never `_classifier.at(column)` itself.
func neighbor_at(column: Vector2i) -> String:
	var sample := _classifier.sample_at(column)
	var boundary := nearest_boundary(sample.x, sample.y, sample.z)
	if boundary.is_empty() or boundary["distance"] >= TRANSITION_WIDTH:
		return ""
	return boundary["neighbor"]


## How much of `neighbor_at(column)` mixes in, in `[0, 0.5]` — `0` away from every edge
## (`neighbor_at()` is `""` there too), `0.5` exactly on a boundary, symmetric on both sides
## of every cut. Reuses `ValueNoise.fade()`, the project's one blending curve (§5.3), rather
## than a second `C¹`-only ramp with its own slope discontinuity to keep in step.
func neighbor_weight_at(column: Vector2i) -> float:
	var sample := _classifier.sample_at(column)
	var boundary := nearest_boundary(sample.x, sample.y, sample.z)
	if boundary.is_empty():
		return 0.0
	return _weight_for_distance(boundary["distance"])


## The primary id, the neighbor (or `""`), and the neighbor's weight, in one call — for 075's
## material blend and Phase J's tint, which want all three without sampling the classifier
## and re-probing the five thresholds twice over the way calling `neighbor_at()` and
## `neighbor_weight_at()` separately would (`ErosionPass.at()`'s reason, §7.1).
func blend_at(column: Vector2i) -> Dictionary:
	var sample := _classifier.sample_at(column)
	var primary := BiomeClassifier.classify(sample.x, sample.y, sample.z)
	var boundary := nearest_boundary(sample.x, sample.y, sample.z)
	if boundary.is_empty():
		return {"primary": primary, "neighbor": "", "neighbor_weight": 0.0}
	var weight: float = _weight_for_distance(boundary["distance"])
	var neighbor: String = boundary["neighbor"] if weight > 0.0 else ""
	return {"primary": primary, "neighbor": neighbor, "neighbor_weight": weight}


## The same three, at a voxel: Y is dropped, exactly as `BiomeClassifier.at_voxel()` drops
## it — a transition is a property of the column, same as the biome itself.
func blend_at_voxel(voxel: Vector3i) -> Dictionary:
	return blend_at(GenerationGrid.voxel_to_column(voxel))


# ---------------------------------------------------------------------------
# The pure form: no world attached
# ---------------------------------------------------------------------------

## The closest single-threshold flip that changes `BiomeClassifier.classify()`'s answer, as
## `{"neighbor": id, "distance": field-unit distance}` — or an empty dictionary, which cannot
## happen for the five thresholds `classify()` actually has (`test_a_boundary_always_exists`
## covers it), but the function does not assume that rather than check it.
##
## Static and pure, `classify()`'s own reason: the boundary is part of the world's
## definition, worth asserting over the whole unit cube rather than hunted for at a handful
## of columns.
static func nearest_boundary(temperature: float, humidity: float,
		ruggedness: float) -> Dictionary:
	var primary := BiomeClassifier.classify(temperature, humidity, ruggedness)
	var best_distance := INF
	var best_neighbor := ""

	var r_flip := _flip_high(ruggedness, BiomeClassifier.RUGGEDNESS_MOUNTAIN)
	var r_candidate := BiomeClassifier.classify(temperature, humidity, r_flip)
	if r_candidate != primary:
		best_distance = absf(ruggedness - BiomeClassifier.RUGGEDNESS_MOUNTAIN)
		best_neighbor = r_candidate

	var t_flip := _flip_low(temperature, BiomeClassifier.TEMPERATURE_COLD)
	var t_candidate := BiomeClassifier.classify(t_flip, humidity, ruggedness)
	if t_candidate != primary:
		var t_distance := absf(temperature - BiomeClassifier.TEMPERATURE_COLD)
		if t_distance < best_distance:
			best_distance = t_distance
			best_neighbor = t_candidate

	var arid_flip := _flip_low(humidity, BiomeClassifier.HUMIDITY_ARID)
	var arid_candidate := BiomeClassifier.classify(temperature, arid_flip, ruggedness)
	if arid_candidate != primary:
		var arid_distance := absf(humidity - BiomeClassifier.HUMIDITY_ARID)
		if arid_distance < best_distance:
			best_distance = arid_distance
			best_neighbor = arid_candidate

	var wetland_flip := _flip_high(humidity, BiomeClassifier.HUMIDITY_WETLAND)
	var wetland_candidate := BiomeClassifier.classify(temperature, wetland_flip, ruggedness)
	if wetland_candidate != primary:
		var wetland_distance := absf(humidity - BiomeClassifier.HUMIDITY_WETLAND)
		if wetland_distance < best_distance:
			best_distance = wetland_distance
			best_neighbor = wetland_candidate

	var wooded_flip := _flip_high(humidity, BiomeClassifier.HUMIDITY_WOODED)
	var wooded_candidate := BiomeClassifier.classify(temperature, wooded_flip, ruggedness)
	if wooded_candidate != primary:
		var wooded_distance := absf(humidity - BiomeClassifier.HUMIDITY_WOODED)
		if wooded_distance < best_distance:
			best_distance = wooded_distance
			best_neighbor = wooded_candidate

	if best_neighbor.is_empty():
		return {}
	return {"neighbor": best_neighbor, "distance": best_distance}


## The value just on the far side of a **low** cut (`value < threshold` triggers the rule):
## exactly `threshold` when `value` is currently on the triggering side (`threshold` itself
## already fails `<`), otherwise a hair below `threshold`.
static func _flip_low(value: float, threshold: float) -> float:
	return threshold if value < threshold else threshold - FLIP_EPSILON


## The mirror for a **high** cut (`value >= threshold` triggers the rule).
static func _flip_high(value: float, threshold: float) -> float:
	return threshold - FLIP_EPSILON if value >= threshold else threshold


## The neighbor weight for a boundary `distance` away, in `[0, 0.5]`: `0.5` at `distance =
## 0`, fading to `0.0` at `distance = TRANSITION_WIDTH` and beyond. `ValueNoise.fade()` is
## the project's one blending curve (§5.3) — reused rather than a second `C¹`-only ramp with
## its own slope discontinuity to keep in step with `FADE_MAX_SLOPE`.
static func _weight_for_distance(distance: float) -> float:
	if distance >= TRANSITION_WIDTH:
		return 0.0
	var t := distance / TRANSITION_WIDTH
	return 0.5 * (1.0 - ValueNoise.fade(t))


# ---------------------------------------------------------------------------
# Shape of the transition
# ---------------------------------------------------------------------------

## The classifier underneath, for a debug probe or a consumer that also wants the plain id.
## Read-only by convention: it holds no mutable state.
func classifier() -> BiomeClassifier:
	return _classifier


## Empty string when `TRANSITION_WIDTH` still is what the class comment says it is,
## otherwise the reason. Same shape and purpose as `BiomeClassifier.self_check()`: the
## derivation cannot be a const expression (`generate_biome_catalog.gd`'s constraint), so it
## is a runtime check instead of a comment nobody re-verifies.
static func self_check() -> String:
	var expected := BiomeClassifier.narrowest_climate_gap() * 0.5
	if not is_equal_approx(TRANSITION_WIDTH, expected):
		return ("TRANSITION_WIDTH %s no longer matches half the narrowest climate gap "
				+ "(%s)") % [TRANSITION_WIDTH, expected]
	return ""
