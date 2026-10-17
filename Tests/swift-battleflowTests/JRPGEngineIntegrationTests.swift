import Testing

@testable import swift_battleflow

// MARK: - JRPG / Engine Integration Tests

@Test("JRPGReducer forwards engine actions to BattleReducer")
func testJRPGReducerForwardsEngineActions() async throws {
  let hero = JRPGBattleFlow.makeCharacter(name: "Hero", isPlayer: true)
  let state = JRPGBattleState(
    phase: .turnSelection,
    combatants: [hero.id: hero],
    playerIDs: [hero.id],
    turnCount: 1,
    currentActor: hero.id
  )

  let reduction = JRPGReducer().reduce(state: state, action: .engine(.incrementTurn))

  #expect(reduction.state.turnCount == 2)
  #expect(reduction.state.currentActor == nil)
  #expect(reduction.state.combatants == state.combatants)
  #expect(reduction.state.playerIDs == state.playerIDs)
  #expect(reduction.commands.contains { ($0 as? BaseCommand)?.id == "turn_advance" })
}

@Test("Effect.map transforms the produced action")
func testEffectMap() async throws {
  let effect = Effect<BattleAction>.send(.incrementTurn).map(JRPGAction.engine)
  #expect(await effect.run() == .engine(.incrementTurn))

  let none = Effect<BattleAction>.none.map(JRPGAction.engine)
  #expect(await none.run() == nil)
}

@Test("JRPGBattleStore is the generic Store specialized for JRPGReducer")
@MainActor
func testJRPGBattleStoreIsGenericStore() async throws {
  let store: Store<JRPGReducer> = JRPGBattleStore()
  #expect(store.state == JRPGBattleState())
}

@Test("JRPGBattleStore records engine actions so history can be replayed")
@MainActor
func testJRPGBattleStoreRecordsEngineActions() async throws {
  let store = JRPGBattleStore()
  let hero = JRPGBattleFlow.makeCharacter(name: "Hero", isPlayer: true)
  let goblin = JRPGBattleFlow.makeCharacter(name: "Goblin", isPlayer: false)

  store.startBattle(players: [hero], enemies: [goblin])
  store.setCurrentActor(hero.id)
  store.performAttack(attacker: hero.id, target: goblin.id)
  store.advanceTurn()
  store.advance(to: .actionExecution)

  let history = store.actionHistory
  #expect(
    history == [
      .startBattle(players: [hero], enemies: [goblin]),
      .engine(.updateCurrentActor(hero.id)),
      .attack(attacker: hero.id, target: goblin.id),
      .engine(.incrementTurn),
      .engine(.transitionPhase(.actionExecution)),
    ])

  let replayed = history.reduce(JRPGBattleState()) { state, action in
    JRPGReducer().reduce(state: state, action: action).state
  }
  #expect(replayed.turnCount == 2)
  #expect(replayed.phase == .actionExecution)
  #expect(replayed.combatants == store.state.combatants)
}
