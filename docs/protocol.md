# Network protocol — message taxonomy

Brick 018. Implementations: `network/protocol/message_taxonomy.gd`,
`network/protocol/protocol_version.gd`. Authority rules: `docs/server-authority.md`
(brick 019). Transport, packet encoding and replication land in Phase K.

## 1. Six kinds, one job each

| Kind | Direction | Delivery | Carries a tick | Meaning |
|---|---|---|---|---|
| `COMMAND` | client → server | reliable ordered | yes | *intent*: "I want to move / attack / use this". Untrusted. May be rejected. |
| `EVENT` | server → client | reliable ordered | yes | something that **happened**, authoritative |
| `SNAPSHOT` | server → client | unreliable | yes | full authoritative state for the receiver's interest area at a tick |
| `DELTA` | server → client | unreliable | yes | change since an acknowledged snapshot |
| `HANDSHAKE` | both | reliable ordered | no | versions, content hashes, identity |
| `CONTROL` | both | reliable unordered | no | ping, ack, disconnect reason |

The kind decides direction, delivery and trust. Deciding those per message type instead
is how a protocol ends up with one path that forgot to validate.

## 2. Command versus event: the distinction the whole design rests on

A **command** is a wish. A client sends `AttackCommand`; the server decides whether the
attacker was alive, in range, off cooldown, and facing the target, and what the damage
actually was.

An **event** is a fact. The server sends `DamageDealtEvent`, and the client's only job is
to show it.

Therefore:

- **A client may never send an `EVENT`, `SNAPSHOT` or `DELTA`.** Accepting one hands the
  client authority over what happened — the entire "the client says it killed the boss"
  class of exploit. `MessageTaxonomy.is_allowed()` encodes this, and a message failing it
  is dropped and logged, never applied.
- **A server never sends a `COMMAND`.** The server does not ask permission; it reports.
- **Everything arriving from a client is untrusted**, including a handshake. Validation
  is not a property of a message type; it is a property of the direction.

Command names are imperative and singular:

```
MoveCommand  AttackCommand  InteractCommand  UseItemCommand  CastSkillCommand
EditBlockCommand  DropItemCommand  AcceptQuestCommand
```

Event names are past tense:

```
DamageDealtEvent  EntityDiedEvent  ItemPickedUpEvent  BlockChangedEvent
QuestCompletedEvent  LevelGainedEvent
```

If a name reads naturally in both tenses, the type is doing two jobs.

## 3. Why state is unreliable and events are not

`SNAPSHOT` and `DELTA` are **superseded by whatever comes next**. Retransmitting a stale
snapshot would fight the newer one that already arrived, and the retransmission costs
latency exactly when the connection is already struggling. Losing one costs 50 ms of
staleness.

`COMMAND` and `EVENT` are not superseded by anything. A dropped command is player input
the world silently ignored. A dropped event is a hole in the client's story — a death
that never happened, an item that vanished. Both are worth retransmitting.

A `DELTA` is sequence-checked against the snapshot it was diffed from. A gap forces a
fresh snapshot; the client never guesses at a missing delta.

## 4. Ticks

`COMMAND`, `EVENT`, `SNAPSHOT` and `DELTA` all carry the simulation tick they belong to
(`docs/simulation-time.md`). It is what lets the server place a command in time,
re-evaluate a client's claim against the state at that tick, and lets the client
interpolate between two snapshots instead of snapping.

`HANDSHAKE` and `CONTROL` sit outside the simulation and carry no tick.

## 5. Versioning and content agreement

Protocol compatibility is **exact-match**, unlike a save. A save is read once by a
process that can migrate it; a connection is a live agreement between two processes that
cannot migrate each other.

Matching the version is necessary but not sufficient. Content IDs travel as **registry
indices** (`docs/ids-and-registries.md` §2), so if the server's index 7 is a steel sword
and the client's is a healing potion, every packet parses cleanly and means the wrong
thing. The handshake therefore carries a combined content hash of every locked registry,
and a mismatch refuses the connection at connect time rather than surfacing as
inexplicable behaviour during play.

Rejections are reported with a reason. "Connection refused" alone produces a bug report
that cannot be acted on.

Bump `PROTOCOL_VERSION` on **any** change to message layout, field order, kind
numbering, or the meaning of an existing field.

## 6. What the protocol carries, and what it must not

Replicate only what a client needs for its interest area (`CLAUDE.md` §12).

Never replicate:

- state a client cannot see (other players' inventories, unexplored terrain, hidden
  spawn tables) — sending it makes a wall-hack a matter of reading packets;
- deterministic generated terrain — clients regenerate it from `(seed, generation
  version)`; only **modification deltas** travel;
- server-internal bookkeeping: RNG stream state, AI scratch data, scheduling queues.
