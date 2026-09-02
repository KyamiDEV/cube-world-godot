class_name LakePass
extends RefCounted
## Where a lake basin locally lowers the terraced ground (backlog brick 082).
##
## `RiverPass` (081) named this brick in advance, twice: its own class comment ("082's lakes
## are free to threshold the ordinary way, on the raw value, and get blobs instead") and its
## `channel_noise()` accessor ("for a debug probe or a later brick (082's lakes) that wants
## the same noise field thresholded a different way"). This is that different threshold: the
## same channel layer `RiverPass` already builds, read for the opposite property — far from
## its own zero contour instead of close to it — which turns the winding band a river needs
## into the blob a lake needs, with no second noise layer and no new salt.
##
## ```gdscript
## var lake := LakePass.for_world(GenerationHash.for_world(world_seed))
## var y := lake.surface_y(column)     # RiverPass's own surface, minus one riser inside a basin
## ```
##
## One clip, the same shape as `RiverPass`'s own (081) and `CaveCarving`'s before it (078):
##
## ```text
## is_lake_at(column)  = is_basin_at(column) and river.terrace().at(column) <= LAKE_CEILING_VOXELS
## surface_y(column)   = RiverPass.surface_y(column) - (CARVE_DEPTH_VOXELS if is_lake_at else 0)
## ```
##
## ## Composing over `RiverPass`, reusing its layer rather than building a second one
##
## `LakePass` holds a `RiverPass`, not a bare `TerracePass` and `ValueNoise` of its own.
## Three consequences follow from that one choice: (1) `channel_distance_at()` is read through
## `RiverPass`, so the exact same hashed corners a river was built from are what a lake reads
## too — a coherent field only has one shape, and building a second `ValueNoise.layer()` with
## identical parameters would compute that shape twice for no new information, the literal
## thing `WorldHash`'s one-salt-per-pass rule exists to avoid duplicating. (2) `surface_y()`
## carves on top of `RiverPass.surface_y()`, not `TerracePass.surface_y()` directly — see
## §21.1 for why that choice is safe. (3) a river and a lake can never both claim a column:
## `is_channel_at()` (081, `distance < 0.02`) and `is_basin_at()` (below, `distance >
## LAKE_MIN_DISTANCE = 0.85`) are disjoint by construction, asserted in `self_check()` rather
## than left as an accident of two numbers that happen not to overlap today.
##
## ## The mask is a threshold on the raw value, the opposite tail choice from a river's
##
## `RiverPass.channel_distance_at()` is small near the field's own most common value (the
## middle of the bell-shaped sum, §20.2) and a river reads *that* band, because a level set of
## a coherent field winds through space rather than pooling into one place. A lake wants the
## opposite: an interior region, not a boundary — so `LakePass` reads the same distance the
## opposite direction, asking whether a column sits *far* from the contour rather than close to
## it. Far from the mean is the field's own tail, which is rare by construction, the same
## reason `CaveMask.DENSITY_THRESHOLD` selects a minority of underground space rather than most
## of it (§16.4) — reused here for a 2D field instead of a 3D one.
##
## `LAKE_MIN_DISTANCE = 0.85` was measured, not guessed, the same restraint `CHANNEL_HALF_
## WIDTH` needed for the identical reason: the field's density is not uniform, so a
## round-looking number does not automatically select a round-looking fraction of the world.
## §21.3 has the sweep.
##
## ## The lowland ceiling and the carve depth are reused, not reinvented
##
## `LAKE_CEILING_VOXELS = RiverPass.RIVER_CEILING_VOXELS` (`ElevationField.LAND_BASE_VOXELS`)
## and `CARVE_DEPTH_VOXELS = TerracePass.TERRACE_HEIGHT_VOXELS` are the exact constants
## `RiverPass` already uses for the same jobs — a lake basin is no less bound to the
## continental-plain baseline than a river channel is, and a lake bed one riser below its
## shore is the same "smallest change that stays terrace-aligned" argument §20.5 already made,
## not a new number invented because the feature has a different name.
##
## No claim is made that a lake basin reaches `WaterLevel.SEA_LEVEL_VOXELS`, `RiverPass`'s own
## disclaimer (§20.5) applied here unchanged: whether it does depends on how low the
## surrounding lowland already sits. Nothing downstream of `TerracePass`/`RiverPass` reads
## `LakePass` yet — no wet material, no "is this column underwater" — that wiring belongs to
## 083/084, `CaveCarving`'s own precedent for the brick after the one that draws the shape.
##
## ## Reference
##
## A case-insensitive grep of `reference/CubeWorld-Reversal` for "lake" turns up exactly one
## kind of hit: the wide string literal `L"Lake"` in the same chunk-label name-to-id map
## `CaveMask`'s own reference search already found `L"Cave"` in (`World.cpp`, alongside
## `L"Village"`, `L"Mountain"`, `L"Forest"`, `L"Canyon"` — a landmark/POI label list, not a
## generation mechanism, §16.5's exact finding repeated for a different label in the same
## table). There is nothing here to diverge from.
##
## Contract: `docs/world-generation.md` §21.

# ---------------------------------------------------------------------------
# The basin mask
# ---------------------------------------------------------------------------

## How far from the channel layer's own zero contour counts as "in a lake basin", in the same
## units `RiverPass.channel_distance_at()` already returns — a fraction of `[-1, 1]`'s
## magnitude, `[0, 1]`. The opposite tail from `RiverPass.CHANNEL_HALF_WIDTH`: small near the
## contour is a river, large away from it is a lake. Measured, not guessed — see the class
## comment and `docs/world-generation.md` §21.3.
const LAKE_MIN_DISTANCE := 0.85

## Only a column whose terraced height is at or below this counts as lowland enough to carry a
## basin. `RiverPass.RIVER_CEILING_VOXELS` (itself `ElevationField.LAND_BASE_VOXELS`) — reused,
## not a new number, the same continental-plain baseline every other vertical anchor in this
## project is measured against.
const LAKE_CEILING_VOXELS := RiverPass.RIVER_CEILING_VOXELS

## How many voxels the clip removes where it applies: exactly one riser, `RiverPass.
## CARVE_DEPTH_VOXELS`'s own value, so `surface_y()` stays an exact terrace plane on both sides
## of a basin edge.
const CARVE_DEPTH_VOXELS := TerracePass.TERRACE_HEIGHT_VOXELS

var _river: RiverPass


func _init(p_river: RiverPass) -> void:
	_river = p_river


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds the pass to one world, or returns null (logged) when the binding is missing or a
## layer underneath it cannot be built. **The supported entry point.**
##
## Builds its own `RiverPass`, `RiverPass.for_world()`'s own reason repeated at this layer
## too: the object is stateless and small, and a shared instance would be a second way for two
## passes to disagree about which world they are generating.
static func for_world(p_hash: GenerationHash) -> LakePass:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build the lake pass without a world binding"):
		return null
	var bound_river := RiverPass.for_world(p_hash)
	if bound_river == null:
		return null
	return LakePass.new(bound_river)


# ---------------------------------------------------------------------------
# The clip
# ---------------------------------------------------------------------------

## True where the basin mask covers this column **and** the ground is lowland enough to carry
## it. The mask is checked first: it costs one absolute value on an already-built noise
## sample, where the ceiling check costs the whole chain underneath `TerracePass` — `RiverPass.
## is_river_at()`'s own ordering argument (§20.3), unchanged here because the cost shape is
## identical.
func is_lake_at(column: Vector2i) -> bool:
	if not is_basin_at(column):
		return false
	return _river.terrace().at(column) <= LAKE_CEILING_VOXELS


## True where the column sits at least `LAKE_MIN_DISTANCE` from the channel layer's own zero
## contour — the geographic shape alone, with no lowland gate applied. `RiverPass.
## is_channel_at()`'s own reason for existing separately from `is_river_at()`, mirrored here.
func is_basin_at(column: Vector2i) -> bool:
	return channel_distance_at(column) > LAKE_MIN_DISTANCE


## The same distance `RiverPass.channel_distance_at()` already computes, read through the
## `RiverPass` this pass holds rather than rebuilt from a second `ValueNoise` layer.
func channel_distance_at(column: Vector2i) -> float:
	return _river.channel_distance_at(column)


## Height of the ground at a world column, in voxels above the datum, after the lake clip.
## Always an exact multiple of `TerracePass.TERRACE_HEIGHT_VOXELS` — `RiverPass.at()` is, and
## this only ever subtracts a whole `CARVE_DEPTH_VOXELS` from it.
func at(column: Vector2i) -> float:
	return float(surface_y(column))


## The same height as an integer voxel plane. Composes over `RiverPass.surface_y()`, not
## `TerracePass.surface_y()` directly — see the class comment's "Composing over `RiverPass`"
## section for why that is safe: a river and a lake column are disjoint by construction, so a
## column this clip carves was never touched by `RiverPass`'s own clip to begin with.
func surface_y(column: Vector2i) -> int:
	var base := _river.surface_y(column)
	if is_lake_at(column):
		return base - CARVE_DEPTH_VOXELS
	return base


## The same height as a voxel: Y is dropped, exactly as `RiverPass.at_voxel()` drops it.
func at_voxel(voxel: Vector3i) -> float:
	return at(GenerationGrid.voxel_to_column(voxel))


## The same height in metres, for a log line, a design note or a debug overlay. Never for
## generation arithmetic — that stays in voxels, where the numbers are exact.
func at_metres(column: Vector2i) -> float:
	return WorldScale.voxels_to_metres(at(column))


# ---------------------------------------------------------------------------
# Shape of the pass
# ---------------------------------------------------------------------------

## The pass underneath, for a consumer that wants the river-clipped surface directly, or its
## own `channel_noise()`/`terrace()` accessors one layer further down. Read-only by
## convention: neither object this file holds is mutable.
func river() -> RiverPass:
	return _river


## The tallest vertical face two columns one voxel apart can present, in voxels: `RiverPass.
## max_riser_voxels()` plus one more riser for the basin edge itself, which this pass can
## introduce where a lake column sits beside a dry one — `RiverPass.max_riser_voxels()`'s own
## reasoning, one layer up.
func max_riser_voxels() -> float:
	return _river.max_riser_voxels() + float(CARVE_DEPTH_VOXELS)


# ---------------------------------------------------------------------------
# Self-check
# ---------------------------------------------------------------------------

## Empty string when the constants above still hold the relationships the class comment
## claims, otherwise the reason. Same shape and purpose as `RiverPass.self_check()`: the
## relationship is claimed in the comment and asserted here rather than trusted from it.
static func self_check() -> String:
	if LAKE_MIN_DISTANCE <= RiverPass.CHANNEL_HALF_WIDTH or LAKE_MIN_DISTANCE >= 1.0:
		return ("LAKE_MIN_DISTANCE (%s) must sit strictly between CHANNEL_HALF_WIDTH (%s) and "
				+ "1.0, or a lake and a river could claim the same column") % [
						LAKE_MIN_DISTANCE, RiverPass.CHANNEL_HALF_WIDTH]
	if int(LAKE_CEILING_VOXELS) % TerracePass.TERRACE_HEIGHT_VOXELS != 0:
		return "LAKE_CEILING_VOXELS (%s) is not an exact multiple of TERRACE_HEIGHT_VOXELS (%d)" % [
				LAKE_CEILING_VOXELS, TerracePass.TERRACE_HEIGHT_VOXELS]
	if LAKE_CEILING_VOXELS < TerracePass.MINIMUM_VOXELS or LAKE_CEILING_VOXELS > TerracePass.MAXIMUM_VOXELS:
		return "LAKE_CEILING_VOXELS (%s) is outside TerracePass's own range [%s, %s]" % [
				LAKE_CEILING_VOXELS, TerracePass.MINIMUM_VOXELS, TerracePass.MAXIMUM_VOXELS]
	if LAKE_CEILING_VOXELS != RiverPass.RIVER_CEILING_VOXELS:
		return "LAKE_CEILING_VOXELS (%s) has drifted from RiverPass.RIVER_CEILING_VOXELS (%s)" % [
				LAKE_CEILING_VOXELS, RiverPass.RIVER_CEILING_VOXELS]
	return ""
