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
##
## Material, collision, interaction/destruction and footstep/surface-tag fields are
## added by dedicated bricks (033–036) rather than guessed here.

## Stable content ID, domain "block" — e.g. "block.grass". Written into save files and
## network packets; see `docs/ids-and-registries.md`.
@export var id: String = ""

## Editor/tooling display only. Never a key (`docs/conventions.md` §5).
@export var display_name: String = ""


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
	return ""


func is_valid() -> bool:
	return validate().is_empty()
