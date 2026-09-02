class_name DecorationMask
extends RefCounted
## Which columns may host natural decoration at all, and how densely (backlog brick 086).
##
## `WorldInfo_scatterObjectsInArea` (`reference/CubeWorld-Reversal/cube/world/WorldInfo.cpp`,
## `0x005f56c0`) is the only reference evidence for this concept
## (`docs/reference/matrix-world.md` §2, confidence LOW): it samples the humidity/temperature
## grids at a point, then scatters candidate object ids "using sqrt spacing" and a
## distance-checked placement helper. This brick keeps the one idea a clean-room
## implementation can actually reuse — an object density expressed as a **spacing**, `1 /
## sqrt(density)` apart — and drops the rest: the reference placement loop checks each new
## candidate's distance against every point already placed, which makes the result depend on
## the order objects are considered. `CLAUDE.md` §1 forbids exactly that for world generation
## ("never of visit order"), so this file answers the same question — "is there room for a
## natural decoration here?" — as a pure function of a column's own coordinates instead: one
## deterministic candidate point per fixed-size cell, chosen by hashing the cell rather than
## by throwing darts and rejecting the ones that land too close.
##
## Two questions, kept separate because 087 (trees) and 088 (rocks) each answer them with
## their own numbers:
##
## - **Eligibility** — can *any* decoration stand on this column at all? Wet and shoreline
##   columns cannot (`ShorelineMaterial`, 084); nothing else is excluded here; a biome-specific
##   reason (bare rock, deep snow) is that pass's own call, not this one's.
## - **Anchoring** — of the columns that pass, which ones are an actual candidate point for a
##   given spacing? One column per `spacing x spacing` cell, placed by hashing the cell so two
##   different spacings (or the same spacing with two different salts) never agree about where
##   inside a shared cell their own anchor sits.
##
## ```gdscript
## var decoration := DecorationMask.for_world(hash, biomes, blocks)
## var spacing := DecorationMask.spacing_for_density(0.02)   # ~1 per 50 columns
## if decoration.is_decoration_anchor_at(column, spacing, WorldHash.SALT_TREES):
##     _place_tree(column)
## ```
##
## ## Why a cell-and-jitter mask reproduces "sqrt spacing" without the dart-throwing
##
## A cell of side `spacing` holding exactly one candidate has area `spacing^2` per point,
## i.e. a density of `1 / spacing^2` points per column — the same relationship the reference
## name implies (`spacing = 1 / sqrt(density)`), reached by fixing the grid instead of
## rejecting close neighbours. It cannot reproduce the reference's exact point set (no
## clean-room implementation should try to), but it is order-free, O(1) per query, and gives
## every decoration pass the same "roughly `spacing` voxels apart, nowhere denser" guarantee
## the original was reaching for.
##
## ## A pure combination over `ShorelineMaterial`, `SnowlineMaterial`'s own precedent
##
## `DecorationMask` holds a `ShorelineMaterial` (084), built fresh in `for_world()` —
## `SnowlineMaterial.for_world()`'s own reason repeated once more: stateless and small, and a
## shared instance would be a second way for two passes to disagree about which world they
## are generating. Nothing here reaches into `SnowlineMaterial` (085): frost cover is a
## per-biome ground question, not a "can anything stand here" question, and this file has no
## more business deciding it than `ShorelineMaterial` had deciding surface material.
##
## Contract: `docs/world-generation.md` §25.

var _hash: GenerationHash
var _shoreline: ShorelineMaterial


func _init(p_hash: GenerationHash, p_shoreline: ShorelineMaterial) -> void:
	_hash = p_hash
	_shoreline = p_shoreline


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds decoration masking to one world and one loaded content set, or returns null
## (logged) when `ShorelineMaterial` itself cannot be built. **The supported entry point.**
static func for_world(p_hash: GenerationHash, p_biomes: BiomeRegistry,
		p_blocks: BlockRegistry) -> DecorationMask:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build decoration masking without a world binding"):
		return null
	var bound_shoreline := ShorelineMaterial.for_world(p_hash, p_biomes, p_blocks)
	if bound_shoreline == null:
		return null
	return DecorationMask.new(p_hash, bound_shoreline)


# ---------------------------------------------------------------------------
# Eligibility
# ---------------------------------------------------------------------------

## True where a column could host natural decoration at all: dry, and not the beach edge of
## a body of water either. `ShorelineMaterial`'s own two exclusions, reused rather than
## re-decided — a wet or shoreline column is exactly as off-limits to a tree or a rock as it
## is to `SnowlineMaterial`'s own override.
func is_eligible_at(column: Vector2i) -> bool:
	return not (_shoreline.is_water_at(column) or _shoreline.is_shoreline_at(column))


## The same answer at a voxel. Y is dropped, exactly as `ShorelineMaterial.
## is_shoreline_at_voxel()` drops it: eligibility is a property of the column.
func is_eligible_at_voxel(voxel: Vector3i) -> bool:
	return is_eligible_at(GenerationGrid.voxel_to_column(voxel))


# ---------------------------------------------------------------------------
# Spacing and anchoring
# ---------------------------------------------------------------------------

## The cell pitch that reproduces a target density of roughly `density_per_column` candidate
## points per column, following the reference's own "sqrt spacing" idea (see the class
## comment). `0` or a negative density returns `0`, meaning "no candidates anywhere" —
## `is_anchor_at()`'s own convention for a disabled pass, matching `GenerationHash.
## chance_column()`'s `probability <= 0` short-circuit.
static func spacing_for_density(density_per_column: float) -> int:
	if density_per_column <= 0.0:
		return 0
	return maxi(1, int(round(1.0 / sqrt(density_per_column))))


## The cell a column falls into at the given spacing: `floor(column / spacing)` on each
## axis. Floored, not truncated, so the cell grid tiles cleanly across the origin — a
## truncating division would fold two cells together on the negative side. `spacing` must be
## positive; `is_anchor_at()` is the entry point that already turns `spacing <= 0` into "no
## candidates" before it would ever reach here.
static func cell_of(column: Vector2i, spacing: int) -> Vector2i:
	return Vector2i(_floor_div(column.x, spacing), _floor_div(column.y, spacing))


## The one column inside `cell` that is a decoration candidate at this spacing and salt.
## Chosen by drawing two sequential values from the cell's own stream
## (`GenerationHash.rng_decoration_cell()`) — `x` offset, then `z` offset — the same
## "position-owned stream" shape `GenerationHash`'s own class comment describes for a
## structure's kind, then its rotation.
func anchor_column_in_cell(cell: Vector2i, spacing: int, salt: int) -> Vector2i:
	var rng := _hash.rng_decoration_cell(cell, salt)
	var offset_x := rng.next_int(0, spacing - 1)
	var offset_z := rng.next_int(0, spacing - 1)
	return Vector2i(cell.x * spacing + offset_x, cell.y * spacing + offset_z)


## True where `column` is its cell's own chosen candidate point. Says nothing about
## eligibility — see `is_decoration_anchor_at()` for the combined answer a placement pass
## actually wants.
func is_anchor_at(column: Vector2i, spacing: int, salt: int) -> bool:
	if spacing <= 0:
		return false
	return anchor_column_in_cell(cell_of(column, spacing), spacing, salt) == column


## The combined answer: `column` is both eligible ground and its cell's chosen anchor.
## **The entry point a placement pass (087, 088) actually calls.**
func is_decoration_anchor_at(column: Vector2i, spacing: int, salt: int) -> bool:
	return is_eligible_at(column) and is_anchor_at(column, spacing, salt)


# ---------------------------------------------------------------------------
# Shape of the pass
# ---------------------------------------------------------------------------

## The wet/shoreline classification underneath, for a consumer that wants the unmasked
## answer directly. Read-only by convention.
func shoreline() -> ShorelineMaterial:
	return _shoreline


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Floor division assuming `divisor > 0` (every caller here already refused `spacing <= 0`).
## GDScript's `/` truncates toward zero, so a negative, non-exact division needs one more
## step down to land on the floor instead.
static func _floor_div(value: int, divisor: int) -> int:
	@warning_ignore("integer_division")
	var quotient := value / divisor
	if value % divisor != 0 and value < 0:
		quotient -= 1
	return quotient
