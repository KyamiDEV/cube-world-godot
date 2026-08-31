extends TestCase
## Covers network/authority/command_gate.gd (brick 019).

const PEER := 7
const OTHER_PEER := 8
const SERVER_TICK := 1000

var _gate: CommandGate
var _sequence: int


func before_each() -> void:
	_gate = CommandGate.new()
	_gate.add_peer(PEER, SERVER_TICK)
	_sequence = 0


func _next_sequence() -> int:
	_sequence += 1
	return _sequence


func _send(owner: int = PEER, command_tick: int = SERVER_TICK,
		server_tick: int = SERVER_TICK,
		kind: MessageTaxonomy.Kind = MessageTaxonomy.Kind.COMMAND) -> CommandGate.Verdict:
	return _gate.evaluate(PEER, kind, owner, command_tick, _next_sequence(), server_tick)


# ---------------------------------------------------------------------------
# The happy path
# ---------------------------------------------------------------------------

func test_a_well_formed_command_from_its_owner_is_accepted() -> void:
	assert_eq(_send(), CommandGate.Verdict.ACCEPT)


func test_a_command_acting_on_no_entity_is_accepted() -> void:
	assert_eq(_send(-1), CommandGate.Verdict.ACCEPT)


# ---------------------------------------------------------------------------
# Identity and ownership
# ---------------------------------------------------------------------------

func test_an_unknown_peer_is_refused() -> void:
	# A disconnected or unauthenticated peer must not slip a command through.
	assert_eq(_gate.evaluate(999, MessageTaxonomy.Kind.COMMAND, 999,
			SERVER_TICK, 1, SERVER_TICK), CommandGate.Verdict.UNKNOWN_PEER)


func test_acting_for_another_peers_entity_is_refused() -> void:
	# The exploit: sending a MoveCommand for someone else's character.
	assert_eq(_send(OTHER_PEER), CommandGate.Verdict.NOT_OWNER)


func test_a_kind_a_client_may_not_send_is_refused() -> void:
	# Belt and braces with the taxonomy: an EVENT from a client never reaches gameplay.
	assert_eq(_send(PEER, SERVER_TICK, SERVER_TICK, MessageTaxonomy.Kind.EVENT),
			CommandGate.Verdict.WRONG_DIRECTION)
	assert_eq(_send(PEER, SERVER_TICK, SERVER_TICK, MessageTaxonomy.Kind.SNAPSHOT),
			CommandGate.Verdict.WRONG_DIRECTION)


func test_removing_a_peer_stops_accepting_its_commands() -> void:
	_gate.remove_peer(PEER)
	assert_false(_gate.has_peer(PEER))
	assert_eq(_send(), CommandGate.Verdict.UNKNOWN_PEER)


# ---------------------------------------------------------------------------
# Timing
# ---------------------------------------------------------------------------

func test_a_command_inside_the_latency_window_is_accepted() -> void:
	# Ordinary latency: the client acted a few ticks ago.
	assert_eq(_send(PEER, SERVER_TICK - 10), CommandGate.Verdict.ACCEPT)
	assert_eq(_send(PEER, SERVER_TICK - CommandGate.DEFAULT_PAST_TICK_WINDOW),
			CommandGate.Verdict.ACCEPT, "the window edge is inclusive")


func test_a_command_older_than_the_window_is_refused() -> void:
	# Rewriting history the world has already shown to other players.
	assert_eq(_send(PEER, SERVER_TICK - CommandGate.DEFAULT_PAST_TICK_WINDOW - 1),
			CommandGate.Verdict.TICK_TOO_OLD)
	assert_eq(_send(PEER, 0), CommandGate.Verdict.TICK_TOO_OLD)


func test_a_slightly_ahead_command_is_accepted_because_clients_predict() -> void:
	assert_eq(_send(PEER, SERVER_TICK + CommandGate.DEFAULT_FUTURE_TICK_WINDOW),
			CommandGate.Verdict.ACCEPT)


func test_a_command_far_in_the_future_is_refused() -> void:
	assert_eq(_send(PEER, SERVER_TICK + CommandGate.DEFAULT_FUTURE_TICK_WINDOW + 1),
			CommandGate.Verdict.TICK_IN_FUTURE)
	assert_eq(_send(PEER, SERVER_TICK + 10000), CommandGate.Verdict.TICK_IN_FUTURE)


# ---------------------------------------------------------------------------
# Replay
# ---------------------------------------------------------------------------

func test_a_replayed_sequence_is_refused() -> void:
	assert_eq(_gate.evaluate(PEER, MessageTaxonomy.Kind.COMMAND, PEER,
			SERVER_TICK, 5, SERVER_TICK), CommandGate.Verdict.ACCEPT)
	assert_eq(_gate.evaluate(PEER, MessageTaxonomy.Kind.COMMAND, PEER,
			SERVER_TICK, 5, SERVER_TICK), CommandGate.Verdict.REPLAYED,
			"the same packet captured and resent does nothing twice")
	assert_eq(_gate.evaluate(PEER, MessageTaxonomy.Kind.COMMAND, PEER,
			SERVER_TICK, 4, SERVER_TICK), CommandGate.Verdict.REPLAYED,
			"an older sequence is stale, not a new command")


func test_sequences_advance_normally() -> void:
	for sequence in range(1, 10):
		assert_eq(_gate.evaluate(PEER, MessageTaxonomy.Kind.COMMAND, PEER,
				SERVER_TICK, sequence, SERVER_TICK), CommandGate.Verdict.ACCEPT)


func test_a_rejected_command_does_not_advance_the_sequence() -> void:
	# Otherwise one bad packet would invalidate the peer's next legitimate one.
	assert_eq(_gate.evaluate(PEER, MessageTaxonomy.Kind.COMMAND, OTHER_PEER,
			SERVER_TICK, 5, SERVER_TICK), CommandGate.Verdict.NOT_OWNER)
	assert_eq(_gate.evaluate(PEER, MessageTaxonomy.Kind.COMMAND, PEER,
			SERVER_TICK, 5, SERVER_TICK), CommandGate.Verdict.ACCEPT,
			"sequence 5 was never consumed")


# ---------------------------------------------------------------------------
# Flooding
# ---------------------------------------------------------------------------

func test_a_burst_within_one_tick_is_allowed() -> void:
	# A frame that submits several commands at once is normal input, not an attack.
	for _i in int(CommandGate.DEFAULT_BURST):
		assert_eq(_send(), CommandGate.Verdict.ACCEPT)


func test_a_flood_is_cut_off() -> void:
	for _i in int(CommandGate.DEFAULT_BURST):
		_send()
	assert_eq(_send(), CommandGate.Verdict.RATE_LIMITED,
			"the burst allowance is finite")


func test_the_budget_refills_over_time() -> void:
	for _i in int(CommandGate.DEFAULT_BURST):
		_send()
	assert_eq(_send(), CommandGate.Verdict.RATE_LIMITED)

	# One second later the peer is allowed to act again.
	var later := SERVER_TICK + SimulationClock.TICK_HZ
	assert_eq(_gate.evaluate(PEER, MessageTaxonomy.Kind.COMMAND, PEER,
			later, _next_sequence(), later), CommandGate.Verdict.ACCEPT)


func test_rejected_commands_do_not_consume_the_budget() -> void:
	# A flood of invalid packets must not lock a peer out of sending valid ones.
	for i in 200:
		_gate.evaluate(PEER, MessageTaxonomy.Kind.COMMAND, OTHER_PEER,
				SERVER_TICK, 1000 + i, SERVER_TICK)
	assert_eq(_gate.evaluate(PEER, MessageTaxonomy.Kind.COMMAND, PEER,
			SERVER_TICK, 5000, SERVER_TICK), CommandGate.Verdict.ACCEPT)


func test_peers_have_independent_budgets() -> void:
	_gate.add_peer(OTHER_PEER, SERVER_TICK)
	for _i in int(CommandGate.DEFAULT_BURST):
		_send()
	assert_eq(_send(), CommandGate.Verdict.RATE_LIMITED)
	assert_eq(_gate.evaluate(OTHER_PEER, MessageTaxonomy.Kind.COMMAND, OTHER_PEER,
			SERVER_TICK, 1, SERVER_TICK), CommandGate.Verdict.ACCEPT,
			"one peer flooding does not silence another")


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

func test_rejections_are_counted_by_reason() -> void:
	# A spike belongs in a metric, not in a log line per packet.
	_send(OTHER_PEER)
	_send(OTHER_PEER)
	_send(PEER, 0)
	assert_eq(_gate.rejection_count(CommandGate.Verdict.NOT_OWNER), 2)
	assert_eq(_gate.rejection_count(CommandGate.Verdict.TICK_TOO_OLD), 1)
	assert_eq(_gate.total_rejections(), 3)

	_gate.reset_metrics()
	assert_eq(_gate.total_rejections(), 0)


func test_verdicts_have_names_for_logging() -> void:
	assert_eq(CommandGate.verdict_name(CommandGate.Verdict.NOT_OWNER), "NOT_OWNER")
	assert_eq(CommandGate.verdict_name(CommandGate.Verdict.ACCEPT), "ACCEPT")


func test_a_custom_configuration_is_honoured() -> void:
	var strict := CommandGate.new(10.0, 2.0, 3, 1)
	strict.add_peer(PEER, SERVER_TICK)
	assert_eq(strict.evaluate(PEER, MessageTaxonomy.Kind.COMMAND, PEER,
			SERVER_TICK - 4, 1, SERVER_TICK), CommandGate.Verdict.TICK_TOO_OLD,
			"a narrower past window rejects sooner")
	assert_eq(strict.evaluate(PEER, MessageTaxonomy.Kind.COMMAND, PEER,
			SERVER_TICK, 2, SERVER_TICK), CommandGate.Verdict.ACCEPT)
	assert_eq(strict.evaluate(PEER, MessageTaxonomy.Kind.COMMAND, PEER,
			SERVER_TICK, 3, SERVER_TICK), CommandGate.Verdict.ACCEPT)
	assert_eq(strict.evaluate(PEER, MessageTaxonomy.Kind.COMMAND, PEER,
			SERVER_TICK, 4, SERVER_TICK), CommandGate.Verdict.RATE_LIMITED,
			"a smaller burst runs out sooner")
