class_name BlockEditDelta
extends RefCounted
## Records what one applied `EditBlockCommand` (044/046) actually changed at one voxel
## (backlog brick 047): the block id that occupied `position` before the edit, and the
## one that occupies it after.
##
## This is the unit `docs/persistence.md` §5 means by a world-modification "delta" —
## "only what a player changed differs from the generator's output" — and, by keeping
## both sides of the change rather than only the result, it is also the unit an undo
## replays: writing `previous_block_id` back via `inverse_command()` restores exactly
## what generation (or an earlier edit) had there, with no separate undo-writing code
## path. Deliberately distinct from `MessageTaxonomy.Kind.DELTA` (`docs/protocol.md`
## §1) — that is a network-replication concept (state changed since an acknowledged
## snapshot); this is a persistence/undo concept (state changed since deterministic
## generation). The two share a name by coincidence of English, not by design.
##
## `""` means air on both sides, the same empty-string-is-air convention
## `EditBlockCommand`/`BlockEditApplicator` already use — this type invents no new
## convention of its own.

## Voxel this delta describes.
var position: Vector3i

## Stable id (domain "block") that occupied `position` before the edit, or "" for air.
var previous_block_id: String

## Stable id that occupies `position` after the edit, or "" for air.
var new_block_id: String

## Simulation tick the originating command was produced for.
var tick: int


func _init(p_position: Vector3i, p_previous_block_id: String, p_new_block_id: String,
		p_tick: int) -> void:
	position = p_position
	previous_block_id = p_previous_block_id
	new_block_id = p_new_block_id
	tick = p_tick


## True when the edit recorded no actual change (both sides name the same content).
func is_noop() -> bool:
	return previous_block_id == new_block_id


## Builds the `EditBlockCommand` that reverses this delta at `p_tick` — always the
## undo's own tick, never this delta's `tick`. Restoring air means `REMOVE`ing whatever
## now occupies `position`; restoring a named block means `PLACE`ing it back.
## `face_normal` carries no meaning for an undo (nothing was struck), so it is left
## `Vector3.ZERO` — the same "no direction" value a directly-issued edit, not derived
## from a raycast hit, would use.
func inverse_command(p_tick: int) -> EditBlockCommand:
	if previous_block_id.is_empty():
		return EditBlockCommand.new(EditBlockCommand.Kind.REMOVE, position, Vector3.ZERO, "",
				p_tick)
	return EditBlockCommand.new(EditBlockCommand.Kind.PLACE, position, Vector3.ZERO,
			previous_block_id, p_tick)
