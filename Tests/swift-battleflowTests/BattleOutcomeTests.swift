import Testing

@testable import swift_battleflow

// MARK: - Battle Outcome Tests

@Test("The engine ends a battle with a rule-defined outcome")
func testEngineCustomOutcome() async throws {
  let timeout = BattleOutcome("custom.timeout")

  let state = BattleReducer().reduce(
    state: BattleState(phase: .actionExecution), action: .transitionPhase(.ended(timeout))
  ).state

  #expect(state.isBattleEnded)
  #expect(state.outcome == timeout)
  #expect(BattleState(phase: .actionExecution).outcome == nil)
}
