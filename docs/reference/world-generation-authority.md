# World generation authority

| Field | Value |
|---|---|
| Subsystem | `world` |
| Reference source | `server/world/World.cpp`, `cube/world/WorldInfo.cpp`, `cube/control/GameController.cpp`, `server/GAP_ANALYSIS.md` |
| Read on | `2026-09-01` |
| Overall confidence | `MEDIUM` |
| Backlog bricks | `056` (written for), `096`–`101`, `235`–`236`, `248` |
| Godot contract | `world/generation/world_seed.gd`, `docs/world-generation.md` §1 |

## 1. Scope

Answers one question and stops: `matrix-world.md` §4 **Q2** — the client binary carries
its own copy of world generation (`cube::WorldInfo`), so is "the client never generates"
safe to assume, or was that singleplayer/local-host convenience?

This note covers **who may generate world content and what that implies for authority**.
It does not cover *how* anything is generated — no noise functions, field formulas,
biome rules or structure placement. Those stay with the bricks that implement them
(060–090) and with `matrix-world.md` §2, which already indexes the evidence for them.

## 2. Sources examined

| Path | What was read | Read depth | Notes |
|---|---|---|---|
| `server/world/World.cpp` | the four sites that read the world-seed slot | `PARTIAL` | region-site and feature-cell generators; found by grep, not by reading the 6 897-line file |
| `cube/world/WorldInfo.cpp` | the one site that reads the same slot | `PARTIAL` | client biome/region content generation |
| `cube/control/GameController.cpp` | the three sites that read the same slot | `PARTIAL` | the client's copy of the region-site/feature generators, misfiled into `GameController` by binary layout |
| `server/GAP_ANALYSIS.md` | the `Server::worldUpdateSendLoop` and `Connection::receiveDispatch` rows | `GAP-ONLY` | one-line summaries only; the send loop's body (~1 900 lines) was **not** read |
| `docs/reference/matrix-world.md` | §1 `WorldInfo` row, §2 rows 1/2/5 | — | prior brick-021 mapping, not re-derived here |

## 3. Observed behavior

1. `HIGH` — Both binaries keep a **single integer world seed** in the same slot of the
   world structure, and both derive per-region generation from it the same way: the seed
   is mixed with the region's grid coordinates and pushed into the C runtime's global
   PRNG, once per region, before that region's content is placed. The client's copy of
   this mixing uses the *same* offset and stride constants as the server's — the two
   sides are reproducing one world, not two similar ones.
2. `MEDIUM` — The client therefore **reconstructs generated world content locally** from
   the shared seed rather than receiving it. `WorldInfo`'s existence is not a
   presentation cache in front of server output; it is the second half of a symmetric
   design.
3. `MEDIUM` — The attributed server→client traffic is **entity and zone state**: the
   per-client send worker walks the entity tree and pushes zone/entity updates, and the
   per-connection receive dispatch decodes packet types and applies them to the world.
   No attributed function in either binary transmits bulk voxel or terrain data. This is
   absence of evidence over a bounded read (`GAP_ANALYSIS.md` summaries plus
   `matrix-world.md` §2), not a proof that no such packet exists.
4. `LOW` — **How the client learns the seed was not found.** No attributed function
   writes the seed slot, so whether it arrives in a handshake field, a save file or a
   command-line argument is undetermined.

## 4. Inputs / outputs

| Direction | Data | Confidence |
|---|---|---|
| in | one integer world seed, held identically on both sides | `HIGH` |
| in (client) | region/zone coordinates the player is near, driving which regions are generated locally | `MEDIUM` |
| out (server→client) | entity and zone state updates; **not** generated terrain | `MEDIUM` |
| out (both, independently) | the same generated world content for the same region | `MEDIUM` |

## 5. State and transitions

| State | Owner | Note |
|---|---|---|
| world seed | both sides, identical | the only input that distinguishes one world from another |
| generated region content | both sides, computed independently | never transferred; each side recomputes it |
| entity/zone state | server, replicated to clients | the actual network payload |
| player modifications to the world | server (persisted), replicated | the part generation cannot reproduce |

There is no transition where a client's generated content becomes the server's. The two
never reconcile because the design assumes they cannot disagree.

## 6. Invariants

- `INV-1` — Both sides generate from the same seed under the same algorithm, or the
  worlds silently diverge. In the reference this is an unchecked assumption; for us it is
  a checked precondition (§8). — `HIGH`
- `INV-2` — Terrain that both sides can compute is not sent over the wire; only what
  cannot be recomputed is (entities, modifications). — `MEDIUM`

## 7. Uncertainties

| # | Unknown | How it could be resolved | Impact if wrong |
|---|---|---|---|
| U1 | How the client receives the world seed (handshake, save, argument) | Reading the connect/login path — which `matrix-client-server.md` Q3 already records as *not found in either binary* | None. Our handshake is ours to design (bricks 235–236); this note only requires that the seed be part of it. |
| U2 | Whether the original server ever re-validated a client's locally generated result | Would need the full send/receive bodies, ~1 900 lines | None. Our policy (§8) is strictly stricter than any answer here. |
| U3 | Whether a terrain-carrying packet exists that no attributed function names | A full read of `Connection::receiveDispatch`'s packet switch | Low. It would make the reference *less* reliant on client generation, which only strengthens §8. |

## 8. Godot contract

**Q2's answer: neither reading in the question is right.** Client-side generation was not
singleplayer convenience, and it was not a trust model either — it is a **bandwidth
design**. Terrain is not transmitted because both sides can compute it from one integer.
The original simply never asked whether the client's copy could be wrong.

So `"the client never generates"` must **not** be baked in as an assumption. The rule we
adopt instead is narrower and keeps `CLAUDE.md` §1 intact:

> The client may **generate**. The client never **decides**.

| Concern | Decision |
|---|---|
| Authority | server. Any gameplay-visible conclusion drawn from generated terrain — movement collision, edit validity, spawn placement, structure contents — is resolved server-side against the server's own generation, never accepted from a client. |
| Determinism | required, and **network-visible**. Determinism is not an internal nicety here: it is the reason the wire protocol can omit terrain at all. |
| Persistence | generated content is not stored (`docs/persistence.md` §5); the seed and generation version are, because they *are* the terrain. |
| Replication | `(seed, generation version)` replicate once, at session start. Generated voxels never replicate; player modifications replicate as deltas (brick 248). |

Consequences, each landing in a named brick:

- **056** — the seed is a configuration object, not a loose `int`: `WorldSeed` carries
  `(value, generation_version)` together and offers `mismatch_reason()`, the check
  `INV-1` requires. A mismatch must be a hard, explained failure at handshake time — a
  client generating from a different seed produces a world that looks right and is
  wrong, which is the worst possible failure mode.
- **096–101** — client streaming may drive local generation for presentation; the
  server keeps its own logical interest and its own generation, and the two are not
  required to be in the same place at the same time.
- **235–236** — the session handshake carries `(seed, generation version)` and refuses
  the connection on a mismatch, rather than letting play begin and diverge.

## 9. Deliberate divergences

- **The reference never verifies seed agreement; we do.** Its symmetric generation is an
  unchecked assumption that holds only because one build shipped both sides. We check it
  explicitly (`WorldSeed.mismatch_reason()`), because our client and server can be
  different builds.
- **The reference's generation is seeded into the C runtime's process-global PRNG.** We
  cannot do that and stay reproducible: it makes generation order-dependent and
  thread-hostile, and `docs/rng.md` §1 forbids process-global randomness in simulation
  code outright. Our equivalent is positional hashing (`WorldHash`), which needs no
  seeding step at all.
- **We take the behavior, not the numbers.** The reference's per-region mixing constants
  are observed, not adopted; our own region/pass separation is `WorldHash`'s salts.

## 10. Tests

- `tests/unit/test_world_seed.gd` — identity (`matches`/`mismatch_reason` over seed and
  generation version), the header round trip, and that a world keeps its own generation
  version on a newer build. Covers `INV-1`'s data half.
- `INV-1`'s enforcement half (refusing a session on mismatch) is bricks 235–236, and
  `INV-2` (no terrain on the wire) is brick 248's replication design — neither is
  testable yet, and both are named here so the check is not forgotten.
- No `HUMAN_REQUIRED` item: nothing in this note is a visual claim.
