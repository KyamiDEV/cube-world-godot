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
