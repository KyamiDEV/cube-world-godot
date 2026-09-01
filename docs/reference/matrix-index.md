# Reference matrix — index

Brick 020. Template: `_matrix_template.md`. Note template: `_template.md`.

The matrices are the bridge between the reference tree and this project: for each
`cube::` class or concept, where its behaviour goes here, which bricks consume it, and
how much of it is guesswork. Bricks 021–028 fill them in, one group at a time.

## Planned matrices

| Brick | Matrix file | Group | Reference paths | Status |
|---:|---|---|---|:---:|
| 021 | `matrix-world.md` | World, Zone, Region, Dungeon, House, Spawn, Field, Chunk, LandscapeTile, WorldMap | `*/world/` | DONE |
| 022 | `matrix-entity.md` | Creature, Sprite, SpriteManager, Speech | `*/entity/` | DONE |
| 023 | `matrix-ai.md` | the `cube::Behavior` tree | `*/ai/` | DONE |
| 024 | `matrix-combat.md` | combat resolution, damage, hit detection | `*/entity/`, `*/game_misc/` | DONE |
| 025 | `matrix-items.md` | inventory, items, equipment | `cube/ui/`, `*/entity/`, `*/db/` | DONE |
| 026 | `matrix-quests.md` | quests, NPCs, QuestText | `*/entity/`, `*/game_misc/` | DONE |
| 027 | `matrix-ui.md` | Widget classes | `cube/ui/` | TODO |
| 028 | `matrix-client-server.md` | what each binary owns, and the protocol boundary | `server/net/`, both trees | TODO |

## Ground rules

1. **The matrix is an index, not a note.** One line of role per class. Behavioural
   detail, invariants and contracts go in a per-subsystem note.
2. **Prefer the server tree for gameplay rules.** It is the authority and roughly a
   fifth of the size. Use the client tree for presentation questions
   (`docs/reference/README.md` §2).
3. **`attribution.tsv` first.** It lists every function with its owning class, so the
   shape of a subsystem is available before reading a single `.cpp`.
4. **Record what was left unread.** A later session must be able to distinguish "this
   does not exist in the reference" from "nobody has looked yet". That is what §5 of the
   template is for.
5. **Behaviour, never text.** No decompiled bodies, struct layouts, constant tables or
   asset data enters this repository (`CLAUDE.md` §16).
6. **Every class gets a row**, including the ones deliberately not reimplemented, with
   the reason. Silence is indistinguishable from an oversight.

## Scale, for planning

55 `cube::` classes in the client, 25 in the server, 23 shared — the shared set is the
game-logic core and deserves most of the reading budget. Only ~1,370 client and ~288
server functions are game code; everything else is SQLite, STL, CRT and FreeType.

## Traceability

Brick 030 builds the index from notes back to bricks. Until then, every matrix row
carries its brick IDs, and every note carries its `Backlog bricks` field — those two
fields are what 030 will read.
