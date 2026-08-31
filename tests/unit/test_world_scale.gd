extends TestCase
## Covers core/math/world_scale.gd (brick 013).
##
## These assertions are the definition of the unit system. If one of them has to be
## "fixed", the change is an ADR, not an edit.


func test_scale_constants_match_the_contract() -> void:
	assert_almost_eq(WorldScale.METRES_PER_VOXEL, 0.5, 1e-12, "1 voxel = 0.5 m")
	assert_almost_eq(WorldScale.VOXELS_PER_METRE, 2.0, 1e-12, "1 m = 2 voxels")
	assert_almost_eq(WorldScale.UNITS_PER_METRE, 2.0, 1e-12, "1 m = 2 world units")
	assert_almost_eq(WorldScale.METRES_PER_UNIT, 0.5, 1e-12, "1 world unit = 0.5 m")


func test_one_world_unit_is_one_voxel() -> void:
	# Voxel Tools meshes LOD0 at one voxel per unit. Everything that floors a Godot
	# position straight into a voxel coordinate depends on this identity.
	assert_almost_eq(WorldScale.UNITS_PER_VOXEL, 1.0, 1e-12)
	assert_eq(WorldScale.world_to_voxel(Vector3(3.0, 4.0, 5.0)), Vector3i(3, 4, 5),
			"a unit position maps to the same-numbered voxel")


func test_constants_are_mutually_consistent() -> void:
	assert_almost_eq(WorldScale.METRES_PER_VOXEL * WorldScale.VOXELS_PER_METRE, 1.0, 1e-12,
			"the two voxel constants are reciprocals")
	assert_almost_eq(WorldScale.METRES_PER_UNIT * WorldScale.UNITS_PER_METRE, 1.0, 1e-12,
			"the two unit constants are reciprocals")
	assert_almost_eq(WorldScale.CUBIC_METRES_PER_VOXEL, 0.125, 1e-12,
			"a voxel is 0.5^3 cubic metres")


# ---------------------------------------------------------------------------
# Metres <-> units
# ---------------------------------------------------------------------------

func test_metres_convert_to_units() -> void:
	assert_almost_eq(WorldScale.metres_to_units(1.0), 2.0)
	assert_almost_eq(WorldScale.metres_to_units(1.8), 3.6, 1e-9, "a 1.8 m creature")
	assert_almost_eq(WorldScale.metres_to_units(0.0), 0.0)
	assert_almost_eq(WorldScale.metres_to_units(-2.5), -5.0, 1e-9, "negatives scale too")


func test_m_is_an_alias_for_metres_to_units() -> void:
	assert_almost_eq(WorldScale.m(1.8), WorldScale.metres_to_units(1.8), 1e-12)


func test_unit_and_metre_conversions_round_trip() -> void:
	for metres in [0.0, 0.25, 1.0, 1.8, 37.5, -12.25]:
		assert_almost_eq(WorldScale.units_to_metres(WorldScale.metres_to_units(metres)),
				metres, 1e-9, "round trip for %s m" % metres)


func test_vector_conversions_scale_every_axis() -> void:
	assert_eq(WorldScale.metres_to_units_v(Vector3(1.0, 2.0, 3.0)), Vector3(2.0, 4.0, 6.0))
	assert_eq(WorldScale.units_to_metres_v(Vector3(2.0, 4.0, 6.0)), Vector3(1.0, 2.0, 3.0))


func test_speeds_use_the_same_linear_factor() -> void:
	assert_almost_eq(WorldScale.mps_to_ups(4.0), 8.0, 1e-9, "4 m/s is 8 units/s")
	assert_almost_eq(WorldScale.ups_to_mps(8.0), 4.0, 1e-9)


# ---------------------------------------------------------------------------
# World <-> voxel
# ---------------------------------------------------------------------------

func test_world_to_voxel_floors_inside_a_cell() -> void:
	assert_eq(WorldScale.world_to_voxel(Vector3(0.0, 0.0, 0.0)), Vector3i(0, 0, 0))
	assert_eq(WorldScale.world_to_voxel(Vector3(0.999, 0.5, 0.1)), Vector3i(0, 0, 0),
			"anywhere inside cell 0 is cell 0")
	assert_eq(WorldScale.world_to_voxel(Vector3(1.0, 1.0, 1.0)), Vector3i(1, 1, 1),
			"a cell boundary belongs to the cell it starts")


func test_world_to_voxel_floors_negative_coordinates() -> void:
	# The bug this guards: truncation would map -0.5 to 0, making the world asymmetric
	# around the origin and breaking deterministic generation for negative coordinates.
	assert_eq(WorldScale.world_to_voxel(Vector3(-0.5, -0.5, -0.5)), Vector3i(-1, -1, -1))
	assert_eq(WorldScale.world_to_voxel(Vector3(-0.001, -1.0, -2.999)), Vector3i(-1, -1, -3))
	assert_eq(WorldScale.world_to_voxel_axis(-0.5), -1, "single-axis form floors too")


func test_voxel_to_world_min_is_the_cell_origin() -> void:
	assert_eq(WorldScale.voxel_to_world_min(Vector3i(0, 0, 0)), Vector3(0.0, 0.0, 0.0))
	assert_eq(WorldScale.voxel_to_world_min(Vector3i(2, 3, 4)), Vector3(2.0, 3.0, 4.0))
	assert_eq(WorldScale.voxel_to_world_min(Vector3i(-1, -1, -1)), Vector3(-1.0, -1.0, -1.0))


func test_voxel_to_world_centre_is_half_a_cell_in() -> void:
	assert_eq(WorldScale.voxel_to_world_centre(Vector3i(0, 0, 0)), Vector3(0.5, 0.5, 0.5))
	assert_eq(WorldScale.voxel_to_world_centre(Vector3i(-1, -1, -1)), Vector3(-0.5, -0.5, -0.5))


func test_voxel_round_trip_is_stable() -> void:
	for voxel in [Vector3i(0, 0, 0), Vector3i(5, -3, 12), Vector3i(-100, 64, -7)]:
		assert_eq(WorldScale.world_to_voxel(WorldScale.voxel_to_world_min(voxel)), voxel,
				"min corner maps back to its own cell")
		assert_eq(WorldScale.world_to_voxel(WorldScale.voxel_to_world_centre(voxel)), voxel,
				"centre maps back to its own cell")


func test_snapping_lands_on_the_containing_cell() -> void:
	assert_eq(WorldScale.snap_to_voxel_min(Vector3(3.7, -0.2, 9.99)), Vector3(3.0, -1.0, 9.0))
	assert_eq(WorldScale.snap_to_voxel_centre(Vector3(3.7, -0.2, 9.99)),
			Vector3(3.5, -0.5, 9.5))


# ---------------------------------------------------------------------------
# Metres <-> voxels
# ---------------------------------------------------------------------------

func test_metres_to_voxels_is_continuous() -> void:
	assert_almost_eq(WorldScale.metres_to_voxels(0.75), 1.5, 1e-9,
			"no rounding is applied for the caller")
	assert_almost_eq(WorldScale.voxels_to_metres(3.0), 1.5, 1e-9)


func test_metres_to_voxels_ceil_rounds_up_for_clearance() -> void:
	assert_eq(WorldScale.metres_to_voxels_ceil(1.7), 4,
			"a 1.7 m creature needs 4 voxels of clearance, not 3")
	assert_eq(WorldScale.metres_to_voxels_ceil(1.0), 2, "an exact fit does not gain a voxel")
	assert_eq(WorldScale.metres_to_voxels_ceil(0.1), 1)
	assert_eq(WorldScale.metres_to_voxels_ceil(0.0), 0)


# ---------------------------------------------------------------------------
# Regions
# ---------------------------------------------------------------------------

func test_aabb_bounds_cover_every_touched_cell() -> void:
	var bounds := WorldScale.aabb_to_voxel_bounds(
			AABB(Vector3(0.5, 0.5, 0.5), Vector3(2.0, 2.0, 2.0)))
	assert_eq(bounds[0], Vector3i(0, 0, 0), "start cell contains the box origin")
	assert_eq(bounds[1], Vector3i(2, 2, 2), "end cell contains the far corner")


func test_aabb_bounds_do_not_claim_a_cell_touched_only_on_its_boundary() -> void:
	# A box ending exactly at x = 2.0 touches cells 0 and 1, not cell 2.
	var bounds := WorldScale.aabb_to_voxel_bounds(
			AABB(Vector3(0.0, 0.0, 0.0), Vector3(2.0, 2.0, 2.0)))
	assert_eq(bounds[0], Vector3i(0, 0, 0))
	assert_eq(bounds[1], Vector3i(1, 1, 1))


func test_aabb_bounds_never_invert_for_a_degenerate_box() -> void:
	var bounds := WorldScale.aabb_to_voxel_bounds(
			AABB(Vector3(1.25, 1.25, 1.25), Vector3.ZERO))
	assert_eq(bounds[0], Vector3i(1, 1, 1))
	assert_eq(bounds[1], Vector3i(1, 1, 1), "max is clamped to at least min")
