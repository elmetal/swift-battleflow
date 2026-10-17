import Testing

@testable import swift_battleflow

// MARK: - BattleReducer Tests

@Test("Reducer handles start battle action")
func testReducerStartBattle() async throws {
  let initialState = JRPGBattleState()

  let hero = JRPGBattleFlow.createCharacter(name: "Hero", isPlayer: true)
  let enemy = JRPGBattleFlow.createCharacter(name: "Goblin", isPlayer: false)

  let action = JRPGAction.startBattle(players: [hero], enemies: [enemy])
  let reduction = JRPGReducer().reduce(state: initialState, action: action)
  let newState = reduction.state

  #expect(newState.phase == .turnSelection)
  #expect(newState.turnCount == 1)
  #expect(newState.combatants.count == 2)
  #expect(newState.playerCombatants.count == 1)
  #expect(newState.enemyCombatants.count == 1)
  #expect(reduction.commands.isEmpty == false)
}

@Test("Reducer handles advance turn and phase change")
func testReducerAdvanceTurnAndPhase() async throws {
  let reducer = BattleReducer()
  let state = BattleState(phase: .turnSelection, turnCount: 3, currentActor: CombatantID("hero"))

  let turnReduction = reducer.reduce(state: state, action: .incrementTurn)
  #expect(turnReduction.state.turnCount == 4)
  #expect(turnReduction.state.currentActor == nil)
  #expect(turnReduction.commands.contains { ($0 as? BaseCommand)?.id == "turn_advance" })

  let phaseReduction = reducer.reduce(
    state: state, action: .transitionPhase(.actionExecution))
  #expect(phaseReduction.state.phase == .actionExecution)
  #expect(
    phaseReduction.commands.contains {
      ($0 as? BaseCommand)?.id == "phase_transition_actionExecution"
    })
}

@Test("Reducer handles attack action")
func testReducerAttack() async throws {
  let hero = JRPGBattleFlow.createCharacter(name: "Hero", hp: 100, isPlayer: true)
  let enemy = JRPGBattleFlow.createCharacter(name: "Goblin", hp: 80, isPlayer: false)

  let state = JRPGBattleState(
    combatants: [hero.id: hero, enemy.id: enemy],
    playerCombatants: [hero.id],
    enemyCombatants: [enemy.id]
  )

  let action = JRPGAction.attack(attacker: hero.id, target: enemy.id)
  let reduction = JRPGReducer().reduce(state: state, action: action)
  let newState = reduction.state

  let updatedEnemy = newState.combatants[enemy.id]!
  #expect(updatedEnemy.stats.hp == 67)  // 80 - (20 - 15 / 2) = 67
  #expect(updatedEnemy.stats.isDefeated == false)
  #expect(reduction.commands.isEmpty == false)
}

@Test("Reducer handles player escape")
func testReducerEscape() async throws {
  let hero = JRPGBattleFlow.createCharacter(name: "Mage", isPlayer: true)
  let state = JRPGBattleState(
    phase: .actionExecution,
    combatants: [hero.id: hero],
    playerCombatants: [hero.id],
    enemyCombatants: []
  )

  let escapeReduction = JRPGReducer().reduce(
    state: state, action: .escape(escaper: hero.id))
  #expect(escapeReduction.state.phase == .escape)
  #expect(escapeReduction.commands.contains { ($0 as? BaseCommand)?.id == "escape_success" })
}

@Test("Reducer handles engine actions directly")
func testReducerBattleActionDirectly() async throws {
  let reducer = BattleReducer()
  let state = BattleState(phase: .turnSelection, turnCount: 1)

  let reduction = reducer.reduce(state: state, action: BattleAction.incrementTurn)

  #expect(reduction.state.turnCount == 2)
  #expect(reduction.commands.contains { ($0 as? BaseCommand)?.id == "turn_advance" })
}

@Test("JRPGReducer handles JRPG actions directly")
func testJRPGReducerActionDirectly() async throws {
  let reducer = JRPGReducer()

  let hero = JRPGBattleFlow.createCharacter(name: "Hero", hp: 100, isPlayer: true)
  let enemy = JRPGBattleFlow.createCharacter(name: "Slime", hp: 40, isPlayer: false)
  let state = JRPGBattleState(
    combatants: [hero.id: hero, enemy.id: enemy],
    playerCombatants: [hero.id],
    enemyCombatants: [enemy.id]
  )

  let reduction = reducer.reduce(
    state: state,
    action: JRPGAction.attack(attacker: hero.id, target: enemy.id)
  )

  #expect(reduction.state.combatants[enemy.id]?.stats.hp == 27)
  #expect(
    reduction.commands.contains { ($0 as? BaseCommand)?.id == "damage_effect_\(enemy.id.value)_13" }
  )
}
