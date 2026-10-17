import Testing

@testable import swift_battleflow

// MARK: - startBattle Contract Tests

@Test("makeCharacter accepts an explicit ID")
func testMakeCharacterExplicitID() async throws {
  let slime = JRPGBattleFlow.makeCharacter(
    name: "Slime", id: CombatantID("slime_b"), isPlayer: false)

  #expect(slime.id == CombatantID("slime_b"))
  #expect(slime.name == "Slime")
}

@Test("startBattle keeps same-named combatants with distinct IDs")
func testStartBattleWithDistinctIDs() async throws {
  let hero = JRPGBattleFlow.makeCharacter(name: "Hero")
  let slimeA = JRPGBattleFlow.makeCharacter(
    name: "Slime", id: CombatantID("slime_a"), isPlayer: false)
  let slimeB = JRPGBattleFlow.makeCharacter(
    name: "Slime", id: CombatantID("slime_b"), isPlayer: false)

  let state = JRPGReducer().reduce(
    state: JRPGBattleState(), action: .startBattle(players: [hero], enemies: [slimeA, slimeB])
  ).state

  #expect(state.combatants.count == 3)
  #expect(state.enemyIDs == [slimeA.id, slimeB.id])
}

@Test("startBattle rejects duplicate IDs within a roster")
func testStartBattleRejectsDuplicateEnemies() async {
  await #expect(processExitsWith: .failure) {
    let slime = JRPGBattleFlow.makeCharacter(name: "Slime", isPlayer: false)
    _ = JRPGReducer().reduce(
      state: JRPGBattleState(), action: .startBattle(players: [], enemies: [slime, slime]))
  }
}

@Test("startBattle rejects IDs shared by players and enemies")
func testStartBattleRejectsSharedIDs() async {
  await #expect(processExitsWith: .failure) {
    let hero = JRPGBattleFlow.makeCharacter(name: "Hero")
    let impostor = JRPGBattleFlow.makeCharacter(name: "Hero", isPlayer: false)
    _ = JRPGReducer().reduce(
      state: JRPGBattleState(), action: .startBattle(players: [hero], enemies: [impostor]))
  }
}
