# Logging and error conventions

Implementation: `autoload/log.gd`, autoloaded as `Log` (brick 006).

## 1. Line format

```
E/net     t=00:12.480  invalid attack command  actor=17 reason=out_of_range
│ │       │            │                       │
│ │       │            │                       └─ context, key=value, keys sorted
│ │       │            └─ message: constant text, no interpolated values
│ │       └─ uptime mm:ss.mmm since Log._ready()
│ └─ channel
└─ level tag: E W I D T
```

Variable data goes in the `context` dictionary, never in the message. This keeps a
message string greppable and lets a line be parsed mechanically. Context keys are
sorted before formatting, so identical events produce byte-identical lines — which
matters for determinism diffs (`CLAUDE.md` §1).

Floats print with 4 decimals and `Vector3` with 2, so log noise does not depend on
float printing defaults.

## 2. Levels

| Level | Use for | Also calls |
|---|---|---|
| `ERROR` | the operation failed, or an authoritative rule was violated | `push_error()` |
| `WARN` | recoverable anomaly, degraded path, suspicious input | `push_warning()` |
| `INFO` | lifecycle milestones: boot, world load, connect, save | — |
| `DEBUG` | per-system detail useful while working on that system | — |
| `TRACE` | high-frequency detail; off by default everywhere | — |

`ERROR`/`WARN` route through `push_error`/`push_warning` so the Godot debugger, the
editor, CI and the MCP capture surface them. The other levels only print, so they
never pollute the error panel.

Defaults: `INFO` in release, `DEBUG` in debug builds.

## 3. Channels

Use the `Log.CH_*` constants: `boot`, `core`, `world`, `gen`, `voxel`, `stream`,
`persist`, `entity`, `combat`, `ai`, `net`, `server`, `client`, `ui`, `test`.

A free string is accepted, but any channel used in more than one file must be added
as a constant so filtering stays discoverable.

## 4. Runtime control

```
godot --headless -- --log-level=debug
godot --headless -- --log-level=warn --log=net:trace,gen:debug
```

`--log-level=<silent|error|warn|info|debug|trace>` sets the default for every channel;
`--log=<channel>:<level>[,…]` overrides individual channels. Overrides win over the
default regardless of argument order. In code: `Log.set_default_level()` /
`Log.set_channel_level()`.

## 5. Error-handling conventions

**Programmer error vs runtime condition.** They are not logged the same way.

| Situation | Call | Behavior |
|---|---|---|
| A rule of the code was broken (impossible state, broken invariant) | `Log.invariant(cond, ch, msg, ctx)` | logs `ERROR`, then `assert` — halts in debug builds |
| Untrusted input failed validation (client command, save file, data asset) | `Log.check(cond, ch, msg, ctx)` | logs `ERROR`, returns the condition so the caller can reject and continue |
| Expected-but-notable condition | `Log.warn(...)` | logs and continues |

**Never `assert()` on client-provided data.** A malicious or out-of-date client must
not be able to halt the server; that is what `Log.check()` is for
(`CLAUDE.md` §1, server authority).

**Functions that can fail** return Godot's `Error` enum (`OK`, `ERR_*`) or a typed
result object, and log the *reason* at the point of failure — not at every level of
the call stack. Log once, at the layer that knows why.

**Silent failure is a bug.** An empty `if not ok: return` with no log is not acceptable
on the authoritative path.

## 6. Performance rules

- Never call a logging method inside a per-voxel, per-block or per-entity-per-frame
  loop above `DEBUG`.
- Guard expensive message construction:
  ```gdscript
  if Log.is_enabled(Log.CH_GEN, Log.Level.TRACE):
      Log.trace(Log.CH_GEN, "column", {"pos": pos, "profile": _dump_profile()})
  ```
  The arguments are evaluated before the call, so the level check inside `Log` cannot
  save the cost of building them.
- Generation and meshing run on worker threads. `print()` is thread-safe in Godot, but
  volume is the real cost: keep threaded logging at `DEBUG`/`TRACE` and off by default.

## 7. Tests

`Log.start_capture()` records emitted records; `Log.take_capture()` returns them as
`{level, channel, message, context}` dictionaries and stops capturing. Assert on
`channel`, `level` and `context` keys — never on the formatted string, which includes
a timestamp.
