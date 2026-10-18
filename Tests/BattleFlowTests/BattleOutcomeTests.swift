import Testing

@testable import BattleFlow

@Suite("Battle outcomes")
struct BattleOutcomeTests {
  @Test("The engine ends a battle with a rule-defined outcome")
  func engineCustomOutcome() {
    let timeout = BattleOutcome("custom.timeout")

    let state = BattleReducer().reduce(
      state: BattleState(phase: .ongoing), action: .transitionPhase(.ended(timeout))
    ).state

    #expect(state.isBattleEnded)
    #expect(state.outcome == timeout)
    #expect(BattleState(phase: .ongoing).outcome == nil)
  }
}
