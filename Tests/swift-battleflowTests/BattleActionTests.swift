import Testing

@testable import swift_battleflow

// MARK: - Action Tests

@Test("BattleAction equality")
func testBattleActionEquality() async throws {
  let heroID = CombatantID("hero")

  #expect(BattleAction.updateCurrentActor(heroID) == .updateCurrentActor(heroID))
  #expect(BattleAction.incrementTurn != .transitionPhase(.ongoing))
}
