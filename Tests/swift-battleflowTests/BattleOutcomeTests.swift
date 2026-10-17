import Testing

@testable import swift_battleflow

// MARK: - Battle Outcome Tests

@Test(
  "endBattle records every JRPG result, including draw",
  arguments: [BattleResult.victory, .defeat, .escape, .draw])
func testEndBattleRoundTripsResult(result: BattleResult) async throws {
  let reduction = JRPGReducer().reduce(state: JRPGBattleState(), action: .endBattle(result: result))

  #expect(reduction.state.phase == .ended(result.outcome))
  #expect(reduction.state.result == result)
  #expect(reduction.state.isBattleEnded)
}

@Test("JRPG results map to distinct engine outcomes")
func testResultOutcomesAreDistinct() async throws {
  let outcomes = [BattleResult.victory, .defeat, .escape, .draw].map(\.outcome)
  #expect(Set(outcomes).count == 4)
}

@Test("An ongoing JRPG battle has no result")
func testOngoingBattleHasNoResult() async throws {
  #expect(JRPGBattleState(phase: .turnSelection).result == nil)
}

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
