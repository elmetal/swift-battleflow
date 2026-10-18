import Testing

@testable import swift_battleflow

// MARK: - BattleStore Tests

@Test("BattleStore initialization")
@MainActor
func testBattleStoreInitialization() async throws {
  let store = BattleStore()

  #expect(store.state.phase == .preparation)
  #expect(store.turnCount == 0)
  #expect(store.currentActor == nil)
  #expect(store.isBattleEnded == false)
}

@Test("BattleStore dispatches engine actions")
@MainActor
func testBattleStoreEngineDispatch() async throws {
  let store = BattleStore()
  let participantID = CombatantID("hero")

  store.updateCurrentActor(to: participantID)
  #expect(store.currentActor == participantID)
  store.dispatch(.incrementTurn)

  #expect(store.currentActor == nil)
  #expect(store.turnCount == 1)
}

@Test("Store exposes action history as a property and can be reset")
@MainActor
func testStoreHistoryAndReset() async throws {
  let store = BattleFlow.makeStore()

  store.advanceTurn()
  store.advance(to: .ongoing)
  #expect(store.actionHistory == [.incrementTurn, .transitionPhase(.ongoing)])

  store.reset(to: BattleState(phase: .ongoing, turnCount: 5))
  #expect(store.turnCount == 5)
  #expect(store.actionHistory.isEmpty)

  store.reset()
  #expect(store.state == BattleState())
}

@Test("BattleStore looks up participants by ID")
@MainActor
func testBattleStoreParticipantLookup() async throws {
  let heroID = CombatantID("hero")
  let state = BattleState().withParticipant(
    BattleParticipant(id: heroID), in: BattleGroupID("players"))
  let store = BattleFlow.makeStore(initialState: state)

  #expect(store.participant(for: heroID) == BattleParticipant(id: heroID))
  #expect(store.participant(for: CombatantID("ghost")) == nil)
  #expect(store.isParticipant(heroID, in: BattleGroupID("players")))
}
