import Testing

@testable import swift_battleflow

// MARK: - BattleStore Tests

@Test("BattleStore initialization")
@MainActor
func testBattleStoreInitialization() async throws {
  let store = BattleStore()

  #expect(store.state.phase == .preparation)
  #expect(store.turnCount == 0)
  #expect(store.currentActor == nil)
  #expect(store.isBattleEnded == false)
}

@Test("BattleStore dispatches engine actions")
@MainActor
func testBattleStoreEngineDispatch() async throws {
  let store = BattleStore()
  let participantID = CombatantID("hero")

  store.updateCurrentActor(to: participantID)
  #expect(store.currentActor == participantID)
  store.dispatch(.incrementTurn)

  #expect(store.currentActor == nil)
  #expect(store.turnCount == 1)
}

@Test("JRPGBattleStore start battle functionality")
@MainActor
func testJRPGBattleStoreStartBattle() async throws {
  let store = JRPGBattleStore()

  let hero = JRPGBattleFlow.makeCharacter(name: "Hero", isPlayer: true)
  let enemy = JRPGBattleFlow.makeCharacter(name: "Goblin", isPlayer: false)

  store.startBattle(players: [hero], enemies: [enemy])

  #expect(store.currentPhase == .turnSelection)
  #expect(store.turnCount == 1)
  #expect(store.alivePlayers.count == 1)
  #expect(store.aliveEnemies.count == 1)

  let storedHero = store.combatant(for: hero.id)
  #expect(storedHero != nil)
  #expect(storedHero?.name == "Hero")

  #expect(store.isPlayer(hero.id) == true)
  #expect(store.isEnemy(enemy.id) == true)
}

@Test("JRPGBattleStore attack functionality")
@MainActor
func testJRPGBattleStoreAttack() async throws {
  let store = JRPGBattleStore()

  let hero = JRPGBattleFlow.makeCharacter(name: "Hero", hp: 100, isPlayer: true)
  let enemy = JRPGBattleFlow.makeCharacter(name: "Goblin", hp: 80, isPlayer: false)

  store.startBattle(players: [hero], enemies: [enemy])
  store.performAttack(attacker: hero.id, target: enemy.id)

  let updatedEnemy = store.combatant(for: enemy.id)!
  #expect(updatedEnemy.stats.hp == 67)  // 80 - (20 - 15 / 2) = 67
}

@Test("JRPGBattleStore uses the injected reducer rules")
@MainActor
func testJRPGBattleStoreInjectedRules() async throws {
  let store = JRPGBattleStore(
    reducer: JRPGReducer(rules: JRPGRules(physicalDamage: { _, _ in 40 })))

  let hero = JRPGBattleFlow.makeCharacter(name: "Hero", isPlayer: true)
  let enemy = JRPGBattleFlow.makeCharacter(name: "Goblin", hp: 80, isPlayer: false)

  store.startBattle(players: [hero], enemies: [enemy])
  store.performAttack(attacker: hero.id, target: enemy.id)

  #expect(store.combatant(for: enemy.id)?.stats.hp == 40)
}

@Test("Store exposes action history as a property and can be reset")
@MainActor
func testStoreHistoryAndReset() async throws {
  let store = BattleFlow.makeStore()

  store.advanceTurn()
  store.advance(to: .actionExecution)
  #expect(store.actionHistory == [.incrementTurn, .transitionPhase(.actionExecution)])

  store.reset(to: BattleState(phase: .turnSelection, turnCount: 5))
  #expect(store.turnCount == 5)
  #expect(store.actionHistory.isEmpty)

  store.reset()
  #expect(store.state == BattleState())
}

@Test("JRPGBattleStore can be reset to a fresh battle")
@MainActor
func testJRPGStoreReset() async throws {
  let store = JRPGBattleFlow.makeStore()
  let hero = JRPGBattleFlow.makeCharacter(name: "Hero", isPlayer: true)

  store.startBattle(players: [hero], enemies: [])
  store.reset()

  #expect(store.state == JRPGBattleState())
  #expect(store.actionHistory.isEmpty)
}

@Test("BattleStore looks up participants by ID")
@MainActor
func testBattleStoreParticipantLookup() async throws {
  let heroID = CombatantID("hero")
  let state = BattleState().withParticipant(BattleParticipant(id: heroID), in: .players)
  let store = BattleFlow.makeStore(initialState: state)

  #expect(store.participant(for: heroID) == BattleParticipant(id: heroID))
  #expect(store.participant(for: CombatantID("ghost")) == nil)
  #expect(store.isParticipant(heroID, in: .players))
}
