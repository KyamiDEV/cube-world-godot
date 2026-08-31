# `gameplay/`

Rules and state for entities, combat, stats, items and progression.

Layering (CLAUDE.md §2): `Definition -> State -> System -> Presentation`.
Definitions are data; state is plain data; systems mutate state. Systems here run
on the **server**; the client only mirrors replicated state.
