# Reference matrix — `client-server split`

| Field | Value |
|---|---|
| Group | `client-server split` — what each binary owns, and the protocol boundary |
| Backlog brick | `028` |
| Mapped on | `2026-09-01` |
| Sources read | `server/net/Server.h`, `server/net/Connection.h` (full, both tiny); `server/attribution.tsv` and `cube/attribution.tsv` full unique-class diff (`comm` of the `kind=game` class column, both binaries) to build the shared/client-only/server-only split; `server/GAP_ANALYSIS.md` full-text grepped `socket\|winsock\|send\|recv\|packet\|opcode` (`## Connection (10)`, `## Server (2)` sections read in full; ~15 additional matched rows read with context); `cube/GAP_ANALYSIS.md` full-text grepped `socket\|winsock\|send\|recv\|packet\|ws2_32` (~25 matched rows, `net::Connection::recv_delta_*`/`EntityState_*` cluster read in full with context); `cube/control/Controller.h` (full, 15 lines); `cube/control/GameController.h` (header only, first 60 of 627 lines — the rest is unread, see `matrix-items.md` §4 Q1 / `matrix-ui.md` §4 Q2); a ~140-line window of `server/world/World.cpp` around the two call sites of `readCombatActionFromStream`/`readHitFromStream` (resolves `matrix-combat.md` §4 Q1, see §4 below); the four `Global::*` inline-comment definitions of `World_deserializeZonePacket`, `Server_worldUpdateSendLoop`, `Connection_receiveDispatch`, `ws2_32_send_all` and their two `std::_Func_impl<..._Callable_obj<lambda_...>>::vfunc_2` call sites in `server/_library/crt_stl.cpp` (grepped by name, ~90 lines read) |
| Coverage | 2 of 2 dedicated network classes placed (`cube::Server`, `cube::Connection`, both server-only); 9 "concept with no single class" rows for the actual protocol boundary; a full client/server class-ownership table (21 shared, 35 client-only, 2 server-only) |

## 1. Class map

Only two `cube::` classes are dedicated to networking, and both are server-only —
`cube/` (the client binary) has **no `net/` directory and no networking class at all**.
Both headers are tiny (`Server.h`: 1 ctor + 1 vfunc; `Connection.h`: ctor/dtor/vfunc plus
seven `buyNodeN` list-allocator helpers) and their own attributed functions are
container/string plumbing, not protocol logic. The actual send/receive/serialize
behaviour *is* named after these classes in `GAP_ANALYSIS.md` (`Server::
worldUpdateSendLoop`, `Connection::receiveDispatch`) but the automated attribution pass
filed the defining functions under `Global` (no owning class) inside
`server/_library/crt_stl.cpp` — the library dump, not `server/net/*.cpp` — because they
are free functions with no vtable slot. Placement below follows the GAP naming (what the
function *is*), not the attribution tool's `kind`/`target` columns (where it physically
landed).

| Reference class | Binary | Role (one line, our words) | Placed | Bricks | Confidence | Note |
|---|:---:|---|---|---|:---:|---|
| `cube::Server` | server | connection-acceptor/session container; its own 5 attributed functions are two `std::string` helpers plus ctor/vfunc stubs — no accept-loop or listen-socket logic survived attribution | `network/server/` | 233, 253 | LOW (own functions); see §2 for the send-loop behaviour named after this class | — |
| `cube::Connection` | server | per-client connection object; its own 13 attributed functions are ctor/dtor plus 7 sized list-node allocators (`buyNode16`…`buyNode296`) for the ~13 lists/trees it owns — no send/recv logic survived attribution on the class itself | `network/server/` | 235, 254, 256 | LOW (own functions); see §2 for the recv-dispatch behaviour named after this class | — |

No client-side networking class exists. `GameController` (client, 620 attributed
functions — already the largest class in either binary, see `matrix-items.md` §4 Q1)
owns the only class-level touchpoint found: `GameController_disconnect` (§2). Everything
else on the client side is unattributed free functions (§2).

## 2. Concepts with no single class

| Concept | Evidence | Placed | Bricks | Confidence |
|---|---|---|---|:---:|
| Per-connection send worker (paced, authoritative push) | `Server::worldUpdateSendLoop` (`server/_library/crt_stl.cpp:14973`, GAP med: "Per-client send worker: timeGetTime pacing, walk entity tree, push zone/entity updates"); wrapped in its own `std::function` lambda thunk (`crt_stl.cpp:16871-16881`), a separate thunk from the receive side — i.e. one worker per direction, not one request/reply loop | `network/server/`, `server/simulation/` | 246–249, 261 (snapshot cadence) | MEDIUM (GAP med, corroborated independently by the separate-thunk call graph — not in the original brick-024 evidence) |
| Per-connection receive dispatch | `Connection::receiveDispatch` (`crt_stl.cpp:16431`, GAP med: "Recv loop (Ordinal_16) + switch on packet type, decode and apply to world"); its own lambda thunk (`crt_stl.cpp:16902-16912`), confirming send and receive run as two independent workers per connection | `network/server/` | 235, 237–243, 254 | MEDIUM (GAP med, corroborated by the same call-graph evidence as above) |
| Entity full-state / delta-state serialization | `EntityData::serializeToStream` (writes every Entity field, ~0x1180 bytes, into a growable send buffer via typed primitive writers) and `EntityData::writeDelta` (same struct, but only fields flagged changed by a `param_4` changed-flag) — two distinct entry points for two distinct payload shapes | `network/protocol/`, `network/replication/` | 244 (snapshot schema), 250 (inventory delta) | MEDIUM (GAP med); shape directly corroborates the already-implemented `SNAPSHOT` (full state) / `DELTA` (changed-since) kinds in `docs/protocol.md` §1 — independently designed, now independently confirmed |
| Zone/chunk update packet | `World::deserializeZonePacket` (`crt_stl.cpp:10741`, GAP med: "Read zone/chunk update packet: entity(0x118) list + hit(0x14) list into world") — one packet type carries both entity updates and hit records together, not two separate messages | `network/replication/` | 246, 248, 249 | MEDIUM (GAP med) |
| Combat action / hit-record stream readers — **resolves `matrix-combat.md` §4 Q1** | `readCombatActionFromStream`/`readHitFromStream` (`server/world/World.cpp:162,269`) are each called immediately after `SpeechDb_loadBlobToVector(...)` (`World.cpp:6276→6287`, `6354→6363`), whose lookup key is built a few lines earlier from the string literals `"mission"`/`"monster"` concatenated with integer IDs (`World.cpp:6263-6268`, `6342-6346`) — i.e. these deserialize a **quest/mission-scripted combat-trigger record keyed by mission+monster id, loaded from the SQLite DB**, not a live socket packet. `GAP_ANALYSIS.md`'s one-line description ("recv buffer") uses "buffer" generically for any in-memory byte buffer, including a blob-loader's output — it is not, on its own, evidence of a network origin. The `matrix-combat.md` Q1 "prefigures the wire format" branch is therefore **not** supported; the "quest-script trigger data" branch is | `gameplay/quests/` (scripted combat-trigger data), cross-ref `network/replication/` only for the *unrelated* live combat-event replication that bricks 249/251 must still design fresh | 249, 251 (design fresh, no reference wire format to reuse); 205–210 (quest data, if mission-scripted combat triggers are wanted) | HIGH (call-site read, not a GAP one-liner) |
| Client-side dirty-bit field receive | `net::Connection::recv_delta_i8`/`_i16`/`_i32`/`_recv_delta_struct20` (`cube/GAP_ANALYSIS.md:1383-1389`, each: "If dirty bit set, recv N bytes via ws2_32 recv") — all four attributed `kind=lib, target=other`, i.e. invisible to a class-based read; found only by grepping for `recv`/`socket` | `network/client/` | 244, 245 | MEDIUM (GAP med, 4 independent rows with the same shape) |
| Client-side entity-state deserialize/receive masters | `EntityState_deserializeFromBuffer` and `EntityState_recvFromSocket` (`cube/GAP_ANALYSIS.md:1406-1407`) — two master entry points walking the same field list, one from an already-received buffer, one reading the socket directly field-by-field; ~10 `EntityState_deserializeField_size*`/`EntityState_recvField_size*` helper pairs beneath them, each gated by the same per-field dirty bit as the server's `writeDelta` | `network/client/` | 244, 245 | MEDIUM (GAP med) |
| Client network lifecycle | `GameController_disconnect` (`cube/GAP_ANALYSIS.md:2909`, GAP med: "Network disconnect: close socket/threads, print 'Disconnected.', add chat line, clear player list") — the one class-attributed network touchpoint on the client, and it lives on `GameController`, continuing the same pattern already seen three times (`matrix-items.md`, `matrix-quests.md`, `matrix-ui.md`): the client's actual framework code (here: network lifecycle) is filed under `GameController`, never a dedicated class | `network/client/`, `client/ui/` (disconnect UI feedback) | 235, 256 | MEDIUM |
| Client world/entity-state apply | `GameWorld::deserialize_state` (`cube/GAP_ANALYSIS.md:3459`, GAP low: "deserialize world/entity state from packet buffer") — attributed to `Creature` by the tool despite the `GameWorld::` name in its own proposed label, almost certainly a misattribution by physical proximity (same pattern as `Interface`'s misfiled combat formulas in `matrix-ui.md` §1) | `network/client/`, `world/streaming/` | 244, 246 | LOW (GAP low, and the class attribution itself is contradicted by the function's own proposed name) |

## 3. Deliberately out of scope

| Reference area | Why it is not reimplemented |
|---|---|
| `plasma::*` | the original engine layer; Godot replaces it entirely |
| `abstr::*` | reflection/binding layer with no gameplay meaning |
| `_library/*` | third-party code (SQLite, STL, CRT, FreeType) — note that the four networking functions in §2 are physically *inside* `server/_library/crt_stl.cpp` despite being game code, not library code; they are placed by GAP name, not by file location |
| `ws2_32_send_all` / `net::send_all` (both binaries, raw winsock `send()`/`recv()` retry loops) | thin transport-layer plumbing; Godot's own high-level networking (`ENetMultiplayerPeer` / `WebSocketPeer` / `StreamPeerTCP`) replaces a hand-rolled send-until-complete loop outright — brick 232 (transport abstraction) already exists and does not need this reference |
| Connection establishment / login / handshake | grepped for in both `GAP_ANALYSIS.md` files (`connect`, `login`, `handshake`, `accept`, `listen`) — **no matching function was found in either binary's attributed or GAP-named function set.** Either it was never recovered by the decompiler pass, or it lives entirely inside the unattributed `lib/other` mass with no name to grep for. `docs/protocol.md` §5's `HANDSHAKE` kind was designed independently and has no reference behaviour to corroborate or contradict it — this is a genuine gap in the source material, not a "not yet read" note |

## 4. Open questions

| # | Question | Blocks | Resolved by |
|---|---|---|---|
| Q1 (closed this brick) | `matrix-combat.md` §4 Q1 — is `readCombatActionFromStream`/`readHitFromStream` quest-script data or a live wire format? | 136, 137, 249, 251 | **Resolved here** (§2, "Combat action / hit-record stream readers"): quest/mission-scripted DB records, not network traffic. `matrix-combat.md` §4 should have its "Resolved by" cell updated to point at this file. |
| Q2 (closed this brick) | `matrix-items.md` §4 Q1 / `matrix-ui.md` §4 Q2 — does `GameController` (620 functions, no owning matrix) need a dedicated matrix or brick? | 224–231 | **Resolved here, by decision, not new evidence**: no. This is the fourth matrix (after items, quests, ui) to find `GameController` acting as the catch-all for a subsystem that has nothing to do with the others — inventory-grid rebuild, NPC/quest interaction, widget-tree/mouse routing, and now (§2 above) network lifecycle. The pattern is the same one already applied to `World` (021), `Creature` (022) and the `Behavior` tree (023): a god-object whose *functions* are split across the matrices/directories that actually own each behaviour, with no matrix or brick for the class shell itself. No brick is inserted; `GameController`'s remaining unread ~560 functions (the bulk of `GameController.h`/`.cpp`) are read only on demand, by whichever future brick's functional area needs them. |
| Q3 | Neither binary's attributed/GAP-named function set contains a connect/login/handshake function (§3). Is this truly absent from the recovered binaries (plausible — connection setup may be simple enough that Ghidra's analysis folded it into an unnamed `FUN_` the automation never scored), or would a targeted read of `server/net/Server.cpp`'s raw (unattributed) body find it? | 235, 236 | a targeted raw read of `server/net/Server.cpp` before brick 235/236, only if `docs/protocol.md`'s independently-designed handshake needs reference corroboration — not required by the clean-room policy (`CLAUDE.md` §16), so may simply stay closed by design decision |

## 5. Reading budget

| Path | Depth | Left unread |
|---|---|---|
| `server/net/Server.h`, `server/net/Connection.h` | full (both files, 27 lines total) | — |
| `server/attribution.tsv`, `cube/attribution.tsv` | full unique-class diff (`kind=game` column only) | per-function rows outside the class-name column |
| `server/GAP_ANALYSIS.md` | grepped `socket\|winsock\|send\|recv\|packet\|opcode`; `## Connection (10)`, `## Server (2)` sections read in full | the remaining ~1,500 rows outside the grep |
| `cube/GAP_ANALYSIS.md` | grepped `socket\|winsock\|send\|recv\|packet\|ws2_32`; the `net::Connection`/`EntityState_*` cluster (lines 1375-1407) read in full with surrounding context | the remaining ~3,400 rows outside the grep |
| `server/_library/crt_stl.cpp` | grepped by function name for the 4 networking functions named in GAP (`World_deserializeZonePacket`, `Server_worldUpdateSendLoop`, `Connection_receiveDispatch`, `ws2_32_send_all`) plus their two lambda-thunk call sites (~90 lines total) | the rest of this 56,000+-line file |
| `server/world/World.cpp` | a ~140-line window (6230-6370) around the two `readCombatActionFromStream`/`readHitFromStream` call sites | the rest of this file (also partially read by brick 024) |
| `cube/control/Controller.h` | full (15 lines) | — |
| `cube/control/GameController.h` | first 60 of 627 lines | the remaining ~567 lines and all of `GameController.cpp` — deliberately, per §4 Q2's resolution: read only on demand by the brick that needs a specific function |
| `cube/control`, `cube/misc` | directory listing only | file contents beyond `Controller.h`/`GameController.h` head |
