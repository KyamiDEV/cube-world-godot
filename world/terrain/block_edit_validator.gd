class_name BlockEditValidator
extends RefCounted
## Layer 2 (gameplay) validation for `EditBlockCommand` against actual world state
## (backlog brick 045).
##
## `docs/server-authority.md` §3 splits command validation into two layers: layer 1
## (`CommandGate`, brick 019) checks the envelope — may this peer have sent this, now —
## using no world state at all. Layer 2 is specific to each command and checks whether
## the action is legal given the world as it actually is. This is that layer for
## `EditBlockCommand` (044): is `position` within the terrain's editable bounds, does
## `PLACE` name a block the registry actually has and target an empty voxel, does
## `REMOVE` target a real, `destructible` block.
##
## Assumes `command.validate()` (044, structural only — grammar, domain, kind/id
## agreement) has already passed, the same way `CommandGate` assumes a well-formed
## envelope. This layer only asks what that structural pass could not: whether
## `block_id` is *registered*, not just well-formed, and whether the target voxel's
## actual content makes the edit legal.
##
## Bounds are read from `terrain.bounds` (`VoxelTerrain`'s own real property,
## godot_voxel `doc/classes/VoxelTerrain.xml`) rather than a separately invented policy —
## `docs/voxel-tools.md` §6 already records that no world-size decision has been made
## yet, so `bounds` is still at its (effectively unbounded) engine default. This check
## simply enforces whatever that property holds, so a real world-size decision (backlog
## brick 050, "voxel world bounds/authority policy") only has to set `terrain.bounds`
## correctly — it does not need a second bounds concept here.
##
## Ordinary rejections (`OUT_OF_BOUNDS`, `UNKNOWN_BLOCK`, `TARGET_OCCUPIED`,
## `TARGET_IS_AIR`, `NOT_DESTRUCTIBLE`) are not logged — `docs/server-authority.md` §4:
## "rejection is normal", produced by latency and ordinary mistaken input, and block
## edits can be frequent enough that per-rejection logging would violate
## `docs/logging-and-errors.md`'s own no-per-frame-spam rule. `INVALID_REGISTRY`,
## `INVALID_TERRAIN` and `UNRESOLVABLE_VOXEL` are logged (`Log.check`) because they
## signal a programmer/data error, not a normal gameplay outcome — the same distinction
## `block_raycast_service.gd` (043) already draws.

enum Verdict {
	ACCEPT,
	## `registry` is not locked — a programmer/data error, not caller input.
	INVALID_REGISTRY,
	## `terrain` produced no `VoxelTool` (mesher/generator not configured).
	INVALID_TERRAIN,
	## `command.position` is outside `terrain.bounds`.
	OUT_OF_BOUNDS,
	## `PLACE` names a `block_id` the registry does not contain.
	UNKNOWN_BLOCK,
	## The voxel already at `command.position` has no registered block id — the terrain
	## was not built from `registry`, or its data is corrupt.
	UNRESOLVABLE_VOXEL,
	## `PLACE` targets a voxel that is not air.
	TARGET_OCCUPIED,
	## `REMOVE` targets a voxel that is already air.
	TARGET_IS_AIR,
	## `REMOVE` targets a block whose definition has `destructible == false`.
	NOT_DESTRUCTIBLE,
}


## Validates `command` against `terrain`'s actual voxel content and `registry`. Assumes
## `command.validate()` (044) already returned `""` — this only checks what that
## structural pass cannot: registry membership and world state.
static func validate(command: EditBlockCommand, terrain: VoxelTerrain,
		registry: BlockRegistry) -> Verdict:
	if not Log.check(registry.is_locked(), Log.CH_VOXEL,
			"block registry must be locked before validating an edit"):
		return Verdict.INVALID_REGISTRY

	var tool := terrain.get_voxel_tool()
	if not Log.check(tool != null, Log.CH_VOXEL,
			"terrain did not produce a voxel tool (mesher/generator not configured?)"):
		return Verdict.INVALID_TERRAIN

	if not terrain.bounds.has_point(Vector3(command.position)):
		return Verdict.OUT_OF_BOUNDS

	if command.kind == EditBlockCommand.Kind.PLACE:
		return _validate_place(command, tool, registry)
	return _validate_remove(command, tool, registry)


static func verdict_name(verdict: Verdict) -> String:
	return Verdict.keys()[verdict]


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

static func _validate_place(command: EditBlockCommand, tool: VoxelTool,
		registry: BlockRegistry) -> Verdict:
	if not registry.has_block(command.block_id):
		return Verdict.UNKNOWN_BLOCK

	var raw := tool.get_voxel(command.position)
	if raw != 0:  # 037's air offset: 0 is always air, regardless of registry contents
		return Verdict.TARGET_OCCUPIED

	return Verdict.ACCEPT


static func _validate_remove(command: EditBlockCommand, tool: VoxelTool,
		registry: BlockRegistry) -> Verdict:
	var raw := tool.get_voxel(command.position)
	if raw == 0:
		return Verdict.TARGET_IS_AIR

	var id := registry.id_from_network_index(raw - 1)  # 037's air offset
	if not Log.check(not id.is_empty(), Log.CH_VOXEL,
			"edit target voxel has no registered block id",
			{"position": command.position, "raw_value": raw}):
		return Verdict.UNRESOLVABLE_VOXEL

	if not registry.get_block(id).destructible:
		return Verdict.NOT_DESTRUCTIBLE

	return Verdict.ACCEPT
