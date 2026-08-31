# <Subsystem name>

> Copy this file to `docs/reference/<subsystem>.md`. Delete the guidance in angle
> brackets. Keep it short: a note is a contract input, not an essay.

| Field | Value |
|---|---|
| Subsystem | `<world / entity / ai / combat / inventory / quest / ui / net>` |
| Reference source | `<cube/... and/or server/... paths actually read>` |
| Read on | `<YYYY-MM-DD>` |
| Overall confidence | `<HIGH / MEDIUM / LOW>` |
| Backlog bricks | `<IDs this note informs>` |
| Godot contract | `<file(s) implementing it, once they exist>` |

## 1. Scope

<One paragraph: what this note covers, and explicitly what it does not.>

## 2. Sources examined

| Path | What was read | Notes |
|---|---|---|
| `server/world/Zone.h` | full | class layout only |
| `server/world/Zone.cpp` | 3 methods | rest not needed |

<List only what was actually read. "Read the minimum necessary" is auditable here.>

## 3. Observed behavior

<Numbered, one claim per line, each with a confidence tag. A claim is about what the
system does — not about how the decompiled code is written.>

1. `HIGH` — <claim>
2. `MEDIUM` — <claim>
3. `LOW` — <claim>

## 4. Inputs / outputs

| Direction | Data | Confidence |
|---|---|---|
| in | | |
| out | | |

## 5. State and transitions

<States the subsystem holds, and what moves it between them. A small table or list
beats prose. Note which side owns the state: server, client, or both.>

## 6. Invariants

<Things that must always hold. These become assertions and tests.>

- `INV-1` — <invariant> — `<HIGH/MEDIUM/LOW>`

## 7. Uncertainties

<What could not be determined, and what would resolve it. Be specific: "unknown" is
not useful; "cannot tell whether X is per-tick or per-second; a playtest measuring Y
would settle it" is.>

| # | Unknown | How it could be resolved | Impact if wrong |
|---|---|---|---|
| U1 | | | |

## 8. Godot contract

<The clean design chosen in response. Not a port. State the API surface, the authority
boundary, and where determinism and replication apply.>

```text
Definition -> State -> System -> Presentation
```

| Concern | Decision |
|---|---|
| Authority | server / client / shared |
| Determinism | required / not required |
| Persistence | generated / delta / progression / not persisted |
| Replication | full / interest-scoped / event-only / none |

## 9. Deliberate divergences

<Where this project knowingly differs from the reference, and why: engine constraints,
clean-room caution, better design, or unresolvable ambiguity. This section protects
future readers from "fixing" an intentional choice.>

## 10. Tests

<Which invariants and behaviors are covered by automated tests, and what must be
verified by a human playtest (`HUMAN_REQUIRED`).>
