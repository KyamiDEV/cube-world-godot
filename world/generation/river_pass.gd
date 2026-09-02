class_name RiverPass
extends RefCounted
## Where a river channel locally lowers the terraced ground (backlog brick 081).
##
## `TerracePass` (063) and `WaterLevel` (080) both said, in their own class comments, that a
## river is a *local* lowering of a column's own terrain — not something either of them has
## any business deciding (`TerracePass` shapes every column alike; `WaterLevel` only places a
## plane). This is that lowering: a winding channel mask, clipped to lowland ground, that pulls
## a column's already-terraced surface down by one riser where the two agree.
##
## ```gdscript
## var river := RiverPass.for_world(GenerationHash.for_world(world_seed))
## var y := river.surface_y(column)     # TerracePass's own plane, minus one riser in-channel
## ```
##
## One clip, the same shape as `CaveCarving`'s (078):
##
## ```text
## is_river_at(column) = is_channel_at(column) and TerracePass.at(column) <= RIVER_CEILING_VOXELS
## surface_y(column)   = TerracePass.surface_y(column) - (CARVE_DEPTH_VOXELS if is_river_at else 0)
## ```
##
## ## Composing over `TerracePass`, not underneath it
##
## `docs/world-generation.md` §8.8 flagged, in advance, that rivers "belong to §7.1's product,
## underneath [terracing]": shape the continuous height, then terrace it, because a flattening
## term applied *after* quantisation would produce heights that are not terrace planes, and
## every consumer of `surface_y()` would have to re-snap them. This brick takes that concern
## seriously and answers it a different way: the clip here only ever subtracts a **whole**
## `TerracePass.TERRACE_HEIGHT_VOXELS`, so `surface_y()` stays exactly terrace-aligned without
## needing to sit upstream of the quantisation at all. Going upstream would have meant
## reaching into `ErosionPass`'s own composition and rebuilding `TerracePass` on top of it —
## the one thing every Phase D brick since 074 has deliberately avoided, because it would
## re-pin every downstream signature (`SurfaceMaterial`, `SubsurfaceMaterial`, `CaveCarving`,
## `UndergroundMaterial`, `WaterLevel`) for a channel that is, by construction, a small
## fraction of the world. `RiverPass` reads `TerracePass`; it does not touch it, and nothing
## before this brick changes.
##
## One consequence worth stating plainly: nothing downstream of `TerracePass` — not
## `SurfaceMaterial`, not `WaterLevel` — reads `RiverPass` yet. A river carved here does not
## yet get a wet material or count as underwater; that wiring belongs to whichever of 082–084
## actually decides what fills a channel, the same way `CaveMask` (077) carved nothing on its
## own until `CaveCarving` (078) read it the very next brick.
##
## ## The channel is a distance from a noise contour, not a threshold on it
##
## `CaveMask` thresholds a 3D field's low tail (`density_at() < 0.25`) to get rare, blobby
## caverns. A river needs the opposite shape: a *thin, winding, connected* band rather than a
## blob, so this reads a coherent 2D layer's **signed** value and asks how close it sits to
## the layer's own zero contour — `ValueNoise.value()` is already `[-1, 1]`, so no remap is
## needed. A coherent field's level sets are winding curves in space (the same reason a
## topographic map's contour lines wind rather than blob), so thresholding *distance from a
## level* rather than the level itself is what turns a height field into a river network
## instead of a lake — 082's lakes are free to threshold the ordinary way, on the raw value,
## and get blobs instead.
##
## ## The lowland ceiling
##
## A channel mask alone would happily cut through a mountain peak, which is not what a river
## does. `RIVER_CEILING_VOXELS` gates the clip to columns whose terraced height is already at
## or below `ElevationField.LAND_BASE_VOXELS` — the continental-plain baseline every other
## vertical anchor in this project is measured against, not a new number invented for this
## brick. `is_river_at()` checks the mask first and the ceiling second: the mask is two
## octaves of 2D noise, and the ceiling costs the whole chain underneath `TerracePass`
## (`Continentalness`, `ElevationField`, `ErosionPass`), so the cheap half runs first and the
## expensive half only runs where it could still change the answer — `CaveCarving`'s own
## ordering argument (§17.2), with the cheap and expensive halves swapped because the cost is
## the other way around here.
##
## ## The carve is one riser, matching the world's own aesthetic
##
## Every existing riser in this world is already a sudden 4 m face — `TerracePass`'s whole
## point is that the ground is a staircase, not a ramp. A channel edge that drops one more
## riser is not a new kind of discontinuity; it is the same one the rest of the terrain
## already has. `CARVE_DEPTH_VOXELS = TerracePass.TERRACE_HEIGHT_VOXELS`, no more and no less
## — a real river bed a whole riser below its banks, not a scratch on the surface.
##
## No claim is made that a channel reaches `WaterLevel.SEA_LEVEL_VOXELS`: whether it does
## depends on how low the surrounding lowland already sits, exactly as a real river's bed
## depth relative to the sea depends on where it flows. Guaranteeing that would need either a
## flow network (explicitly out of scope, `docs/world-generation.md` §7.6's "a hydraulic or
## thermal erosion simulation... is a different brick's problem") or a second, deeper clip a
## later brick can add once it actually needs one.
##
## ## Reference
##
## `docs/reference/terrain-base-height-field.md` claim 6 names `World_riverClimateGate`
## (`min(gate · 4, 1)`, put through a cubic smoothstep and squared) as one of four post-passes
## that flatten relief toward its base — never carving below it — and rates the finding
## `MEDIUM` because the helper body itself was never read (out of scope for 061; belongs to
## this brick and was not opened here either, since the shape claim 6 already recorded — a
## gate built from a per-column noise sample, not a flow simulation — is exactly the
## behavioral hypothesis this brick's own channel-distance mask follows). The original's gate
## only ever softens relief; it never carves below a base the way this brick's clip does. That
## is a deliberate divergence, not an oversight: the original's river is a *material/relief*
## gate feeding the same additive-upward height field claim 2 describes, with no terracing
## afterward to keep aligned, where ours has to stay an exact multiple of `TERRACE_HEIGHT_
## VOXELS` for every consumer of `surface_y()` to keep working. Cutting a whole riser is the
## smallest change that stays terrace-aligned; softening relief the way the original does
## would not.
##
## Contract: `docs/world-generation.md` §20.

# ---------------------------------------------------------------------------
# The channel mask
# ---------------------------------------------------------------------------

## Cell edge of the coarsest channel octave, in voxels: 2048 m.
##
## Four times `ElevationField.RELIEF_CELL_SIZE_VOXELS` — a river system is a broader thing
## than a single hillside, the same "coarser than what it places" argument `ErosionPass.
## RUGGEDNESS_CELL_SIZE_VOXELS` makes for ruggedness (§7.3), applied here in the direction a
## winding, kilometres-long channel actually needs.
const CHANNEL_CELL_SIZE_VOXELS := ElevationField.RELIEF_CELL_SIZE_VOXELS * 4

## Layers of channel noise summed. Two, deliberately restrained: the channel is a contour of
## this field, and every extra octave roughens that contour's edge — a smooth, gently winding
## line reads as a river, a jagged one does not. The same restraint `CaveMask` names for
## staying a threshold rather than a domain-warped worm (§16.1) applied to a contour instead
## of a blob.
const CHANNEL_OCTAVES := 2

## Amplitude ratio between one channel octave and the next: the conventional half, matching
## every other layer in the project.
const CHANNEL_GAIN := 0.5

## How close to the layer's own zero contour counts as "in the channel", in the same units as
## `ValueNoise.value()` — i.e. a fraction of `[-1, 1]`. A round number is not available here
## the way `CaveMask.DENSITY_THRESHOLD` is a round quarter: the field's density concentrates
## at its own zero (the middle of a bell-shaped sum, not a tail), so the fraction of the world
## this selects is far more sensitive to the width than a tail threshold is, and was measured
## rather than guessed (`docs/world-generation.md` §20.4).
const CHANNEL_HALF_WIDTH := 0.02

## Only a column whose terraced height is at or below this counts as lowland enough to carry
## a channel. `ElevationField.LAND_BASE_VOXELS` — the continental-plain baseline, not a new
## number invented for this brick — so a mountain peak the channel mask happens to cross never
## reads as a river.
const RIVER_CEILING_VOXELS := ElevationField.LAND_BASE_VOXELS

## How many voxels the clip removes where it applies: exactly one riser, `TerracePass`'s own
## unit, so `surface_y()` stays an exact terrace plane on both sides of the channel edge.
const CARVE_DEPTH_VOXELS := TerracePass.TERRACE_HEIGHT_VOXELS

var _terrace: TerracePass
var _channel: ValueNoise


func _init(p_terrace: TerracePass, p_channel: ValueNoise) -> void:
	_terrace = p_terrace
	_channel = p_channel


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds the pass to one world, or returns null (logged) when the binding is missing or a
## layer underneath it cannot be built. **The supported entry point.**
##
## Builds its own `TerracePass`, `TerracePass.for_world()`'s own reason repeated at every
## layer of this chain: the object is stateless and small, and a shared instance would be a
## second way for two passes to disagree about which world they are generating.
static func for_world(p_hash: GenerationHash) -> RiverPass:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build the river pass without a world binding"):
		return null
	var bound_terrace := TerracePass.for_world(p_hash)
	if bound_terrace == null:
		return null
	var channel_layer := ValueNoise.layer(p_hash, CHANNEL_CELL_SIZE_VOXELS, CHANNEL_OCTAVES,
			CHANNEL_GAIN, WorldHash.SALT_RIVERS)
	if channel_layer == null:
		return null
	return RiverPass.new(bound_terrace, channel_layer)


# ---------------------------------------------------------------------------
# The clip
# ---------------------------------------------------------------------------

## True where the channel mask crosses this column **and** the ground is lowland enough to
## carry it. The mask is checked first: it costs two octaves of 2D noise, where the ceiling
## check costs the whole chain underneath `TerracePass`, so the cheap half runs first and the
## expensive half only runs where it could still flip the answer.
func is_river_at(column: Vector2i) -> bool:
	if not is_channel_at(column):
		return false
	return _terrace.at(column) <= RIVER_CEILING_VOXELS


## True where the column sits within `CHANNEL_HALF_WIDTH` of the channel layer's own zero
## contour — the geographic shape alone, with no lowland gate applied. For a debug probe or a
## later brick that wants the raw channel network without this brick's own ceiling.
func is_channel_at(column: Vector2i) -> bool:
	return channel_distance_at(column) < CHANNEL_HALF_WIDTH


## How far this column sits from the channel layer's own zero contour, in `[0, 1]`. Small
## near a channel, large away from one. Pure: same column, same answer, whatever else was
## sampled first (`CLAUDE.md` §1).
func channel_distance_at(column: Vector2i) -> float:
	return absf(_channel.value(column))


## Height of the ground at a world column, in voxels above the datum, after the river clip.
## Always an exact multiple of `TerracePass.TERRACE_HEIGHT_VOXELS` — `TerracePass.at()` is,
## and this only ever subtracts a whole `CARVE_DEPTH_VOXELS` from it.
func at(column: Vector2i) -> float:
	return float(surface_y(column))


## The same height as an integer voxel plane — `TerracePass.surface_y()`'s own reason: this is
## the question every consumer of a terraced surface actually asks.
func surface_y(column: Vector2i) -> int:
	var base := _terrace.surface_y(column)
	if is_river_at(column):
		return base - CARVE_DEPTH_VOXELS
	return base


## The same height, asked at a voxel: Y is dropped, exactly as `TerracePass.at_voxel()` drops
## it. "How high is the ground here" is a property of the column.
func at_voxel(voxel: Vector3i) -> float:
	return at(GenerationGrid.voxel_to_column(voxel))


## The same height in metres, for a log line, a design note or a debug overlay. Never for
## generation arithmetic — that stays in voxels, where the numbers are exact.
func at_metres(column: Vector2i) -> float:
	return WorldScale.voxels_to_metres(at(column))


# ---------------------------------------------------------------------------
# Shape of the pass
# ---------------------------------------------------------------------------

## The pass underneath, for a consumer that wants the uncarved terrace surface directly.
## Read-only by convention: neither object this file holds is mutable.
func terrace() -> TerracePass:
	return _terrace


## The channel layer, for a debug probe or a later brick (082's lakes) that wants the same
## noise field thresholded a different way.
func channel_noise() -> ValueNoise:
	return _channel


## The tallest vertical face two columns one voxel apart can present, in voxels: `TerracePass.
## max_riser_voxels()` plus one more riser for the channel edge itself, which this pass can
## introduce where a river column sits beside a dry one.
func max_riser_voxels() -> float:
	return _terrace.max_riser_voxels() + float(CARVE_DEPTH_VOXELS)


# ---------------------------------------------------------------------------
# Self-check
# ---------------------------------------------------------------------------

## Empty string when the constants above still hold the relationships the class comment
## claims, otherwise the reason. Same shape and purpose as `WaterLevel.self_check()`/
## `CaveMask.self_check()`: the relationship is claimed in the comment and asserted here
## rather than trusted from it.
static func self_check() -> String:
	if int(RIVER_CEILING_VOXELS) % TerracePass.TERRACE_HEIGHT_VOXELS != 0:
		return "RIVER_CEILING_VOXELS (%s) is not an exact multiple of TERRACE_HEIGHT_VOXELS (%d)" % [
				RIVER_CEILING_VOXELS, TerracePass.TERRACE_HEIGHT_VOXELS]
	if RIVER_CEILING_VOXELS < TerracePass.MINIMUM_VOXELS or RIVER_CEILING_VOXELS > TerracePass.MAXIMUM_VOXELS:
		return "RIVER_CEILING_VOXELS (%s) is outside TerracePass's own range [%s, %s]" % [
				RIVER_CEILING_VOXELS, TerracePass.MINIMUM_VOXELS, TerracePass.MAXIMUM_VOXELS]
	if CHANNEL_CELL_SIZE_VOXELS != ElevationField.RELIEF_CELL_SIZE_VOXELS * 4:
		return "CHANNEL_CELL_SIZE_VOXELS (%d) is no longer four times RELIEF_CELL_SIZE_VOXELS (%d)" % [
				CHANNEL_CELL_SIZE_VOXELS, ElevationField.RELIEF_CELL_SIZE_VOXELS]
	if CHANNEL_HALF_WIDTH <= 0.0 or CHANNEL_HALF_WIDTH >= 1.0:
		return "CHANNEL_HALF_WIDTH (%s) is outside (0, 1)" % CHANNEL_HALF_WIDTH
	return ""
