import Testing

@testable import swift_battleflow

// MARK: - Automatic Outcome Tests

private let hero = JRPGBattleFlow.makeCharacter(name: "Hero", hp: 100, attack: 500, speed: 20)
private let goblin = JRPGBattleFlow.makeCharacter(
  name: "Goblin", hp: 30, attack: 500, speed: 10, isPlayer: false)

private let reducer = JRPGReducer()

private func started(
  players: [Combatant] = [hero], enemies: [Combatant] = [goblin]
) -> JRPGBattleState {
  reducer.reduce(state: JRPGBattleState(), action: .startBattle(players: players, enemies: enemies))
    .state
}

private func reduce(_ state: JRPGBattleState, _ actions: JRPGAction...) -> JRPGBattleState {
  actions.reduce(state) { reducer.reduce(state: $0, action: $1).state }
}

@Test("Defeating the last enemy wins the battle")
func testVictory() async throws {
  let reduction = reducer.reduce(
    state: started(), action: .attack(attacker: hero.id, target: goblin.id))

  #expect(reduction.state.result == .victory)
  #expect(reduction.state.phase == .ended(.victory))
  #expect(reduction.commands.contains { $0.id == "battle_end_victory" })
}

@Test("Losing the last player loses the battle")
func testDefeat() async throws {
  let reduction = reducer.reduce(
    state: started(), action: .attack(attacker: goblin.id, target: hero.id))

  #expect(reduction.state.result == .defeat)
  #expect(reduction.commands.contains { $0.id == "battle_end_defeat" })
}

@Test("The battle continues while each side has a living combatant")
func testBattleContinues() async throws {
  let twin = JRPGBattleFlow.makeCharacter(
    name: "Goblin", id: CombatantID("goblin_b"), hp: 30, isPlayer: false)

  let state = reduce(
    started(enemies: [goblin, twin]), .attack(attacker: hero.id, target: goblin.id))

  #expect(state.combatants[goblin.id]!.stats.isDefeated)
  #expect(state.result == nil)
  #expect(state.phase == .turnSelection)
}

@Test("A side with no members never counts as defeated")
func testEmptySideDoesNotEndBattle() async throws {
  let ally = JRPGBattleFlow.makeCharacter(name: "Ally", hp: 10, maxHP: 100)
  let state = started(players: [hero, ally], enemies: [])

  let healed = reduce(state, .useItem(user: hero.id, item: .potion, target: ally.id))

  #expect(healed.combatants[ally.id]!.stats.hp == 60)
  #expect(healed.result == nil)
}

@Test("Actions that do not change combatants do not end the battle")
func testUnrelatedActionsDoNotEndBattle() async throws {
  // A state set up with every enemy already defeated.
  let fallen = goblin.withStats(goblin.stats.withHP(0))
  let state = started(enemies: [fallen])

  #expect(reduce(state, .defend(defender: hero.id)).result == nil)
  #expect(reduce(state, .engine(.incrementTurn)).result == nil)
}

@Test("Winning mid-turn skips the remaining actions")
func testVictoryEndsTurn() async throws {
  let won = reduce(
    started(),
    .select(.attack(target: goblin.id), by: hero.id),
    .select(.attack(target: hero.id), by: goblin.id),
    .executeTurn,
    .performNextAction)
  #expect(won.result == .victory)

  let reduction = reducer.reduce(state: won, action: .performNextAction)
  #expect(reduction.state == won)
  #expect(reduction.state.combatants[hero.id] == won.combatants[hero.id])
}
