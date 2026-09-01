class_name BlockEditApplicator
extends RefCounted
## Applies an already-validated `EditBlockCommand` to real voxel data (backlog brick 046).
##
## The last stage of the edit pipeline `docs/server-authority.md` §3 describes:
## `command.validate()` (044, structural) then `BlockEditValidator.validate()` (045,
## gameplay) must both have already returned `ACCEPT` before this is called — the same
## "layer already checked it" trust 045 itself places in 044. This layer performs no
## gameplay re-check (occupied/air/destructible): that would duplicate 045, not add
## anything, since nothing about voxel content changes between validating a command and
## applying it in the same call.
##
## Writes `registry.network_index(block_id) + 1` for `PLACE` and `0` (air) for `REMOVE`,
## via `VoxelTool.set_voxel()` — the exact inverse of the `- 1` offset
## `block_raycast_service.gd` (043) and `block_edit_validator.gd` (045) apply when
## *reading* a voxel back into a block id (`blocky_library_builder.gd`, 037).
##
## `apply_capturing_delta()` (047) is the same write with the pre-edit content also
## reported back as a `BlockEditDelta`, for persistence/undo callers that need it.

## Applies `command`'s effect to `terrain`'s voxel data. Returns false — and logs why via
## `Log.check` — only for a programmer/data error a correctly-ordered caller should never
## trigger: an unlocked registry, a terrain with no voxel tool, or (for `PLACE`) a
## `block_id` the registry does not actually contain despite passing structural/gameplay
## validation. These mirror the exact defensive checks 043/045 already make before
## touching voxel data, not a re-run of 045's gameplay verdicts.
static func apply(command: EditBlockCommand, terrain: VoxelTerrain,
		registry: BlockRegistry) -> bool:
	if not Log.check(registry.is_locked(), Log.CH_VOXEL,
			"block registry must be locked before applying an edit"):
		return false

	var tool := terrain.get_voxel_tool()
	if not Log.check(tool != null, Log.CH_VOXEL,
			"terrain did not produce a voxel tool (mesher/generator not configured?)"):
		return false

	var raw_value := 0  # REMOVE writes air; 037's air offset.
	if command.kind == EditBlockCommand.Kind.PLACE:
		if not Log.check(registry.has_block(command.block_id), Log.CH_VOXEL,
				"attempted to place an unregistered block id — command bypassed validation?",
				{"block_id": command.block_id}):
			return false
		raw_value = registry.network_index(command.block_id) + 1

	tool.set_voxel(command.position, raw_value)
	return true


## Same effect as `apply()`, but also returns what changed as a `BlockEditDelta` (047) —
## the unit `docs/persistence.md` §5's world-modification deltas and an undo are both
## built from. The pre-edit content must be read before `set_voxel()` overwrites it,
## which is the one thing `apply()` itself cannot report back; the actual write is
## delegated to `apply()` so the two entry points can never disagree about what
## happened. Returns null on the same rejections `apply()` itself logs — this adds no
## checks of its own, so no `Log.check` calls here would ever fire.
static func apply_capturing_delta(command: EditBlockCommand, terrain: VoxelTerrain,
		registry: BlockRegistry) -> BlockEditDelta:
	if not registry.is_locked():
		return null
	var tool := terrain.get_voxel_tool()
	if tool == null:
		return null

	var previous_id := registry.id_from_network_index(tool.get_voxel(command.position) - 1)
	if not apply(command, terrain, registry):
		return null

	var new_id := command.block_id if command.kind == EditBlockCommand.Kind.PLACE else ""
	return BlockEditDelta.new(command.position, previous_id, new_id, command.tick)
