import Testing

@testable import swift_battleflow

// MARK: - JRPGAction Intent Tests

private func makeState(
  players: [Combatant],
  enemies: [Combatant],
  phase: BattlePhase = .turnSelection
) -> JRPGBattleState {
  var combatants: [CombatantID: Combatant] = [:]
  for combatant in players + enemies {
    combatants[combatant.id] = combatant
  }
  return JRPGBattleState(
    phase: phase,
    combatants: combatants,
    playerIDs: Set(players.map(\.id)),
    enemyIDs: Set(enemies.map(\.id))
  )
}

@Test("Attack derives damage from the standard rules")
func testAttackUsesStandardRules() async throws {
  let hero = JRPGBattleFlow.makeCharacter(name: "Hero", attack: 30, isPlayer: true)
  let goblin = JRPGBattleFlow.makeCharacter(
    name: "Goblin", hp: 80, defense: 10, isPlayer: false)
  let state = makeState(players: [hero], enemies: [goblin])

  let reduction = JRPGReducer().reduce(
    state: state, action: .attack(attacker: hero.id, target: goblin.id))

  // 30 - 10 / 2 = 25
  #expect(reduction.state.combatants[goblin.id]?.stats.hp == 55)
  #expect(
    reduction.commands.contains { ($0 as? BaseCommand)?.id == "damage_effect_goblin_25" })
}

@Test("Attack always deals at least one damage")
func testAttackMinimumDamage() async throws {
  let hero = JRPGBattleFlow.makeCharacter(name: "Hero", attack: 5, isPlayer: true)
  let golem = JRPGBattleFlow.makeCharacter(
    name: "Golem", hp: 80, defense: 50, isPlayer: false)
  let state = makeState(players: [hero], enemies: [golem])

  let reduction = JRPGReducer().reduce(
    state: state, action: .attack(attacker: hero.id, target: golem.id))

  #expect(reduction.state.combatants[golem.id]?.stats.hp == 79)
}

@Test("Attack uses injected rules")
func testAttackUsesInjectedRules() async throws {
  let hero = JRPGBattleFlow.makeCharacter(name: "Hero", isPlayer: true)
  let goblin = JRPGBattleFlow.makeCharacter(name: "Goblin", hp: 80, isPlayer: false)
  let state = makeState(players: [hero], enemies: [goblin])
  let reducer = JRPGReducer(rules: JRPGRules(physicalDamage: { _, _ in 7 }))

  let reduction = reducer.reduce(
    state: state, action: .attack(attacker: hero.id, target: goblin.id))

  #expect(reduction.state.combatants[goblin.id]?.stats.hp == 73)
}

@Test(
  "Attack is ignored when its preconditions are not met",
  arguments: [
    "defeated attacker", "defeated target", "unknown attacker", "unknown target", "ended battle",
  ])
func testAttackPreconditions(scenario: String) async throws {
  var hero = JRPGBattleFlow.makeCharacter(name: "Hero", isPlayer: true)
  var goblin = JRPGBattleFlow.makeCharacter(name: "Goblin", isPlayer: false)
  var attackerID = hero.id
  var targetID = goblin.id
  var phase = BattlePhase.turnSelection

  switch scenario {
  case "defeated attacker":
    hero = hero.withStats(hero.stats.withHP(0))
  case "defeated target":
    goblin = goblin.withStats(goblin.stats.withHP(0))
  case "unknown attacker":
    attackerID = CombatantID("ghost")
  case "unknown target":
    targetID = CombatantID("ghost")
  default:
    phase = .victory
  }

  let state = makeState(players: [hero], enemies: [goblin], phase: phase)
  let reduction = JRPGReducer().reduce(
    state: state, action: .attack(attacker: attackerID, target: targetID))

  #expect(reduction.state == state)
  #expect(reduction.commands.isEmpty)
}

@Test("Defeated combatants cannot defend or escape")
func testDefeatedCombatantCannotAct() async throws {
  let hero = JRPGBattleFlow.makeCharacter(name: "Hero", hp: 0, maxHP: 100, isPlayer: true)
  let goblin = JRPGBattleFlow.makeCharacter(name: "Goblin", isPlayer: false)
  let state = makeState(players: [hero], enemies: [goblin])

  for action in [JRPGAction.defend(defender: hero.id), .escape(escaper: hero.id)] {
    let reduction = JRPGReducer().reduce(state: state, action: action)
    #expect(reduction.state == state)
    #expect(reduction.commands.isEmpty)
  }
}

@Test("Skills and items are identified by typed IDs")
func testTypedSkillAndItemIDs() async throws {
  let hero = JRPGBattleFlow.makeCharacter(name: "Hero", isPlayer: true)
  let goblin = JRPGBattleFlow.makeCharacter(name: "Goblin", isPlayer: false)
  let state = makeState(players: [hero], enemies: [goblin])

  let skill = JRPGReducer().reduce(
    state: state,
    action: .useSkill(user: hero.id, skill: SkillID("fire"), targets: [goblin.id]))
  #expect(skill.commands.contains { ($0 as? BaseCommand)?.id == "skill_animation_fire" })

  let item = JRPGReducer().reduce(
    state: state, action: .useItem(user: hero.id, item: ItemID("potion"), target: hero.id))
  #expect(item.commands.contains { ($0 as? BaseCommand)?.id == "item_use_potion" })

  #expect(
    SelectedAction.skill(id: SkillID("fire"), targets: []).battleSelection.id == "jrpg.skill.fire")
  #expect(
    SelectedAction.item(id: ItemID("potion"), target: nil).battleSelection.id == "jrpg.item.potion")
}
