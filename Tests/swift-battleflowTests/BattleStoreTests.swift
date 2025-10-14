import Testing
@testable import swift_battleflow

// MARK: - BattleStore Tests

@Test("BattleStore initialization")
@MainActor
func testBattleStoreInitialization() async throws {
    let store = BattleStore()

    #expect(store.state.phase == .preparation)
    #expect(store.currentTurn == 0)
    #expect(store.currentActor == nil)
    #expect(store.isBattleEnded == false)
}

@Test("BattleStore start battle functionality")
@MainActor
func testBattleStoreStartBattle() async throws {
    let store = BattleStore()

    let hero = BattleFlow.createCharacter(name: "Hero", isPlayer: true)
    let enemy = BattleFlow.createCharacter(name: "Goblin", isPlayer: false)

    store.startBattle(players: [hero], enemies: [enemy])

    #expect(store.currentPhase == .turnSelection)
    #expect(store.currentTurn == 1)
    #expect(store.alivePlayers.count == 1)
    #expect(store.aliveEnemies.count == 1)

    let storedHero = store.getCombatant(hero.id)
    #expect(storedHero != nil)
    #expect(storedHero?.name == "Hero")

    #expect(store.isPlayerCombatant(hero.id) == true)
    #expect(store.isEnemyCombatant(enemy.id) == true)
}

@Test("BattleStore attack functionality")
@MainActor
func testBattleStoreAttack() async throws {
    let store = BattleStore()

    let hero = BattleFlow.createCharacter(name: "Hero", hp: 100, isPlayer: true)
    let enemy = BattleFlow.createCharacter(name: "Goblin", hp: 80, isPlayer: false)

    store.startBattle(players: [hero], enemies: [enemy])
    store.performAttack(attacker: hero.id, target: enemy.id, damage: 30)

    let updatedEnemy = store.getCombatant(enemy.id)!
    #expect(updatedEnemy.stats.hp == 50)  // 80 - 30 = 50
}
