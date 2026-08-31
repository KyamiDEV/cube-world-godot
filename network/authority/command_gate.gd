class_name CommandGate
extends RefCounted
## Envelope-level validation every client command passes before any gameplay code sees
## it (backlog brick 019).
##
## This is the first of the two authority checks. It answers "may this peer have sent
## this, now?" — direction, ownership, timing, replay and flooding — using only the
## envelope. The second check is gameplay validation: whether the action is legal given
## the world state (in range, off cooldown, item held), and that lives in the systems.
##
## Keeping them separate matters. Envelope checks are identical for every command, so
## implementing them once here means a new command type cannot forget them; and a
## gameplay system that only ever receives commands from their rightful owner, in a
## plausible tick, is much simpler to reason about.
##
## A rejection is **never** an assertion. A malicious or out-of-date client must not be
## able to halt the server (`docs/logging-and-errors.md` §5), so every rejection returns
## a verdict the caller reports and drops.
##
## Invariants: `docs/server-authority.md`.

enum Verdict {
	ACCEPT,
	## The kind may not travel client -> server at all (an EVENT, say).
	WRONG_DIRECTION,
	## The peer does not own the entity the command acts for.
	NOT_OWNER,
	## Older than the accepted window: the server has already simulated past it.
	TICK_TOO_OLD,
	## Ahead of the server: a client claiming to act in the future.
	TICK_IN_FUTURE,
	## Sequence number already seen, or out of order.
	REPLAYED,
	## The peer is sending faster than the allowed rate.
	RATE_LIMITED,
	## The peer is unknown to the gate.
	UNKNOWN_PEER,
}

## How far behind the server tick a command may be and still apply. Wide enough to cover
## ordinary latency and jitter, narrow enough that a client cannot rewrite history it has
## already seen the consequences of. 20 ticks at 60 Hz is about a third of a second.
const DEFAULT_PAST_TICK_WINDOW := 20

## How far ahead a command may claim to be. Small: a client running slightly ahead of the
## server is normal with prediction; a client far ahead is either broken or lying.
const DEFAULT_FUTURE_TICK_WINDOW := 4

## Sustained commands per second one peer may send. Well above what input produces at
## 60 Hz, low enough that a flood is cut off early.
const DEFAULT_COMMANDS_PER_SECOND := 120.0

## Burst allowance, so a legitimate frame that submits several commands at once is not
## penalised.
const DEFAULT_BURST := 30.0

var _past_window: int
var _future_window: int
var _commands_per_second: float
var _burst: float

## peer_id -> {tokens: float, last_tick: int, last_sequence: int}
var _peers: Dictionary = {}

## Rejections since construction, by verdict. A spike is an attack or a bug, and either
## way it belongs in a metric rather than in a log line per packet.
var _rejections: Dictionary = {}


func _init(commands_per_second: float = DEFAULT_COMMANDS_PER_SECOND,
		burst: float = DEFAULT_BURST,
		past_window: int = DEFAULT_PAST_TICK_WINDOW,
		future_window: int = DEFAULT_FUTURE_TICK_WINDOW) -> void:
	_commands_per_second = commands_per_second
	_burst = burst
	_past_window = past_window
	_future_window = future_window


## Starts tracking a peer. A peer must be added before its commands are accepted, so a
## disconnected or unauthenticated peer cannot slip a command through.
func add_peer(peer_id: int, server_tick: int) -> void:
	_peers[peer_id] = {
		"tokens": _burst,
		"last_tick": server_tick,
		"last_sequence": -1,
	}


func remove_peer(peer_id: int) -> void:
	_peers.erase(peer_id)


func has_peer(peer_id: int) -> bool:
	return _peers.has(peer_id)


## Evaluates one incoming command envelope.
##
## `owner_peer_id` is who actually owns the entity the command acts for, resolved by the
## caller from authoritative state — never taken from the packet. Pass -1 for a command
## that acts on no entity.
##
## Accepting consumes a rate-limit token and advances the peer's sequence; rejecting
## does neither, so a flood of invalid packets cannot exhaust a peer's own budget and
## lock it out.
func evaluate(peer_id: int, kind: MessageTaxonomy.Kind, owner_peer_id: int,
		command_tick: int, sequence: int, server_tick: int) -> Verdict:
	if not _peers.has(peer_id):
		return _reject(Verdict.UNKNOWN_PEER)

	if not MessageTaxonomy.is_allowed(kind, MessageTaxonomy.Direction.CLIENT_TO_SERVER):
		return _reject(Verdict.WRONG_DIRECTION)

	if owner_peer_id != -1 and owner_peer_id != peer_id:
		return _reject(Verdict.NOT_OWNER)

	if command_tick < server_tick - _past_window:
		return _reject(Verdict.TICK_TOO_OLD)
	if command_tick > server_tick + _future_window:
		return _reject(Verdict.TICK_IN_FUTURE)

	var peer: Dictionary = _peers[peer_id]
	if sequence <= int(peer["last_sequence"]):
		return _reject(Verdict.REPLAYED)

	_refill(peer, server_tick)
	if float(peer["tokens"]) < 1.0:
		return _reject(Verdict.RATE_LIMITED)

	peer["tokens"] = float(peer["tokens"]) - 1.0
	peer["last_sequence"] = sequence
	return Verdict.ACCEPT


## Number of rejections recorded for a verdict.
func rejection_count(verdict: Verdict) -> int:
	return int(_rejections.get(verdict, 0))


func total_rejections() -> int:
	var total := 0
	for verdict in _rejections:
		total += int(_rejections[verdict])
	return total


func reset_metrics() -> void:
	_rejections.clear()


static func verdict_name(verdict: Verdict) -> String:
	return Verdict.keys()[verdict]


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _refill(peer: Dictionary, server_tick: int) -> void:
	var elapsed_ticks := server_tick - int(peer["last_tick"])
	if elapsed_ticks <= 0:
		# Several commands in one tick are normal; the burst allowance covers them.
		return
	var gained := SimulationClock.ticks_to_seconds(elapsed_ticks) * _commands_per_second
	peer["tokens"] = minf(float(peer["tokens"]) + gained, _burst)
	peer["last_tick"] = server_tick


func _reject(verdict: Verdict) -> Verdict:
	_rejections[verdict] = int(_rejections.get(verdict, 0)) + 1
	return verdict
