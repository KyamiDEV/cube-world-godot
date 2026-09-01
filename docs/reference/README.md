# `docs/reference/` — reverse-engineering notes

Durable record of what was learned from the reference material, and of how much of it
we actually trust. One file per subsystem. `CLAUDE.md` §4 defines the workflow;
this file defines the artifacts.

**Nothing here is ground truth.** The reference is decompiler output: guessed types,
ambiguous control flow and inferred names. A note records a *hypothesis about
observable behavior*, with a confidence level attached.

## 1. The reference source

`reference/CubeWorld-Reversal` — a local clone of
<https://github.com/qad3n/CubeWorld-Reversal>. It is **not** committed to this
repository (`.gitignore`) and carries a `.gdignore` so the Godot editor never scans
27 MB of C++.

It is a Ghidra-recovered tree for the 2013 Alpha client (`Cube.exe`) and dedicated
server (`Server.exe`): 32-bit MSVC 2012 binaries with RTTI intact and no PDB. It does
not compile and is not the original source.

| Path | Contents |
|---|---|
| `cube/` | client |
| `server/` | dedicated server |
| `*/world/` | World, Zone, Region, Dungeon, House, Spawn, Field (client also: Chunk, ChunkBuffer, LandscapeTile, WorldInfo, WorldMap, ZoneTile) |
| `*/entity/` | Creature, Sprite, SpriteManager, Speech, QuestText |
| `*/ai/` | the `cube::Behavior` tree: Combat, Companion, RandomWalk, WalkPath, LookAtPlayer, RandomInteraction, Sequential, SpawnLocation |
| `*/db/` | `cube::Database` (SQLite glue) |
| `server/net/` | `cube::Server`, `cube::Connection` — the WinSock protocol, server only |
| `cube/ui/`, `cube/render/`, `cube/audio/`, `cube/control/` | client-only subsystems |
| `*/game_misc/` | game functions with no single owning class |
| `*/include/cube_types.h` | recovered structs and types |
| `*/_library/` | statically linked third-party code — **ignore**, it is not game logic |

Two index files per binary folder are the cheapest entry points:

- `attribution.tsv` — every function: address, name, kind, owning class.
- `GAP_ANALYSIS.md` — best-effort name, purpose and confidence for every function
  automation left as `FUN_<addr>`; the same notes appear inline as `/* [AUDIT] */`.

Scale: 55 `cube::` classes in the client, 25 in the server, 23 shared — the shared set
is the game-logic core. Only ~1,370 client and ~288 server functions are game code;
the rest is SQLite/STL/CRT/FreeType.

Out of scope for this project: `plasma::` (the original engine layer, ~95 classes),
`abstr::` (reflection), `Concurrency::` (MS PPL). Godot replaces all of it. Do not
mine `plasma::` for architecture.

## 2. How to read it efficiently

1. Start from `attribution.tsv` to find the class cluster for the subsystem.
2. Read the class `.h` first; read `.cpp` bodies only when behavior is unclear.
3. Prefer the **server** copy for gameplay rules — it is the authority and is far
   smaller. Use the client copy for presentation questions.
4. Check `GAP_ANALYSIS.md` before trusting any `FUN_`-named helper.
5. Read the minimum necessary (`CLAUDE.md` §4.2). Do not bulk-read a subsystem.

## 3. Note files

Name: `docs/reference/<subsystem>.md` — e.g. `world-zones.md`, `creature-stats.md`,
`ai-behavior-tree.md`, `net-protocol.md`. Lower-case, hyphenated, no addresses in the
filename.

Copy `_template.md` to start one. A note must answer, for the subsystem:

- what it observably does (inputs, outputs, state transitions, invariants);
- what remains unknown;
- how much we trust each claim;
- what Godot contract we chose in response, and where that contract now lives.

## 4. Confidence

Every behavioral claim carries a level, required by `CLAUDE.md` §4.5:

| Level | Means |
|---|---|
| `HIGH` | corroborated by clear, named code paths plus data or naming that agrees; a competent reader would reach the same conclusion |
| `MEDIUM` | one plausible reading of decompiled logic, with no contradicting evidence found |
| `LOW` | inferred, guessed from names or partial control flow, or reconstructed from gameplay memory |

A `LOW` claim may still be implemented — behavior has to be chosen somehow — but it
must be marked in the note and be cheap to revise. Never launder a `LOW` claim into a
`HIGH` one by restating it in a later document.

This is the baseline every note starts from. `confidence.md` (brick 029) is the full
convention: the separate read-depth axis (`FULL`/`PARTIAL`/`GAP-ONLY`/`UNREAD`), the
rule that a `GAP_ANALYSIS.md`-only claim cannot be recorded `HIGH`, how "overall
confidence" is computed for a note, and the open-question resolution lifecycle. Read it
before recording a claim that isn't a straightforward `HIGH`/`MEDIUM`/`LOW` call.

## 5. Clean-room discipline (`CLAUDE.md` §16)

- Extract **behavior**, not text. Never copy decompiled bodies, struct layouts,
  constant tables or asset data into this repository.
- A note is written in our own words and describes what the system *does*.
- Implementations are idiomatic Godot, written against the note contract — never a
  mechanical translation of C++.
- No original assets, names, trademarks or data files, here or anywhere in the repo.
- When two readings are possible and one is riskier for IP, take the other one.
- Numeric constants: prefer values we choose and tune for our own feel; record the
  reference apparent value only when the behavior is meaningless without it, and
  mark it as an observation, not as data to ship.

## 6. Traceability

Each note links the backlog bricks it informs; each brick that consumed a note names
it. `traceability.md` (brick 030) is the reverse index across all matrices and notes —
keep the `Backlog bricks` field of each note, and `traceability.md` itself, current as
notes are added.
