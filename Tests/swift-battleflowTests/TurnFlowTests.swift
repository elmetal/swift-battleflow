import Testing

@testable import swift_battleflow

// MARK: - Turn Flow Tests

private let hero = JRPGBattleFlow.makeCharacter(name: "Hero", hp: 100, speed: 10)
private let mage = JRPGBattleFlow.makeCharacter(name: "Mage", hp: 60, speed: 20)
private let goblin = JRPGBattleFlow.makeCharacter(
  name: "Goblin", hp: 50, speed: 15, isPlayer: false)

private let reducer = JRPGReducer<SeededBattleRandomGenerator>()

private func started(
  players: [Combatant] = [hero, mage], enemies: [Combatant] = [goblin]
) -> JRPGBattleState<SeededBattleRandomGenerator> {
  reducer.reduce(state: JRPGBattleState(), action: .startBattle(players: players, enemies: enemies))
    .state
}

private func reduce(_ state: JRPGBattleState<SeededBattleRandomGenerator>, _ actions: JRPGAction...)
  -> JRPGBattleState<SeededBattleRandomGenerator>
{
  actions.reduce(state) { reducer.reduce(state: $0, action: $1).state }
}

private func commandIDs(_ state: JRPGBattleState<SeededBattleRandomGenerator>, _ action: JRPGAction)
  -> [String]
{
  reducer.reduce(state: state, action: action).commands.map(\.id)
}

// MARK: Selecting

@Test("Combatants select actions during turn selection; later selections replace earlier ones")
func testSelect() async throws {
  let state = reduce(
    started(),
    .select(.defend, by: hero.id),
    .select(.attack(target: goblin.id), by: hero.id))

  #expect(state.selections == [hero.id: .attack(target: goblin.id)])
}

@Test(
  "Selections are ignored when the combatant cannot act or the phase is wrong",
  arguments: ["defeated", "unknown", "wrong phase"])
func testSelectPreconditions(scenario: String) async throws {
  var state = started()
  var id = hero.id
  switch scenario {
  case "defeated":
    state = state.withCombatant(hero.withStats(hero.stats.withHP(0)))
  case "unknown":
    id = CombatantID("ghost")
  default:
    state = state.withPhase(.actionExecution)
  }

  let reduction = reducer.reduce(state: state, action: .select(.defend, by: id))

  #expect(reduction.state == state)
  #expect(reduction.commands.isEmpty)
}

// MARK: Ordering

@Test("Selected actions have priorities; defending and escaping go first")
func testSelectedActionPriority() async throws {
  #expect(SelectedAction.escape.priority == .highest)
  #expect(SelectedAction.defend.priority == .highest)
  #expect(SelectedAction.item(id: .potion, target: nil).priority == .high)
  #expect(SelectedAction.attack(target: goblin.id).priority == .normal)
  #expect(SelectedAction.skill(id: SkillID("fire"), targets: []).priority == .normal)
}

@Test("executeTurn orders actors by priority, then speed")
func testExecuteTurnOrder() async throws {
  let twin = JRPGBattleFlow.makeCharacter(
    name: "Goblin", id: CombatantID("goblin_b"), hp: 50, speed: 14, isPlayer: false)

  let state = reduce(
    started(enemies: [goblin, twin]),
    .select(.defend, by: hero.id),
    .select(.attack(target: goblin.id), by: mage.id),
    .select(.attack(target: hero.id), by: twin.id),
    .select(.attack(target: hero.id), by: goblin.id),
    .executeTurn)

  #expect(state.phase == .actionExecution)
  #expect(state.engineState.actionOrder == [hero.id, mage.id, goblin.id, twin.id])
}

@Test("executeTurn waits until every living combatant has selected")
func testExecuteTurnRequiresAllSelections() async throws {
  let partial = reduce(started(), .select(.defend, by: hero.id), .select(.defend, by: mage.id))
  #expect(reducer.reduce(state: partial, action: .executeTurn).state == partial)

  // Defeated combatants do not need to select.
  let fallenMage = started().withCombatant(mage.withStats(mage.stats.withHP(0)))
  let ready = reduce(
    fallenMage,
    .select(.defend, by: hero.id),
    .select(.attack(target: hero.id), by: goblin.id),
    .executeTurn)
  #expect(ready.engineState.actionOrder == [hero.id, goblin.id])
}

// MARK: Executing

@Test("performNextAction performs selections in order and then ends the turn")
func testPerformTurn() async throws {
  let executing = reduce(
    started(),
    .select(.defend, by: hero.id),
    .select(.attack(target: goblin.id), by: mage.id),
    .select(.attack(target: hero.id), by: goblin.id),
    .executeTurn)

  #expect(commandIDs(executing, .performNextAction).contains("defend_animation_hero"))

  let afterHero = reduce(executing, .performNextAction)
  #expect(afterHero.currentActor == hero.id)

  let afterMage = reduce(afterHero, .performNextAction)
  #expect(afterMage.currentActor == mage.id)
  #expect(afterMage.combatants[goblin.id]!.stats.hp < goblin.stats.hp)

  let afterGoblin = reduce(afterMage, .performNextAction)
  #expect(afterGoblin.currentActor == goblin.id)
  #expect(afterGoblin.combatants[hero.id]!.stats.hp < hero.stats.hp)

  let nextTurn = reduce(afterGoblin, .performNextAction)
  #expect(nextTurn.phase == .turnSelection)
  #expect(nextTurn.turnCount == executing.turnCount + 1)
  #expect(nextTurn.selections.isEmpty)
  #expect(nextTurn.currentActor == nil)
}

@Test("A combatant defeated before its turn does not act")
func testDefeatedActorIsSkipped() async throws {
  let archmage = JRPGBattleFlow.makeCharacter(name: "Mage", hp: 60, attack: 500, speed: 20)
  // A slower second enemy keeps the battle going after the goblin falls.
  let slime = JRPGBattleFlow.makeCharacter(name: "Slime", hp: 50, speed: 1, isPlayer: false)
  let state = reduce(
    started(players: [hero, archmage], enemies: [goblin, slime]),
    .select(.defend, by: hero.id),
    .select(.attack(target: goblin.id), by: archmage.id),
    .select(.attack(target: hero.id), by: goblin.id),
    .select(.attack(target: hero.id), by: slime.id),
    .executeTurn,
    .performNextAction,
    .performNextAction)
  #expect(state.combatants[goblin.id]!.stats.isDefeated)

  let goblinTurn = reducer.reduce(state: state, action: .performNextAction)

  #expect(goblinTurn.state.combatants[hero.id] == state.combatants[hero.id])
  #expect(goblinTurn.state.currentActor == goblin.id)
}

@Test("Escaping ends the battle and the rest of the turn is ignored")
func testEscapeEndsTurn() async throws {
  let escaped = reduce(
    started(),
    .select(.escape, by: hero.id),
    .select(.attack(target: goblin.id), by: mage.id),
    .select(.attack(target: hero.id), by: goblin.id),
    .executeTurn,
    .performNextAction)
  #expect(escaped.result == .escape)

  let reduction = reducer.reduce(state: escaped, action: .performNextAction)
  #expect(reduction.state == escaped)
  #expect(reduction.commands.isEmpty)
}

@Test("performNextAction is ignored outside action execution")
func testPerformNextActionOutsideExecution() async throws {
  let state = started()
  #expect(reducer.reduce(state: state, action: .performNextAction).state == state)
}

// MARK: Store

@Test("JRPGBattleStore drives a turn")
@MainActor
func testStoreDrivesTurn() async throws {
  let store = JRPGBattleStore()
  store.startBattle(players: [hero], enemies: [goblin])

  store.select(.attack(target: goblin.id), by: hero.id)
  store.select(.attack(target: hero.id), by: goblin.id)
  store.executeTurn()
  store.performNextAction()
  store.performNextAction()
  store.performNextAction()

  #expect(store.turnCount == 2)
  #expect(store.currentPhase == .turnSelection)
  #expect(store.combatant(for: goblin.id)!.stats.hp < goblin.stats.hp)
}
