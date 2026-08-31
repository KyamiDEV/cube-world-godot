# Reference matrix — `<subsystem group>`

> Copy to `docs/reference/matrix-<group>.md`. One matrix per mapping brick (021–028).
> The matrix is an **index**, not a note: it says what exists and where it went. The
> behavioural detail lives in the per-subsystem notes made from `_template.md`.

| Field | Value |
|---|---|
| Group | `<world / entity / ai / combat / inventory / quest / ui / client-server split>` |
| Backlog brick | `<021…028>` |
| Mapped on | `<YYYY-MM-DD>` |
| Sources read | `<attribution.tsv rows, headers, specific .cpp methods>` |
| Coverage | `<n of m classes in this group placed>` |

## 1. Class map

One row per `cube::` class in the group. **Placed** is where the behaviour goes in this
project — a directory from `CLAUDE.md` §3, not a file that may not exist yet.

| Reference class | Binary | Role (one line, our words) | Placed | Bricks | Confidence | Note |
|---|:---:|---|---|---|:---:|---|
| `cube::Zone` | both | fixed-size horizontal region owning spawns and terrain metadata | `world/regions/` | 060–067 | MEDIUM | `world-zones.md` |
| `cube::Chunk` | client | client-side terrain block cached for rendering | `world/streaming/` | 096–100 | LOW | — |

Rules for the table:

- **Role is written in our own words**, describing observable behaviour. Never paste a
  decompiled signature, a struct layout or a constant table (`CLAUDE.md` §16).
- **Binary** is `client`, `server`, or `both`. A class present in both is game-logic
  core and worth more attention than a client-only one.
- **Confidence** is `HIGH` / `MEDIUM` / `LOW` for the *role claim in this row*, not for
  the subsystem as a whole.
- **Note** links the per-subsystem note once one exists; `—` while the row is only an
  index entry.
- A class deliberately **not** reimplemented gets a row with `Placed = NONE` and a
  reason. Silence is indistinguishable from an oversight.

## 2. Concepts with no single class

Behaviour that lives in `game_misc/`, is spread across several classes, or exists only
as a data pattern. These are the rows most likely to be missed by a class-by-class read.

| Concept | Evidence | Placed | Bricks | Confidence |
|---|---|---|---|:---:|
| | | | | |

## 3. Deliberately out of scope

| Reference area | Why it is not reimplemented |
|---|---|
| `plasma::*` | the original engine layer; Godot replaces it entirely |
| `abstr::*` | reflection/binding layer with no gameplay meaning |
| `_library/*` | third-party code (SQLite, STL, CRT, FreeType) |
| | |

## 4. Open questions

Questions this mapping raised that a later note must answer. Each becomes an
uncertainty row (`_template.md` §7) in the note that resolves it.

| # | Question | Blocks | Resolved by |
|---|---|---|---|
| Q1 | | | |

## 5. Reading budget

What was actually read, so a later session can tell "not present" from "not yet read"
(`CLAUDE.md` §4.2).

| Path | Depth | Left unread |
|---|---|---|
| `server/world/attribution.tsv` | full | — |
| `server/world/Zone.cpp` | 3 methods | the rest |
