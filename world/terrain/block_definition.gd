class_name BlockDefinition
extends Resource
## Immutable per-kind block data (backlog brick 031).
##
## One resource describes one distinct block *kind* — "block.grass", "block.stone" —
## never one voxel instance. A loader parses `data/blocks/*.tres` (or JSON, once a
## loader exists) and hands each one to a `BlockRegistry` (brick 032), which owns
## storage, locking and network indices; this file only defines the shape and the
## self-validation every domain's definition type is responsible for
## (`docs/ids-and-registries.md` §5).

## Stable content ID, domain "block" — e.g. "block.grass". Written into save files and
## network packets; see `docs/ids-and-registries.md`.
@export var id: String = ""

## Editor/tooling display only. Never a key (`docs/conventions.md` §5).
@export var display_name: String = ""

## Per-face texture paths (backlog brick 033) — top/side/bottom, not six, mirrors the
## scheme every reference block needs (grass: green top, dirt-textured sides) without
## guessing at a full six-sided model this early; a uniform block (stone) simply repeats
## the same path in all three. Plain `res://...` resource path, same "String, no editor
## hint" style as `id`/`display_name` — resolved into an actual `Texture2D`/`Material`
## by the `VoxelBlockyLibrary` bootstrap (037), not here.
@export var texture_top: String = ""
@export var texture_side: String = ""
@export var texture_bottom: String = ""

## Carries `VoxelBlockyModel`'s own face-culling flag (`transparent`): true means
## neighbor faces behind this block must still be meshed (glass, leaves) instead of
## culled as hidden. Recorded on the definition, not derived from texture content, so
## 037 can set the mesher model's flag directly. Defaults to opaque, matching
## `VoxelBlockyModel`'s own default.
@export var transparent: bool = false

## Whether this block kind produces collision at all (backlog brick 034). Mirrors
## `docs/conventions.md` §5's own worked example for this exact concept
## (`is_solid, has_collision`). Deliberately a plain predicate, not a raw
## `VoxelBlockyModel.collision_mask` bitmask — which physics layer(s) a solid block
## occupies is an engine-integration decision for the `VoxelBlockyLibrary` bootstrap
## (037), not block-kind data. Defaults to true: most reference blocks (stone, dirt,
## grass) are walkable/solid; a block kind that should not collide (e.g. a future
## decorative or liquid-surface kind) sets this to false explicitly.
@export var is_solid: bool = true

## Whether this block kind can be destroyed by ordinary player action at all (backlog
## brick 035). Bare adjective, no `is_`/`has_` prefix — same style as `transparent`
## (033), both read fine as a predicate on their own. Defaults to true: most reference
## blocks (stone, dirt, grass) are minable; a future kind meant to be permanent (e.g. a
## world-boundary or structural-core block) sets this to false explicitly. Independent
## of `is_solid` — a block can collide but never be destroyed, or vice versa (a
## walk-through hazard that still yields a drop).
@export var destructible: bool = true

## Relative effort required to destroy this block kind, e.g. mining-time weight. An
## abstract positive multiplier, not seconds and not tied to any specific tool-tier
## system — which tool types affect it, and how, is equipment/combat-system data
## (Phase G/H), not block-kind data. Meaningless when `destructible` is false, but still
## validated so a data file can't carry a nonsensical value it forgot to fix when
## flipping `destructible` back on later.
@export var hardness: float = 1.0

## Stable ID (domain "item") of the item this block kind yields on destruction, or an
## empty string for no drop (e.g. a decorative or liquid-surface kind). Quantity/roll
## variance is a loot-system concern (Phase H), not recorded here — this field only
## names *what*, not how many. No `ItemRegistry` exists yet (Phase H), so `validate()`
## below only checks the ID's own grammar and domain, the same way it already checks
## `id`/`display_name` without a live registry to cross-reference against — whether the
## named item actually exists is a data-loading-time concern, not this resource's.
@export var drop_item_id: String = ""

## Surface-material category for footstep/movement audio (backlog brick 036) — e.g.
## "grass", "dirt", "stone", "sand". A plain lowercase tag, not a stable ID: it names a
## material *category* shared by many block kinds, not one piece of identified content,
## so it carries no domain prefix and is not looked up through a registry. Brick 220
## ("footstep/audio surface mapping", Phase J) builds the tag -> sound-event table this
## feeds; that mapping stays out of scope here, same as 037's texture/material
## resolution staying out of scope for 033. Required like the texture fields — every
## block kind a player can stand on needs a footstep category, and unlike `hardness`
## (meaningless but harmless when `destructible` is false) there is no default that
## would be correct for an unset tag.
@export var footstep_tag: String = ""


## Returns an empty string when well-formed, otherwise a human-readable reason — same
## convention as `StableId.validate()`, so a bad data file logs a useful error instead
## of "invalid definition".
func validate() -> String:
	var id_problem := StableId.validate(id)
	if not id_problem.is_empty():
		return id_problem
	if StableId.domain_of(id) != "block":
		return "block definition id must be in the 'block' domain, got '%s'" % id
	if display_name.is_empty():
		return "display_name is empty"
	if texture_top.is_empty():
		return "texture_top is empty"
	if texture_side.is_empty():
		return "texture_side is empty"
	if texture_bottom.is_empty():
		return "texture_bottom is empty"
	if hardness <= 0.0:
		return "hardness must be greater than 0"
	if not drop_item_id.is_empty():
		var drop_problem := StableId.validate(drop_item_id)
		if not drop_problem.is_empty():
			return "drop_item_id: " + drop_problem
		if StableId.domain_of(drop_item_id) != "item":
			return "drop_item_id must be in the 'item' domain, got '%s'" % drop_item_id
	if footstep_tag.is_empty():
		return "footstep_tag is empty"
	return ""


func is_valid() -> bool:
	return validate().is_empty()
