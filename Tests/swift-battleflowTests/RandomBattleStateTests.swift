import Testing

@testable import swift_battleflow

// MARK: - Random Turn Order Tests

private let hero = JRPGBattleFlow.makeCharacter(name: "Hero", speed: 10)
private let mage = JRPGBattleFlow.makeCharacter(name: "Mage", speed: 20)
private let goblin = JRPGBattleFlow.makeCharacter(name: "Goblin", speed: 15, isPlayer: false)
private let twin = JRPGBattleFlow.makeCharacter(
  name: "Goblin", id: CombatantID("goblin_b"), speed: 15, isPlayer: false)

private func executed(rolls: [Double]) -> JRPGBattleState<ScriptedBattleRandomGenerator> {
  let reducer = JRPGReducer<ScriptedBattleRandomGenerator>()
  let actions: [JRPGAction] = [
    .startBattle(players: [hero, mage], enemies: [goblin, twin]),
    .select(.defend, by: hero.id),
    .select(.attack(target: goblin.id), by: mage.id),
    .select(.attack(target: hero.id), by: goblin.id),
    .select(.attack(target: hero.id), by: twin.id),
    .executeTurn,
  ]
  return actions.reduce(JRPGBattleState(random: ScriptedBattleRandomGenerator(rolls))) {
    reducer.reduce(state: $0, action: $1).state
  }
}

@Test(
  "Ties in priority and speed are broken by rolls, higher roll first",
  arguments: [
    // Rolls are drawn per living actor in ID order: goblin, goblin_b, hero, mage.
    ([0.1, 0.9, 0.5, 0.5], [CombatantID("goblin_b"), CombatantID("goblin")]),
    ([0.9, 0.1, 0.5, 0.5], [CombatantID("goblin"), CombatantID("goblin_b")]),
  ])
func testTieBreakByRoll(rolls: [Double], tied: [CombatantID]) async throws {
  let state = executed(rolls: rolls)

  #expect(state.engineState.actionOrder == [hero.id, mage.id] + tied)
}

@Test("executeTurn draws exactly one roll per living actor and keeps the rest")
func testExecuteTurnAdvancesGenerator() async throws {
  let state = executed(rolls: [0.1, 0.9, 0.5, 0.5, 0.3])

  #expect(state.random.remainingRolls == [0.3])
}

// MARK: - Generator Defaults

@Test("JRPGBattleState defaults to a seeded generator with seed 0")
func testDefaultGenerator() async throws {
  #expect(JRPGBattleState().random == SeededBattleRandomGenerator(seed: 0))
  #expect(JRPGBattleState(phase: .turnSelection).random == SeededBattleRandomGenerator(seed: 0))
}

@Test("makeStore() seeds the generator from the system")
@MainActor
func testMakeStoreSeedsFromSystem() async throws {
  // Two system seeds collide with probability 2^-64.
  #expect(JRPGBattleFlow.makeStore().state.random != JRPGBattleFlow.makeStore().state.random)
}

@Test("A store works with any generator, and reset keeps the generator")
@MainActor
func testStoreWithScriptedGenerator() async throws {
  let store = JRPGBattleFlow.makeStore(
    initialState: JRPGBattleState(random: ScriptedBattleRandomGenerator([0.5, 0.5])))

  store.startBattle(players: [hero], enemies: [goblin])
  store.select(.defend, by: hero.id)
  store.select(.defend, by: goblin.id)
  store.executeTurn()
  #expect(store.state.random.remainingRolls.isEmpty)

  store.reset()
  #expect(store.state == JRPGBattleState(random: ScriptedBattleRandomGenerator([])))
}
