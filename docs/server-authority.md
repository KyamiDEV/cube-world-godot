# Server authority invariants

Brick 019. Enforcement so far: `network/authority/command_gate.gd` (envelope checks),
`network/protocol/message_taxonomy.gd` (direction rules). Gameplay validation lands with
each system.

## 1. The one sentence

**The server decides what happened. The client says what it wants and shows what it is
told.**

Everything below follows from that. The invariants are numbered so a reference note, a
code comment or a review can cite one.

## 2. Invariants

| # | Invariant |
|---|---|
| `A1` | Every gameplay decision with a network-visible outcome is made on the server. |
| `A2` | A client sends **intent** only. It never sends results, state, or events. |
| `A3` | Everything arriving from a client is untrusted, including the handshake. |
| `A4` | A client may act only for entities it owns. |
| `A5` | A rejection never halts the server. Invalid input is logged and dropped. |
| `A6` | A command is validated against the authoritative state at the tick it claims, not against whatever the client asserts about that state. |
| `A7` | Server-owned RNG produces every outcome a client could benefit from predicting. |
| `A8` | A client receives only what its interest area needs. |
| `A9` | Client-side prediction is presentation. Reconciliation overwrites it without argument. |
| `A10` | Nothing observable is derived from a client's local clock. |

### A1 — Decisions are server-side

Damage, hit resolution, loot, inventory changes, quest state, XP, spawns, deaths, world
edits. If two players could ever disagree about it, the server owns it.

### A2 — Intent, not results

`AttackCommand("target 42")`, never `DamageDealtEvent(37 damage)`. The taxonomy makes
this structural: `MessageTaxonomy.is_allowed()` refuses `EVENT`, `SNAPSHOT` and `DELTA`
from a client, so the exploit has no message to arrive in.

### A3 — Untrusted means untrusted

Trust is a property of the **direction**, not of the message type or of what the client
did earlier. A peer that has behaved for an hour is exactly as untrusted as one that
just connected.

### A4 — Ownership

Ownership is resolved from authoritative state, **never read from the packet**. A packet
claiming `entity_id: 42, owner: me` proves nothing. `CommandGate.evaluate()` takes the
real owner as an argument for this reason.

### A5 — Rejections do not crash

`Log.check()` for untrusted input — logs, returns, continues. `Log.invariant()` (which
asserts) is only for programmer errors. Asserting on client data hands any client a
remote denial of service (`docs/logging-and-errors.md` §5).

### A6 — Validation is against state, not against claims

A command carries the tick it was produced for. The server evaluates it against what was
true then, within a bounded window — not against a position or a health value the client
supplied. "Client says it was in range" is not evidence.

### A7 — Server-owned randomness

Crit rolls, loot, spawn variation: all from server streams (`docs/rng.md`). A client that
can compute the outcome ahead of time can act on it.

### A8 — Interest scoping is a security boundary

Sending a client state it cannot see makes a wall-hack a matter of reading packets.
Other players' inventories, unexplored terrain, hidden spawn tables and server
bookkeeping never leave the server.

### A9 — Prediction is presentation

A client may predict its own movement to hide latency, but the server's correction wins,
always and silently. Prediction that argues with the server is a rubber-banding bug at
best and an exploit at worst.

### A10 — No client clocks

Cooldowns, durations and timeouts are server ticks. A client-supplied timestamp is data
about the client, not about the world.

## 3. Two layers of validation

Every command passes both. Keeping them separate is what stops a new command type from
quietly skipping the common checks.

**Layer 1 — envelope (`CommandGate`), identical for every command:**

| Check | Rejects | Because |
|---|---|---|
| known peer | `UNKNOWN_PEER` | a disconnected or unauthenticated peer must not slip through |
| direction | `WRONG_DIRECTION` | a client may not send authoritative kinds |
| ownership | `NOT_OWNER` | acting for someone else's character |
| tick window (past) | `TICK_TOO_OLD` | rewriting history other players have already seen |
| tick window (future) | `TICK_IN_FUTURE` | claiming to act in a time the server has not reached |
| sequence | `REPLAYED` | a captured packet resent must do nothing twice |
| rate limit | `RATE_LIMITED` | flooding |

Two deliberate properties: a **rejected command consumes neither the rate-limit budget
nor the sequence number**, so a flood of invalid packets cannot lock a peer out of
sending valid ones; and rejections are **counted by reason**, because a spike belongs in
a metric rather than in one log line per packet.

**Layer 2 — gameplay, specific to each command:** is the actor alive, in range, off
cooldown, holding the item, allowed by faction rules, within the world's editable
bounds. This lives in the systems, which by then know that the sender owns the actor and
that the tick is plausible.

## 4. Rejection is normal

Latency alone produces rejections: a command that arrives after the window, a stale
sequence after a reconnect. The server reports and continues. Only a *pattern* —
sustained `NOT_OWNER`, sustained `RATE_LIMITED` — indicates an attack, which is why the
counters exist.

## 5. Single-player

Single-player runs the same server code in-process. There is no "trusted client" mode:
one code path, one set of rules, and multiplayer bugs surface in single-player testing
instead of hiding until Phase K.
