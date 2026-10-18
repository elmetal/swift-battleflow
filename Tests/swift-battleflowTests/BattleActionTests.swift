import Testing

@testable import swift_battleflow

@Suite("Battle actions")
struct BattleActionTests {
  @Test("BattleAction equality")
  func battleActionEquality() {
    let heroID = CombatantID("hero")

    #expect(BattleAction.updateCurrentActor(heroID) == .updateCurrentActor(heroID))
    #expect(BattleAction.incrementTurn != .transitionPhase(.ongoing))
  }
}
