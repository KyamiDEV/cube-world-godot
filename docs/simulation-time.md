# Simulation and time contract

Brick 014. Implementation: `core/time/simulation_clock.gd`.

## 1. The rule

**Gameplay advances in whole fixed ticks. Frame time never reaches gameplay code.**

| Quantity | Value | Why |
|---|---|---|
| Simulation tick | **60 Hz** (`TICK_SECONDS = 1/60`) | equal to the physics tick, so a character controller in `_physics_process` and a system stepping on the clock stay in phase |
| Network snapshot | **20 Hz** (every 3rd tick) | a snapshot always lands on a tick boundary; the cadence lives in one constant |
| Catch-up limit | **8 ticks per frame** | matches `physics/common/max_physics_steps_per_frame`; prevents the spiral of death |

A tick is an integer. It starts at 0 when a world is created, is monotonic, and is the
timestamp for everything the simulation records: commands, events, cooldowns, buffs,
scheduled spawns, save files. At 60 Hz an int64 tick counter never realistically wraps.

## 2. Why fixed-step

Three properties depend on it, and all three are load-bearing for this project:

1. **Determinism.** The same command sequence over the same ticks produces the same
   world. Variable `delta` makes results frame-rate dependent, which breaks replay,
   debugging and any cross-machine agreement (`CLAUDE.md` §1).
2. **Server authority.** The server has to be able to say *when* something happened and
   to re-evaluate a client's claim against that tick. "About 16 milliseconds ago" is not
   a defensible answer to a cheating client.
3. **Reproducible bugs.** A bug that only appears at 144 fps and not at 60 is not a
   gameplay bug — it is a time-handling bug, and this contract removes the category.

## 3. Rules for system code

- **Never scale gameplay by `delta`.** Inside a tick, the step is `TICK_SECONDS`, a
  constant. `velocity * delta` in a gameplay system is a bug.
- **Never sum floats to measure time.** Accumulating `delta` drifts. Count ticks and
  convert once at the edge: `SimulationClock.ticks_to_seconds()`.
- **Never read wall-clock time for a gameplay decision.** `Time.get_ticks_msec()` is for
  profiling and logging. Cooldowns, durations and timeouts are tick deadlines:
  `expires_at_tick = tick + SimulationClock.seconds_to_ticks(0.4)`.
- **Express durations in seconds in data, ticks in state.** A definition says `0.4`;
  the state stores 24. Converting at load keeps designer-facing data readable and the
  runtime integral.
- **Round deliberately.** `seconds_to_ticks` floors; `seconds_to_ticks_ceil` rounds up.
  Use ceil where a duration must never end early (a stun, an invulnerability window).

## 4. The frame loop

```gdscript
func _process(delta: float) -> void:
    for _i in _clock.advance(delta):
        _simulate_one_tick(_clock.tick)
    _presentation.interpolate(_clock.interpolation_alpha())
```

`advance()` consumes real time, returns the number of whole ticks to run, and keeps the
remainder in `[0, TICK_SECONDS)`. Presentation renders between the last two ticks using
`interpolation_alpha()`; it never simulates and never steps the clock.

### Catch-up and dropped ticks

If a frame takes longer than 8 ticks' worth of time, the extra ticks are **dropped**,
not queued, and counted in `dropped_ticks()`. Queuing them guarantees the next frame is
also late — the simulation falls further behind every frame until it stops responding.

Dropping means simulated time runs slower than wall time during a stall. That is the
correct trade: the world stays internally consistent, and it is the server's clock, not
the wall clock, that defines when things happened. A non-zero `dropped_ticks()` is a
performance defect to log and investigate, never a normal operating condition.

## 5. Time zero and world time

- **Tick 0** is world creation. It is persisted with the world, so a reloaded world
  resumes its tick count rather than restarting — otherwise every scheduled deadline in
  the save becomes meaningless.
- **Join time.** A client joining mid-session adopts the server's tick; it does not
  start at 0. Client-side prediction runs ahead of the last acknowledged server tick;
  reconciliation is Phase K work, but the tick is already the shared vocabulary for it.
- **In-game day/night** is a separate mapping *derived* from the tick, defined with the
  day/night cycle (Phase J). Do not conflate the two: the simulation tick is a physical
  unit; the in-game clock is a presentation of it and may be scaled or paused for
  gameplay reasons without touching simulation timing.

## 6. Pausing

Pausing means not calling `advance()`. It must never mean scaling `TICK_SECONDS`: a
variable step size reintroduces exactly the non-determinism this contract removes.
Slow-motion, if it is ever wanted, is achieved by running fewer ticks per second of wall
time, not by making a tick shorter.

Single-player pause is a client convenience. On a server, pausing is a global authority
decision and stops the world for every connected client.

## 7. What is out of scope here

Threading, job scheduling and the order in which systems run within one tick are
separate concerns (system ordering lands with the server simulation loop, Phase K).
This contract fixes only *when* a tick happens and *how long* it is.
