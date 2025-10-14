import Testing
@testable import swift_battleflow

// MARK: - BattleFlow Integration Tests

@Test("Full battle flow integration")
@MainActor
func testFullBattleFlow() async throws {
    let store = BattleStore()

    let hero = BattleFlow.createCharacter(name: "Hero", hp: 100, attack: 25, isPlayer: true)
    let goblin = BattleFlow.createCharacter(name: "Goblin", hp: 50, attack: 15, isPlayer: false)

    // 戦闘開始
    store.startBattle(players: [hero], enemies: [goblin])
    #expect(store.currentPhase == .turnSelection)
    #expect(store.isBattleEnded == false)

    // ヒーローがゴブリンを攻撃
    store.performAttack(attacker: hero.id, target: goblin.id, damage: 30)
    let damagedGoblin = store.getCombatant(goblin.id)!
    #expect(damagedGoblin.stats.hp == 20)  // 50 - 30 = 20

    // もう一度攻撃してゴブリンを倒す
    store.performAttack(attacker: hero.id, target: goblin.id, damage: 25)
    let defeatedGoblin = store.getCombatant(goblin.id)!
    #expect(defeatedGoblin.stats.hp == 0)  // 20 - 25 = 0 (min)
    #expect(defeatedGoblin.stats.isDefeated == true)

    // 戦闘終了
    store.endBattle(with: .victory)
    #expect(store.currentPhase == .victory)
    #expect(store.isBattleEnded == true)
}

@Test("BattleFlow factory methods")
@MainActor
func testBattleFlowFactory() async throws {
    let store = BattleFlow.createStore()
    #expect(store.currentPhase == .preparation)

    let hero = BattleFlow.createCharacter(name: "Test Hero", hp: 150, mp: 75, attack: 30)
    #expect(hero.name == "Test Hero")
    #expect(hero.id.value == "test_hero")
    #expect(hero.stats.hp == 150)
    #expect(hero.stats.maxHP == 150)
    #expect(hero.stats.mp == 75)
    #expect(hero.stats.attack == 30)
    #expect(hero.isPlayerControlled == true)
}
