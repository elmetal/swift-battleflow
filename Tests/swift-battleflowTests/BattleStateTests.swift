import Testing

@testable import swift_battleflow

// MARK: - BattleState Tests

@Test("BattleState creation with default values")
func testBattleStateCreation() async throws {
  let state = BattleState()

  #expect(state.phase == .preparation)
  #expect(state.turnCount == 0)
  #expect(state.currentActor == nil)
  #expect(state.participants.isEmpty)
  #expect(state.groups.isEmpty)
}

@Test("BattleState manages participants and groups")
func testBattleStateParticipants() async throws {
  let heroID = CombatantID("hero")
  let enemyID = CombatantID("enemy")
  let state = BattleState()
    .withParticipant(BattleParticipant(id: heroID), in: BattleGroupID("left"))
    .withParticipant(BattleParticipant(id: enemyID), in: BattleGroupID("right"))

  #expect(state.participants[heroID]?.id == heroID)
  #expect(state.participantIDs(in: BattleGroupID("left")) == Set([heroID]))
  #expect(state.participantIDs(in: BattleGroupID("right")) == Set([enemyID]))
}

@Test("Battles go from preparation to ongoing to ended")
func testBattlePhases() async throws {
  #expect(BattleState().isBattleEnded == false)
  #expect(BattleState(phase: .ongoing).isBattleEnded == false)
  #expect(BattleState(phase: .ongoing).outcome == nil)

  let ended = BattleState(phase: .ended(BattleOutcome("test.over")))
  #expect(ended.isBattleEnded)
  #expect(ended.outcome == BattleOutcome("test.over"))
}
