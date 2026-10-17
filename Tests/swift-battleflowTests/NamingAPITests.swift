import Testing

@testable import swift_battleflow

// MARK: - Store & State API Tests

@Test("Store exposes action history as a property and can be reset")
@MainActor
func testStoreHistoryAndReset() async throws {
  let store = BattleFlow.makeStore()

  store.advanceTurn()
  store.advance(to: .actionExecution)
  #expect(store.actionHistory == [.incrementTurn, .transitionPhase(.actionExecution)])

  store.reset(to: BattleState(phase: .turnSelection, turnCount: 5))
  #expect(store.turnCount == 5)
  #expect(store.actionHistory.isEmpty)

  store.reset()
  #expect(store.state == BattleState())
}

@Test("JRPGBattleStore can be reset to a fresh battle")
@MainActor
func testJRPGStoreReset() async throws {
  let store = JRPGBattleFlow.makeStore()
  let hero = JRPGBattleFlow.makeCharacter(name: "Hero", isPlayer: true)

  store.startBattle(players: [hero], enemies: [])
  store.reset()

  #expect(store.state == JRPGBattleState())
  #expect(store.actionHistory.isEmpty)
}

@Test("BattleStore looks up participants by ID")
@MainActor
func testBattleStoreParticipantLookup() async throws {
  let heroID = CombatantID("hero")
  let state = BattleState().withParticipant(BattleParticipant(id: heroID), in: .players)
  let store = BattleFlow.makeStore(initialState: state)

  #expect(store.participant(for: heroID) == BattleParticipant(id: heroID))
  #expect(store.participant(for: CombatantID("ghost")) == nil)
  #expect(store.isParticipant(heroID, in: .players))
}

@Test("BattleState appends and removes pending commands")
func testBattleStateCommandTransforms() async throws {
  let state = BattleState()
    .appendingCommands([BaseCommand(id: "a")])
    .appendingCommands([BaseCommand(id: "b")])
  #expect(state.pendingCommands.map(\.id) == ["a", "b"])

  #expect(state.removingAllCommands().pendingCommands.isEmpty)
}

@Test("JRPGReducer handles AI decision requests")
func testRequestAIDecision() async throws {
  let goblin = JRPGBattleFlow.makeCharacter(name: "Goblin", isPlayer: false)
  let state = JRPGBattleState(
    phase: .turnSelection, combatants: [goblin.id: goblin], enemyIDs: [goblin.id])

  let reduction = JRPGReducer().reduce(state: state, action: .requestAIDecision(for: goblin.id))

  #expect(reduction.commands.contains { ($0 as? BaseCommand)?.id == "ai_thinking_goblin" })
}
