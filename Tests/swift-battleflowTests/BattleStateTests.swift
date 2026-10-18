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

@Test("BattleState appends and removes pending commands")
func testBattleStateCommandTransforms() async throws {
  let state = BattleState()
    .appendingCommands([BaseCommand(id: "a")])
    .appendingCommands([BaseCommand(id: "b")])
  #expect(state.pendingCommands.map(\.id) == ["a", "b"])

  #expect(state.removingAllCommands().pendingCommands.isEmpty)
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
