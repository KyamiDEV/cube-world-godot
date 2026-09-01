class_name EditBlockCommand
extends RefCounted
## Client -> server intent to place or remove one block (backlog brick 044).
##
## `docs/protocol.md` §2 names `EditBlockCommand` among the worked command examples: a
## **wish**, not a result. Per CLAUDE.md §12 an edit is a command the server validates,
## not a raw voxel write — this type carries only *what the player wants*: a target
## voxel, which face was struck, and the placement id. It does not decide whether the
## edit is legal (brick 045, gameplay validation against world state) or write the voxel
## (brick 046, application layer using `BlockRegistry.network_index(id) + 1`, the
## inverse of the `- 1` `BlockRaycastService` (043) applies on read).
##
## Deliberately excludes envelope fields (`docs/server-authority.md` §3 layer 1): peer
## id, owner, and sequence number are resolved by `CommandGate` from the connection, not
## carried in the payload — a packet field is not evidence of ownership (A4). `tick` is
## the one envelope-shaped field kept here because `MessageTaxonomy.requires_tick()`
## makes it part of what a COMMAND *is*, not part of who sent it.

enum Kind {
	## Turn the target voxel into `block_id`.
	PLACE,
	## Turn the target voxel into air.
	REMOVE,
}

## Which edit this is.
var kind: Kind

## Target voxel coordinates, already resolved to what should be written: the hit voxel
## itself for `REMOVE`, the voxel just outside the hit face for `PLACE`
## (`BlockRaycastHit.hit_position` / `placement_position`, brick 043).
var position: Vector3i

## Unit surface normal of the face the player was aiming at when the command was formed.
## Carried for gameplay validation that needs the approach direction (e.g. adjacency or
## reach checks in brick 045) — informational context, not part of `position` itself.
var face_normal: Vector3

## Stable id (domain "block") of the block kind to place. Empty for `REMOVE`, which
## names no content — there is nothing to place.
var block_id: String

## Simulation tick this command was produced for (`docs/simulation-time.md`).
var tick: int


func _init(p_kind: Kind, p_position: Vector3i, p_face_normal: Vector3, p_block_id: String,
		p_tick: int) -> void:
	kind = p_kind
	position = p_position
	face_normal = p_face_normal
	block_id = p_block_id
	tick = p_tick


## Builds the command from a raycast hit (043), picking the correct target voxel for
## `kind` automatically so no caller re-derives hit-vs-placement position itself.
## `block_id` is only meaningful for `Kind.PLACE`; pass "" for `Kind.REMOVE`.
static func from_hit(hit: BlockRaycastHit, p_kind: EditBlockCommand.Kind, p_block_id: String,
		p_tick: int) -> EditBlockCommand:
	var target := hit.placement_position if p_kind == Kind.PLACE else hit.hit_position
	return EditBlockCommand.new(p_kind, target, hit.normal, p_block_id, p_tick)


## Returns an empty string when structurally well-formed, otherwise a human-readable
## reason — same convention as `StableId.validate()`/`BlockDefinition.validate()`.
## Structural only: whether `position` is within world/authored bounds, whether
## `block_id` names a block the sender may place, and every other world-state question
## is gameplay validation (brick 045), not this command's job.
func validate() -> String:
	if tick < 0:
		return "tick must not be negative"
	match kind:
		Kind.PLACE:
			var id_problem := StableId.validate(block_id)
			if not id_problem.is_empty():
				return "block_id: " + id_problem
			if StableId.domain_of(block_id) != "block":
				return "block_id must be in the 'block' domain, got '%s'" % block_id
		Kind.REMOVE:
			if not block_id.is_empty():
				return "block_id must be empty for a REMOVE command"
		_:
			return "unknown kind %s" % kind
	return ""


func is_valid() -> bool:
	return validate().is_empty()


static func kind_name(p_kind: Kind) -> String:
	return Kind.keys()[p_kind]
