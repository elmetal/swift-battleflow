import Testing

@testable import swift_battleflow

@Suite("Battle store")
struct BattleStoreTests {
  @Test("BattleStore initialization")
  @MainActor
  func battleStoreInitialization() {
    let store = BattleStore()

    #expect(store.state.phase == .preparation)
    #expect(store.turnCount == 0)
    #expect(store.currentActor == nil)
    #expect(store.isBattleEnded == false)
  }

  @Test("BattleStore dispatches engine actions")
  @MainActor
  func battleStoreEngineDispatch() {
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
  func storeHistoryAndReset() {
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
  func battleStoreParticipantLookup() {
    let heroID = CombatantID("hero")
    let state = BattleState().withParticipant(
      heroID, in: BattleGroupID("players"))
    let store = BattleFlow.makeStore(initialState: state)

    #expect(store.isParticipant(heroID))
    #expect(!store.isParticipant(CombatantID("ghost")))
    #expect(store.isParticipant(heroID, in: BattleGroupID("players")))
  }
}
