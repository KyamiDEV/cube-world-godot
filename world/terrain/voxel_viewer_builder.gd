class_name VoxelViewerBuilder
extends RefCounted
## Builds a baseline `VoxelViewer` node (backlog brick 042).
##
## `VoxelViewer` is a `Node3D`, not a `VoxelTerrain` property — Voxel Tools streams
## voxels around whatever `VoxelViewer`s exist in the scene tree, independent of any one
## `VoxelNode`. This builder only configures the node's own properties; it does not add
## the result to a tree or parent it under a camera/player, same as
## `VoxelTerrainBuilder.build()` never adds its terrain to a tree. No player/camera exists
## yet (Phase F) to attach it to, so where this node actually lives is still open —
## carried forward in `nextsteps.md`, not decided here.
##
## `view_distance` uses `VoxelTerrainBuilder.DEFAULT_VIEW_DISTANCE` (042) — the same
## constant that brick sets on `VoxelTerrain.max_view_distance` — so a baseline viewer is
## never silently clamped below what it requests (`VoxelTerrain.max_view_distance`'s own
## doc: "If a VoxelViewer requests more, it will be clamped").
##
## `requires_visuals`/`requires_collisions` are set explicitly `true` even though that
## matches the engine default — this is the actual baseline decision (a sandbox needs
## both meshed terrain and collision around the viewer), not an unexamined default, same
## "explicit, not merely unset" reasoning `voxel_terrain_builder.gd` used for
## `material_override` (041). `enabled_in_editor` and
## `requires_data_block_notifications` are left at their engine defaults (`false`) —
## no live-in-editor streaming workflow or block-notification consumer exists yet to
## justify overriding either.


static func build() -> VoxelViewer:
	var viewer := VoxelViewer.new()
	viewer.view_distance = VoxelTerrainBuilder.DEFAULT_VIEW_DISTANCE
	viewer.requires_visuals = true
	viewer.requires_collisions = true
	return viewer
