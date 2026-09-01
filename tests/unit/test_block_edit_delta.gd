extends TestCase
## Covers world/terrain/block_edit_delta.gd (brick 047).

const _POSITION := Vector3i(8, 3, 8)
const _TICK := 1000
const _UNDO_TICK := 1001


func test_is_noop_when_both_sides_name_the_same_content() -> void:
	var delta := BlockEditDelta.new(_POSITION, "block.stone", "block.stone", _TICK)

	assert_true(delta.is_noop())


func test_is_not_noop_when_the_sides_differ() -> void:
	var delta := BlockEditDelta.new(_POSITION, "", "block.stone", _TICK)

	assert_false(delta.is_noop())


func test_inverse_of_a_place_is_a_remove_when_the_voxel_was_air() -> void:
	var delta := BlockEditDelta.new(_POSITION, "", "block.stone", _TICK)

	var undo := delta.inverse_command(_UNDO_TICK)

	assert_eq(undo.kind, EditBlockCommand.Kind.REMOVE)
	assert_eq(undo.position, _POSITION)
	assert_eq(undo.block_id, "")
	assert_eq(undo.tick, _UNDO_TICK)


func test_inverse_of_a_remove_is_a_place_of_the_previous_block() -> void:
	var delta := BlockEditDelta.new(_POSITION, "block.stone", "", _TICK)

	var undo := delta.inverse_command(_UNDO_TICK)

	assert_eq(undo.kind, EditBlockCommand.Kind.PLACE)
	assert_eq(undo.position, _POSITION)
	assert_eq(undo.block_id, "block.stone")
	assert_eq(undo.tick, _UNDO_TICK)


func test_inverse_command_is_structurally_valid() -> void:
	var place_undo := BlockEditDelta.new(_POSITION, "block.stone", "", _TICK) \
			.inverse_command(_UNDO_TICK)
	var remove_undo := BlockEditDelta.new(_POSITION, "", "block.stone", _TICK) \
			.inverse_command(_UNDO_TICK)

	assert_true(place_undo.is_valid())
	assert_true(remove_undo.is_valid())
