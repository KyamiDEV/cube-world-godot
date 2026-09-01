class_name TerracePass
extends RefCounted
## The block world: ground snapped to flat terraces with vertical risers between them
## (backlog brick 063).
##
## `ErosionPass` (062) answers with a continuous height — a smooth landscape that happens
## to be stored in voxels. This pass is what makes it a *block world*: every column's
## ground is pulled down to the terrace plane below it, so a hillside stops being a ramp
## and becomes a staircase of flat shelves with clean vertical faces between them. It is
## the last shaping pass over the height field and the one that gives the world its
## silhouette.
##
## ```gdscript
## var ground := TerracePass.for_world(GenerationHash.for_world(world_seed))
## var y := ground.at(column)        # voxels, signed, an exact multiple of the terrace
## var iy := ground.surface_y(column)
## ```
##
## One operation, and it is deliberately the whole pass:
##
## ```text
## at(column) = floor(erosion.at(column) / H) * H,   H = TERRACE_HEIGHT_VOXELS
## ```
##
## Three things follow from that being a *floor* rather than a rounding:
##
## | Property | Why it matters |
## |---|---|
## | it only ever **lowers** ground | `terraced(base) <= at <= erosion.at()`, the same shape as 061's and 062's invariants (`docs/world-generation.md` §7.1) — a fourth pass in the same family, not a new field |
## | the terrace planes are anchored to the **datum** | `y = 0` is a terrace boundary, so every shelf in the world is at a height both the server and a designer can name (§6.1) |
## | the output is **discontinuous**, on purpose | this is the first pass for which `max_step_per_voxel()` is meaningless. What replaces it is `max_riser_voxels()` — the tallest vertical face two neighbouring columns can present |
##
## **The terrace height is not free, it was pinned by brick 061.** `ElevationField` chose 6
## relief octaves so its finest cell is 32 voxels = 16 m, *four times* the terrace height
## here (§6.4): a coarser terrace would round 061's finest octave away entirely and the
## detail it pays four hashes an octave for would never reach the ground. And 062's step
## bound (`2.627` voxels per voxel) is comfortably **under** one terrace, which is what
## makes the staircase legible — see `max_riser_voxels()`.
##
## No new noise field and no new salt: quantisation is a pure function of a height this
## pass is handed, so there is nothing here for a seed to vary. That also means the pass
## costs one division and one `floor` per column on top of 062.
##
## Contract: `docs/world-generation.md` §8.

# ---------------------------------------------------------------------------
# The terrace
# ---------------------------------------------------------------------------

## Height of one terrace, in voxels: 8 voxels = 4 m — roughly two player heights of shelf
## to shelf.
##
## Pinned by brick 061 from the other end: `ElevationField.RELIEF_OCTAVES` was chosen so
## the finest relief cell is 32 voxels, **four times** this number, so the smallest hill
## the field carries still spans several terraces instead of vanishing into one
## (`docs/world-generation.md` §6.4).
##
## A power of two, and that is a determinism decision as much as a design one: `h / 8.0` is
## an exact exponent shift for every finite double, and `floor` is exactly specified by
## IEEE-754 (round toward negative infinity). The whole pass is therefore bit-identical on
## every platform, which `pow()` and `cos()` would not be — the same argument
## `docs/world-generation.md` §5.3 makes about the fade.
const TERRACE_HEIGHT_VOXELS := 8

## The stated range of `at()`, in voxels — 062's, and 061's before it, unchanged.
##
## Inherited rather than restated because `floor` is monotone and both ends of that range
## are exact multiples of `TERRACE_HEIGHT_VOXELS` (`-96 = -12·8`, `+192 = 24·8`), so
## quantising maps the range into itself. `tests/unit/test_terrace_pass.gd` asserts the
## divisibility rather than trusting it: it is a property of 061's vertical anchors, and a
## later change to them would silently push the world one terrace out of its own range.
##
## The minimum is reachable and now easier to reach than before (any column within one
## terrace of the ocean floor lands exactly on it). The maximum is only reached by a column
## whose eroded height is *exactly* `MAXIMUM_VOXELS`; in practice the world's ceiling is
## one terrace below it, which is what a floor-quantised field means and not a defect.
const MINIMUM_VOXELS := ErosionPass.MINIMUM_VOXELS
const MAXIMUM_VOXELS := ErosionPass.MAXIMUM_VOXELS

var _erosion: ErosionPass


func _init(p_erosion: ErosionPass) -> void:
	_erosion = p_erosion


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Binds the pass to one world, or returns null (logged) when the binding is missing or the
## pass underneath it cannot be built. **The supported entry point.**
##
## Builds its own `ErosionPass` for the reason 062 builds its own `ElevationField`: the
## objects are stateless and small, and a shared instance would be a second way for two
## passes to disagree about which world they are generating.
static func for_world(p_hash: GenerationHash) -> TerracePass:
	if not Log.check(p_hash != null, Log.CH_GEN,
			"cannot build the terrace pass without a world binding"):
		return null
	var shaped := ErosionPass.for_world(p_hash)
	if shaped == null:
		return null
	return TerracePass.new(shaped)


# ---------------------------------------------------------------------------
# Sampling
# ---------------------------------------------------------------------------

## Height of the terraced ground at a world column, in voxels above the datum.
##
## Pure, inside `[MINIMUM_VOXELS, MAXIMUM_VOXELS]`, and always an exact integer multiple of
## `TERRACE_HEIGHT_VOXELS`. This is the height the voxel generator will eventually fill up
## to, and the first one in the chain that describes a surface rather than a curve.
func at(column: Vector2i) -> float:
	return terraced(_erosion.at(column))


## The same height as an integer voxel plane.
##
## Exact, not a rounding: `at()` is already integral, so this only changes the type. It
## exists because "which voxel is the top of the ground" is the question every consumer of
## this pass actually asks, and answering it with a float invites each of them to invent
## its own conversion.
func surface_y(column: Vector2i) -> int:
	return int(at(column))


## The same height, asked at a voxel: Y is dropped, exactly as `ErosionPass.at_voxel()`
## drops it. "How high is the ground here" is a property of the column.
func at_voxel(voxel: Vector3i) -> float:
	return at(GenerationGrid.voxel_to_column(voxel))


## The same height in metres, for a log line, a design note or a debug overlay. Never for
## generation arithmetic — that stays in voxels, where the numbers are exact.
func at_metres(column: Vector2i) -> float:
	return WorldScale.voxels_to_metres(at(column))


# ---------------------------------------------------------------------------
# The terms, separately
# ---------------------------------------------------------------------------
#
# Brick 075 wants to know which terrace a column sits on to pick a surface material, 084
# and 085 want to know how close a column sits to the top of its shelf before they decide
# a shoreline or a snowline, and a debug probe wants the height this pass started from.

## The height before quantisation, in voxels: what 062 alone would have answered. The
## ceiling `at()` can never rise above.
func continuous_at(column: Vector2i) -> float:
	return _erosion.at(column)


## Which terrace a column stands on, counted from the datum: `0` is the shelf whose floor
## is `y = 0`, `-1` the one immediately below it.
##
## A signed index, because the datum sits in the middle of the world and half the terraces
## are under it.
func terrace_index_at(column: Vector2i) -> int:
	return terrace_index(_erosion.at(column))


## How many voxels this pass removed at a column: in `[0, TERRACE_HEIGHT_VOXELS)`, never
## negative and never a whole terrace.
func removed_at(column: Vector2i) -> float:
	return _erosion.at(column) - at(column)


## Where in its terrace the continuous height sat, in `[0, 1)` — `0` at the floor of the
## shelf, approaching `1` just below the riser to the next one.
##
## The sub-terrace detail this pass throws away, kept as a number so a later pass can use
## it without recomputing the quantisation. Brick 084's shoreline and 085's snowline both
## want to know that a column is *nearly* over an edge.
func fraction_at(column: Vector2i) -> float:
	return removed_at(column) / float(TERRACE_HEIGHT_VOXELS)


## The terraced height of the column's base, in voxels — the floor `at()` can never go
## below, and the terraced form of 062's own floor.
##
## Quantising the base as well as the height is what keeps the family invariant exact:
## `floor` is monotone, so `base <= erosion.at()` implies `terraced(base) <= at()`. The
## *un*terraced base is no longer a lower bound — a column sitting just above its base gets
## pulled down past it, by less than one terrace.
func terraced_base_at(column: Vector2i) -> float:
	return terraced(_erosion.base_at(column))


# ---------------------------------------------------------------------------
# The curve
# ---------------------------------------------------------------------------

## The terrace plane at or below a height, in voxels.
##
## `floor`, never `round`: rounding would raise ground as often as it lowers it, and this
## pass belongs to a family whose whole shape is that a pass only ever removes material
## (`docs/world-generation.md` §7.1). It would also put the terrace boundaries half a shelf
## off the datum, which is a strange place for the world's landmarks to live.
##
## Static: the quantisation is part of the world's definition, and a test that wants to
## know what happens exactly on a boundary or exactly below one should not have to hunt the
## world for a column that happens to sit there.
static func terraced(height: float) -> float:
	return floorf(height / float(TERRACE_HEIGHT_VOXELS)) * float(TERRACE_HEIGHT_VOXELS)


## The signed terrace index for a height, counted from the datum.
static func terrace_index(height: float) -> int:
	return int(floorf(height / float(TERRACE_HEIGHT_VOXELS)))


# ---------------------------------------------------------------------------
# Shape of the pass
# ---------------------------------------------------------------------------

## The pass underneath, for a consumer that wants the continuous height or one of 062's
## own terms. Read-only by convention: none of these objects holds mutable state.
func erosion() -> ErosionPass:
	return _erosion


## The field under that, for a consumer that wants the shore weight or the unshaped height.
func elevation() -> ElevationField:
	return _erosion.elevation()


## The tallest vertical face two columns one voxel apart can present, in voxels.
##
## **This replaces `max_step_per_voxel()`**, which the passes below all expose and which
## stops meaning anything here: the output is discontinuous by construction, so bounding
## the change between neighbours by a fraction of a voxel is not a property this pass has
## or wants. What it has instead is a bound on how many terraces a single step may cross:
##
## ```text
## riser <= ceil(erosion.max_step_per_voxel() / H) · H
## ```
##
## because `floor(a/H)` and `floor(b/H)` cannot differ by more than `ceil(|a−b|/H)` steps.
## 062's bound is `2.627` voxels per voxel, so this comes to exactly **one terrace, 8
## voxels** — every riser in the world is a single 4 m face, never a stacked cliff. That is
## the property the terrace height is sized for, and it is a derived consequence of the
## constants rather than something to hope for: if a future pass steepened the ground past
## one terrace per voxel, this number would grow with it and say so.
func max_riser_voxels() -> float:
	var height := float(TERRACE_HEIGHT_VOXELS)
	return ceilf(_erosion.max_step_per_voxel() / height) * height


## Height of one terrace, in metres — the shelf-to-shelf drop a player sees.
static func terrace_height_metres() -> float:
	return WorldScale.voxels_to_metres(float(TERRACE_HEIGHT_VOXELS))
