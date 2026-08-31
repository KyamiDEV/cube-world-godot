# `network/`

Protocol, packet definitions, replication and authority.

The protocol separates commands/intent, authoritative state, events, deltas and
snapshots. The server validates every command before applying it; clients are never
trusted for damage, inventory, quests, drops, world edits or final movement.
