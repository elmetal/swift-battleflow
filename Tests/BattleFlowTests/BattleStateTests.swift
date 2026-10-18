import Testing

@testable import BattleFlow

@Suite("Battle state")
struct BattleStateTests {
  @Test("BattleState creation with default values")
  func battleStateCreation() {
    let state = BattleState()

    #expect(state.phase == .preparation)
    #expect(state.turnCount == 0)
    #expect(state.currentActor == nil)
    #expect(state.participants.isEmpty)
    #expect(state.groups.isEmpty)
  }

  @Test("BattleState manages participants and groups")
  func battleStateParticipants() {
    let heroID = CombatantID("hero")
    let enemyID = CombatantID("enemy")
    let state = BattleState()
      .withParticipant(heroID, in: BattleGroupID("left"))
      .withParticipant(enemyID, in: BattleGroupID("right"))
      .withParticipant(CombatantID("bystander"))

    #expect(state.participants == [heroID, enemyID, CombatantID("bystander")])
    #expect(state.participantIDs(in: BattleGroupID("left")) == Set([heroID]))
    #expect(state.participantIDs(in: BattleGroupID("right")) == Set([enemyID]))
  }

  @Test("Battles go from preparation to ongoing to ended")
  func battlePhases() {
    #expect(BattleState().isBattleEnded == false)
    #expect(BattleState(phase: .ongoing).isBattleEnded == false)
    #expect(BattleState(phase: .ongoing).outcome == nil)

    let ended = BattleState(phase: .ended(BattleOutcome("test.over")))
    #expect(ended.isBattleEnded)
    #expect(ended.outcome == BattleOutcome("test.over"))
  }
}
