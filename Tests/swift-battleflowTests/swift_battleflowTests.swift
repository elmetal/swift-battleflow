import Testing
@testable import swift_battleflow

// MARK: - BattleState Tests

@Test("BattleState creation with default values")
func testBattleStateCreation() async throws {
    let state = BattleState()
    
    #expect(state.phase == .preparation)
    #expect(state.turnCount == 0)
    #expect(state.currentActor == nil)
    #expect(state.combatants.isEmpty)
    #expect(state.playerCombatants.isEmpty)
    #expect(state.enemyCombatants.isEmpty)
}

@Test("Combatant creation and basic properties")
func testCombatantCreation() async throws {
    let stats = Stats(hp: 100, maxHP: 100, mp: 50, maxMP: 50, attack: 20, defense: 15, speed: 10)
    let combatant = Combatant(
        id: CombatantID("test_hero"),
        name: "Test Hero",
        stats: stats,
        isPlayerControlled: true
    )
    
    #expect(combatant.id.value == "test_hero")
    #expect(combatant.name == "Test Hero")
    #expect(combatant.stats.hp == 100)
    #expect(combatant.isPlayerControlled == true)
    #expect(combatant.stats.isDefeated == false)
}

@Test("Stats HP changes and boundaries")
func testStatsHPChange() async throws {
    let stats = Stats(hp: 100, maxHP: 100, mp: 50, maxMP: 50, attack: 20, defense: 15, speed: 10)
    
    // HP減少
    let damagedStats = stats.withHP(70)
    #expect(damagedStats.hp == 70)
    #expect(damagedStats.isDefeated == false)
    
    // HP0で戦闘不能
    let defeatedStats = stats.withHP(0)
    #expect(defeatedStats.hp == 0)
    #expect(defeatedStats.isDefeated == true)
    
    // HP上限を超えないことを確認
    let overhealedStats = stats.withHP(150)
    #expect(overhealedStats.hp == 100)
}

// MARK: - BattleAction Tests

@Test("BattleAction metadata properties")
func testBattleActionMetadata() async throws {
    let escapeAction = BattleAction.escape(escaper: CombatantID("test"))
    #expect(escapeAction.metadata.priority == .escape)
    #expect(escapeAction.metadata.isInstant == true)
    
    let attackAction = BattleAction.attack(attacker: CombatantID("a"), target: CombatantID("b"), damage: 10)
    #expect(attackAction.metadata.priority == .attack)
    #expect(attackAction.metadata.isInstant == false)
}

@Test("BattleAction classification")
func testBattleActionClassification() async throws {
    let startAction = BattleAction.startBattle(players: [], enemies: [])
    #expect(startAction.isFlowControl == true)
    #expect(startAction.isCharacterAction == false)
    
    let attackAction = BattleAction.attack(attacker: CombatantID("a"), target: CombatantID("b"), damage: 10)
    #expect(attackAction.isFlowControl == false)
    #expect(attackAction.isCharacterAction == true)
}

// MARK: - BattleReducer Tests

@Test("Reducer handles start battle action")
func testReducerStartBattle() async throws {
    let reducer = BattleReducer()
    let initialState = BattleState()
    
    let hero = BattleFlow.createCharacter(name: "Hero", isPlayer: true)
    let enemy = BattleFlow.createCharacter(name: "Goblin", isPlayer: false)
    
    let action = BattleAction.startBattle(players: [hero], enemies: [enemy])
    let (newState, effects) = reducer.reduce(state: initialState, action: action)
    
    #expect(newState.phase == .turnSelection)
    #expect(newState.turnCount == 1)
    #expect(newState.combatants.count == 2)
    #expect(newState.playerCombatants.count == 1)
    #expect(newState.enemyCombatants.count == 1)
    #expect(effects.isEmpty == false)
}

@Test("Reducer handles attack action")
func testReducerAttack() async throws {
    let reducer = BattleReducer()
    
    let hero = BattleFlow.createCharacter(name: "Hero", hp: 100, isPlayer: true)
    let enemy = BattleFlow.createCharacter(name: "Goblin", hp: 80, isPlayer: false)
    
    let state = BattleState(
        combatants: [hero.id: hero, enemy.id: enemy],
        playerCombatants: [hero.id],
        enemyCombatants: [enemy.id]
    )
    
    let action = BattleAction.attack(attacker: hero.id, target: enemy.id, damage: 25)
    let (newState, effects) = reducer.reduce(state: state, action: action)
    
    let updatedEnemy = newState.combatants[enemy.id]!
    #expect(updatedEnemy.stats.hp == 55)  // 80 - 25 = 55
    #expect(updatedEnemy.stats.isDefeated == false)
    #expect(effects.isEmpty == false)
}

@Test("Reducer handles HP change action")
func testReducerChangeHP() async throws {
    let reducer = BattleReducer()
    
    let hero = BattleFlow.createCharacter(name: "Hero", hp: 50, maxHP: 100, isPlayer: true)
    let state = BattleState(
        combatants: [hero.id: hero],
        playerCombatants: [hero.id]
    )
    
    // 回復（maxHP = 100なので80まで回復可能）
    let healAction = BattleAction.changeHP(target: hero.id, amount: 30)
    let (healedState, _) = reducer.reduce(state: state, action: healAction)
    let healedHero = healedState.combatants[hero.id]!
    #expect(healedHero.stats.hp == 80)  // 50 + 30 = 80
    
    // ダメージ
    let damageAction = BattleAction.changeHP(target: hero.id, amount: -20)
    let (damagedState, _) = reducer.reduce(state: healedState, action: damageAction)
    let damagedHero = damagedState.combatants[hero.id]!
    #expect(damagedHero.stats.hp == 60)  // 80 - 20 = 60
}

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

// MARK: - Effect Tests

@Test("Effect creation and properties")
func testEffectCreation() async throws {
    let effect = BaseEffect(id: "test_effect", priority: 5)
    
    #expect(effect.id == "test_effect")
    #expect(effect.priority == 5)
}

@Test("NoEffect implementation")
func testNoEffect() async throws {
    let noEffect = NoEffect()
    
    #expect(noEffect.id == "no_effect")
    #expect(noEffect.priority == 0)
}

// MARK: - Integration Tests

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

// MARK: - BattleFlow Factory Tests

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
