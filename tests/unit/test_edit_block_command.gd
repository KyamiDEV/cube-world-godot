extends TestCase
## Covers network/packets/edit_block_command.gd (brick 044).

const _POSITION := Vector3i(8, 4, 8)
const _NORMAL := Vector3.UP
const _TICK := 1000


func _hit(hit_position: Vector3i = _POSITION,
		placement_position: Vector3i = Vector3i(8, 5, 8)) -> BlockRaycastHit:
	return BlockRaycastHit.new("block.stone", hit_position, placement_position, _NORMAL, 3.0)


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func test_place_carries_the_given_fields() -> void:
	var command := EditBlockCommand.new(EditBlockCommand.Kind.PLACE, _POSITION, _NORMAL,
			"block.dirt", _TICK)

	assert_eq(command.kind, EditBlockCommand.Kind.PLACE)
	assert_eq(command.position, _POSITION)
	assert_eq(command.face_normal, _NORMAL)
	assert_eq(command.block_id, "block.dirt")
	assert_eq(command.tick, _TICK)


func test_from_hit_place_targets_the_placement_position() -> void:
	var command := EditBlockCommand.from_hit(_hit(), EditBlockCommand.Kind.PLACE,
			"block.dirt", _TICK)

	assert_eq(command.position, Vector3i(8, 5, 8))
	assert_eq(command.face_normal, _NORMAL)


func test_from_hit_remove_targets_the_hit_position() -> void:
	var command := EditBlockCommand.from_hit(_hit(), EditBlockCommand.Kind.REMOVE, "", _TICK)

	assert_eq(command.position, _POSITION)
	assert_eq(command.block_id, "")


# ---------------------------------------------------------------------------
# validate() — structural checks only
# ---------------------------------------------------------------------------

func test_a_well_formed_place_is_valid() -> void:
	var command := EditBlockCommand.new(EditBlockCommand.Kind.PLACE, _POSITION, _NORMAL,
			"block.dirt", _TICK)

	assert_true(command.is_valid())
	assert_eq(command.validate(), "")


func test_a_well_formed_remove_is_valid() -> void:
	var command := EditBlockCommand.new(EditBlockCommand.Kind.REMOVE, _POSITION, _NORMAL,
			"", _TICK)

	assert_true(command.is_valid())


func test_place_with_an_empty_block_id_is_invalid() -> void:
	var command := EditBlockCommand.new(EditBlockCommand.Kind.PLACE, _POSITION, _NORMAL,
			"", _TICK)

	assert_false(command.is_valid())


func test_place_with_a_malformed_block_id_is_invalid() -> void:
	var command := EditBlockCommand.new(EditBlockCommand.Kind.PLACE, _POSITION, _NORMAL,
			"Not An Id", _TICK)

	assert_false(command.is_valid())


func test_place_with_a_non_block_domain_id_is_invalid() -> void:
	var command := EditBlockCommand.new(EditBlockCommand.Kind.PLACE, _POSITION, _NORMAL,
			"item.sword.iron", _TICK)

	assert_false(command.is_valid())


func test_remove_with_a_block_id_is_invalid() -> void:
	# REMOVE names no content — carrying one is a malformed command, not a hint.
	var command := EditBlockCommand.new(EditBlockCommand.Kind.REMOVE, _POSITION, _NORMAL,
			"block.dirt", _TICK)

	assert_false(command.is_valid())


func test_a_negative_tick_is_invalid() -> void:
	var command := EditBlockCommand.new(EditBlockCommand.Kind.PLACE, _POSITION, _NORMAL,
			"block.dirt", -1)

	assert_false(command.is_valid())


# ---------------------------------------------------------------------------
# kind_name()
# ---------------------------------------------------------------------------

func test_kind_name_matches_the_enum() -> void:
	assert_eq(EditBlockCommand.kind_name(EditBlockCommand.Kind.PLACE), "PLACE")
	assert_eq(EditBlockCommand.kind_name(EditBlockCommand.Kind.REMOVE), "REMOVE")
