class_name SimulationClock
extends RefCounted
## Fixed-step clock for the authoritative simulation (backlog brick 014).
##
## The simulation advances in whole ticks of exactly `TICK_SECONDS`. A frame's real
## `delta` never reaches gameplay code: it is fed to `advance()`, which returns how many
## whole ticks to run and keeps the remainder. Two runs given the same tick sequence
## produce the same result regardless of frame rate — that is what makes the simulation
## reproducible and the server's decisions replayable.
##
## Typical use, on the authority:
##
## ```gdscript
## func _process(delta: float) -> void:
##     for _i in _clock.advance(delta):
##         _simulate_one_tick(_clock.tick)   # tick is already incremented
## ```
##
## Presentation interpolates with `interpolation_alpha()`; it never simulates.
##
## Contract and rationale: `docs/simulation-time.md`.

## Simulation ticks per second. Chosen equal to the physics tick so a character
## controller stepping in `_physics_process` and a system stepping here stay in phase.
const TICK_HZ := 60

## Duration of one tick, in seconds.
const TICK_SECONDS := 1.0 / float(TICK_HZ)

## Ticks per network snapshot: 60 / 3 = 20 Hz. Snapshot cadence is a multiple of the
## tick so a snapshot always lands on a tick boundary.
const TICKS_PER_SNAPSHOT := 3

## Upper bound on ticks executed for a single frame. A long stall (a load spike, a
## debugger breakpoint) must not queue a hundred ticks and stall the next frame too —
## that feedback loop is the classic spiral of death. Excess time is dropped and
## counted, never silently absorbed.
const MAX_CATCH_UP_TICKS := 8

## Current tick. Monotonic, starts at 0, incremented by `advance()`. At 60 Hz an int64
## counter outlives any conceivable session, so wrap-around is not a case to handle.
var tick: int = 0

## Unconsumed real time, always in `[0, TICK_SECONDS)` after `advance()` returns.
var _accumulator: float = 0.0

## Ticks discarded by catch-up clamping since construction. Non-zero means the host
## could not keep up; it is a diagnostic, not a normal condition.
var _dropped_ticks: int = 0


## Feeds real elapsed time and returns how many whole ticks to simulate now.
## `tick` has already advanced by that amount when this returns.
##
## A negative or non-finite delta is ignored: a clock that can go backwards would let a
## replay diverge, and no caller has a legitimate reason to pass one.
func advance(delta_seconds: float) -> int:
	if not is_finite(delta_seconds) or delta_seconds <= 0.0:
		return 0

	_accumulator += delta_seconds
	var steps := int(_accumulator / TICK_SECONDS)
	if steps <= 0:
		return 0

	if steps > MAX_CATCH_UP_TICKS:
		_dropped_ticks += steps - MAX_CATCH_UP_TICKS
		steps = MAX_CATCH_UP_TICKS
		# Drop the backlog rather than carrying it: keeping it would guarantee another
		# clamped frame, and the simulation is already behind wall time either way.
		_accumulator = 0.0
	else:
		_accumulator -= float(steps) * TICK_SECONDS

	tick += steps
	return steps


## Fraction of the way from the last simulated tick to the next one, in `[0, 1)`.
## Presentation interpolates between the previous and current replicated state with it.
func interpolation_alpha() -> float:
	return clampf(_accumulator / TICK_SECONDS, 0.0, 1.0)


## Ticks dropped by catch-up clamping. Log it; do not use it in simulation.
func dropped_ticks() -> int:
	return _dropped_ticks


## Seconds of simulated time elapsed since tick 0. Derived from the tick counter, never
## accumulated from deltas — summing floats every frame drifts.
func elapsed_seconds() -> float:
	return ticks_to_seconds(tick)


## Resets to a known tick. Used when loading a world, joining a server, or starting a
## deterministic test. Clears the accumulator so the next tick boundary is clean.
func reset(start_tick: int = 0) -> void:
	tick = start_tick
	_accumulator = 0.0
	_dropped_ticks = 0


## True when this tick is a snapshot tick. Keeps the cadence in one place instead of
## scattering `% 3` through the network layer.
func is_snapshot_tick() -> bool:
	return tick % TICKS_PER_SNAPSHOT == 0


static func ticks_to_seconds(ticks: int) -> float:
	return float(ticks) * TICK_SECONDS


## Whole ticks in a duration, rounded down. Use for timers expressed in seconds:
## a 0.4 s cooldown is 24 ticks.
static func seconds_to_ticks(seconds: float) -> int:
	return floori(seconds * float(TICK_HZ))


## Whole ticks covering a duration, rounded up. Use where a timer must never expire
## early — a stun that must last at least this long.
static func seconds_to_ticks_ceil(seconds: float) -> int:
	return ceili(seconds * float(TICK_HZ))
