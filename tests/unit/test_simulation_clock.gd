extends TestCase
## Covers core/time/simulation_clock.gd (brick 014).

var _clock: SimulationClock


func before_each() -> void:
	_clock = SimulationClock.new()


func test_tick_rate_matches_the_contract() -> void:
	assert_eq(SimulationClock.TICK_HZ, 60, "simulation runs at 60 Hz")
	assert_almost_eq(SimulationClock.TICK_SECONDS, 1.0 / 60.0, 1e-12)
	assert_eq(SimulationClock.TICKS_PER_SNAPSHOT, 3, "snapshots at 20 Hz")
	assert_eq(SimulationClock.MAX_CATCH_UP_TICKS, 8)


func test_starts_at_tick_zero() -> void:
	assert_eq(_clock.tick, 0)
	assert_almost_eq(_clock.elapsed_seconds(), 0.0, 1e-12)
	assert_eq(_clock.dropped_ticks(), 0)


func test_exact_step_advances_one_tick() -> void:
	assert_eq(_clock.advance(SimulationClock.TICK_SECONDS), 1)
	assert_eq(_clock.tick, 1)


func test_partial_time_does_not_advance_a_tick() -> void:
	assert_eq(_clock.advance(SimulationClock.TICK_SECONDS * 0.5), 0,
			"half a tick simulates nothing")
	assert_eq(_clock.tick, 0)

	# ...but it is not lost: the second half completes the tick.
	assert_eq(_clock.advance(SimulationClock.TICK_SECONDS * 0.5), 1)
	assert_eq(_clock.tick, 1)


func test_one_frame_can_yield_several_ticks() -> void:
	assert_eq(_clock.advance(SimulationClock.TICK_SECONDS * 3.0), 3)
	assert_eq(_clock.tick, 3)


func test_remainder_is_carried_without_drift() -> void:
	# 100 frames at 1/50 s should be exactly 120 ticks of 1/60 s. Any per-frame float
	# drift would show up as 119 or 121 here.
	var total := 0
	for _i in 100:
		total += _clock.advance(1.0 / 50.0)
	assert_eq(total, 120, "no tick is gained or lost over 2 seconds")
	assert_eq(_clock.tick, 120)


func test_elapsed_seconds_comes_from_the_tick_count() -> void:
	for _i in 60:
		_clock.advance(SimulationClock.TICK_SECONDS)
	assert_eq(_clock.tick, 60)
	assert_almost_eq(_clock.elapsed_seconds(), 1.0, 1e-9,
			"60 ticks is one second of simulated time")


func test_catch_up_is_clamped_and_counted() -> void:
	# A two-second stall would be 120 ticks; only MAX_CATCH_UP_TICKS may run.
	var steps := _clock.advance(2.0)
	assert_eq(steps, SimulationClock.MAX_CATCH_UP_TICKS, "catch-up is clamped")
	assert_eq(_clock.tick, SimulationClock.MAX_CATCH_UP_TICKS)
	assert_eq(_clock.dropped_ticks(), 120 - SimulationClock.MAX_CATCH_UP_TICKS,
			"dropped ticks are reported, not hidden")


func test_clamping_drops_the_backlog_instead_of_queueing_it() -> void:
	_clock.advance(2.0)
	# The very next ordinary frame must behave normally. If the backlog had been kept,
	# this frame would immediately clamp again — the spiral this guards against.
	var steps := _clock.advance(SimulationClock.TICK_SECONDS)
	assert_eq(steps, 1, "the frame after a stall runs a single tick")


func test_non_positive_and_non_finite_deltas_are_ignored() -> void:
	assert_eq(_clock.advance(0.0), 0)
	assert_eq(_clock.advance(-1.0), 0, "time never runs backwards")
	assert_eq(_clock.advance(NAN), 0)
	assert_eq(_clock.advance(INF), 0)
	assert_eq(_clock.tick, 0, "no bad delta moved the clock")


func test_interpolation_alpha_stays_in_range() -> void:
	assert_almost_eq(_clock.interpolation_alpha(), 0.0, 1e-12, "starts on a tick boundary")

	_clock.advance(SimulationClock.TICK_SECONDS * 0.25)
	assert_almost_eq(_clock.interpolation_alpha(), 0.25, 1e-9)

	_clock.advance(SimulationClock.TICK_SECONDS * 0.5)
	assert_almost_eq(_clock.interpolation_alpha(), 0.75, 1e-9)

	# Completing the tick resets the fraction rather than exceeding 1.
	_clock.advance(SimulationClock.TICK_SECONDS * 0.25)
	assert_in_range(_clock.interpolation_alpha(), 0.0, 1.0)


func test_snapshot_cadence_lands_on_tick_boundaries() -> void:
	var snapshot_ticks: Array[int] = []
	for _i in 9:
		_clock.advance(SimulationClock.TICK_SECONDS)
		if _clock.is_snapshot_tick():
			snapshot_ticks.append(_clock.tick)
	assert_eq(snapshot_ticks, [3, 6, 9] as Array[int],
			"a snapshot every third tick, on the tick")


func test_reset_restores_a_known_tick() -> void:
	_clock.advance(2.0)  # leaves a dropped-tick count behind
	_clock.reset(1000)
	assert_eq(_clock.tick, 1000, "a loaded world resumes its own tick")
	assert_eq(_clock.dropped_ticks(), 0)
	assert_almost_eq(_clock.interpolation_alpha(), 0.0, 1e-12,
			"reset lands on a clean tick boundary")


func test_seconds_to_ticks_floors_and_ceils_deliberately() -> void:
	assert_eq(SimulationClock.seconds_to_ticks(1.0), 60)
	assert_eq(SimulationClock.seconds_to_ticks(0.4), 24, "a 0.4 s cooldown is 24 ticks")
	assert_eq(SimulationClock.seconds_to_ticks(0.001), 0, "shorter than a tick floors to 0")
	assert_eq(SimulationClock.seconds_to_ticks_ceil(0.001), 1,
			"a duration that must not end early gets at least one tick")
	assert_eq(SimulationClock.seconds_to_ticks_ceil(1.0), 60, "an exact fit gains nothing")


func test_tick_and_second_conversions_round_trip() -> void:
	for ticks in [0, 1, 24, 60, 3600]:
		assert_eq(SimulationClock.seconds_to_ticks(
				SimulationClock.ticks_to_seconds(ticks)), ticks,
				"round trip for %d ticks" % ticks)


func test_two_clocks_given_the_same_deltas_agree() -> void:
	# Determinism in the small: the clock itself must not depend on anything but its
	# inputs.
	var other := SimulationClock.new()
	var deltas := [0.013, 0.0166, 0.008, 0.05, 0.0001, 0.033]
	for delta in deltas:
		assert_eq(_clock.advance(delta), other.advance(delta),
				"same delta, same tick count")
	assert_eq(_clock.tick, other.tick)
