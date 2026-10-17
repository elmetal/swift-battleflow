import Testing

@testable import swift_battleflow

// MARK: - JRPGBattleState Group Tests

private func engineState(players: [CombatantID], enemies: [CombatantID]) -> BattleState {
  var state = BattleState()
  for id in players {
    state = state.withParticipant(BattleParticipant(id: id), in: .players)
  }
  for id in enemies {
    state = state.withParticipant(BattleParticipant(id: id), in: .enemies)
  }
  return state
}

@Test("Player and enemy IDs are derived from the engine groups")
func testGroupsDerivedFromEngineState() async throws {
  let hero = JRPGBattleFlow.makeCharacter(name: "Hero")
  let goblin = JRPGBattleFlow.makeCharacter(name: "Goblin", isPlayer: false)

  let state = JRPGBattleState(
    engineState: engineState(players: [hero.id], enemies: [goblin.id]),
    combatants: [hero.id: hero, goblin.id: goblin]
  )

  #expect(state.playerIDs == [hero.id])
  #expect(state.enemyIDs == [goblin.id])
}

@Test("Replacing the engine state keeps groups consistent")
func testWithEngineStateKeepsGroupsConsistent() async throws {
  let hero = JRPGBattleFlow.makeCharacter(name: "Hero")
  let goblin = JRPGBattleFlow.makeCharacter(name: "Goblin", isPlayer: false)
  let state = JRPGBattleState(
    combatants: [hero.id: hero, goblin.id: goblin], playerIDs: [hero.id], enemyIDs: [goblin.id])

  // The goblin switches sides in the engine state.
  let swapped = state.withEngineState(engineState(players: [hero.id, goblin.id], enemies: []))

  #expect(swapped.playerIDs == [hero.id, goblin.id])
  #expect(swapped.enemyIDs.isEmpty)
  #expect(swapped.playerIDs == swapped.engineState.participantIDs(in: .players))
}

@Test("Every combatant must be an engine participant")
func testCombatantWithoutParticipantIsRejected() async {
  await #expect(processExitsWith: .failure) {
    let hero = JRPGBattleFlow.makeCharacter(name: "Hero")
    _ = JRPGBattleState(engineState: BattleState(), combatants: [hero.id: hero])
  }
}

@Test("Every engine participant must be a combatant")
func testParticipantWithoutCombatantIsRejected() async {
  await #expect(processExitsWith: .failure) {
    let ghost = BattleState().withParticipant(BattleParticipant(id: CombatantID("ghost")))
    _ = JRPGBattleState(engineState: ghost, combatants: [:])
  }
}
