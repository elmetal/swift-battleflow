import Testing

@testable import swift_battleflow

// MARK: - Item Effect Tests

private let hero = JRPGBattleFlow.makeCharacter(
  name: "Hero", hp: 40, maxHP: 100, mp: 5, maxMP: 50)
private let fallen = JRPGBattleFlow.makeCharacter(name: "Fallen", hp: 0, maxHP: 80)
private let goblin = JRPGBattleFlow.makeCharacter(name: "Goblin", isPlayer: false)

private let state = JRPGBattleState(
  phase: .turnSelection,
  combatants: [hero.id: hero, fallen.id: fallen, goblin.id: goblin],
  playerIDs: [hero.id, fallen.id],
  enemyIDs: [goblin.id]
)

private func use(
  _ item: ItemID, on target: CombatantID?, rules: JRPGRules = .standard
) -> Reduction<JRPGBattleState, JRPGAction> {
  JRPGReducer(rules: rules).reduce(
    state: state, action: .useItem(user: hero.id, item: item, target: target))
}

@Test("A potion restores HP up to the maximum")
func testPotionRestoresHP() async throws {
  let reduction = use(.potion, on: hero.id)

  #expect(reduction.state.combatants[hero.id]?.stats.hp == 90)
  #expect(reduction.commands.contains { ($0 as? BaseCommand)?.id == "item_use_potion" })
}

@Test("An ether restores MP")
func testEtherRestoresMP() async throws {
  #expect(use(.ether, on: hero.id).state.combatants[hero.id]?.stats.mp == 35)
}

@Test("A phoenix down revives a defeated combatant")
func testPhoenixDownRevives() async throws {
  let revived = use(.phoenixDown, on: fallen.id).state.combatants[fallen.id]

  #expect(revived?.stats.hp == 1)
  #expect(revived?.stats.isDefeated == false)
}

@Test("Items without a target apply to the user")
func testItemDefaultsToUser() async throws {
  #expect(use(.potion, on: nil).state.combatants[hero.id]?.stats.hp == 90)
}

@Test("Items use the effects defined by the injected rules")
func testInjectedItemEffects() async throws {
  let elixir = ItemID("elixir")
  let rules = JRPGRules(
    physicalDamage: JRPGRules.standard.physicalDamage,
    itemEffect: { $0 == elixir ? .restoreHP(1000) : nil })

  #expect(use(elixir, on: hero.id, rules: rules).state.combatants[hero.id]?.stats.hp == 100)
}

@Test(
  "Item use is ignored when the effect does not fit the target",
  arguments: [
    (ItemID.phoenixDown, hero.id),  // revive needs a defeated target
    (ItemID.potion, fallen.id),  // healing needs a living target
    (ItemID("unknown"), hero.id),  // not defined by the rules
    (ItemID.potion, CombatantID("ghost")),  // unknown target
  ])
func testItemPreconditions(item: ItemID, target: CombatantID) async throws {
  let reduction = use(item, on: target)

  #expect(reduction.state == state)
  #expect(reduction.commands.isEmpty)
}

@Test("Rules must define positive item effect amounts")
func testNonPositiveItemEffectIsRejected() async {
  await #expect(processExitsWith: .failure) {
    let hero = JRPGBattleFlow.makeCharacter(name: "Hero", hp: 10, maxHP: 100)
    let rules = JRPGRules(
      physicalDamage: JRPGRules.standard.physicalDamage, itemEffect: { _ in .restoreHP(0) })
    _ = JRPGReducer(rules: rules).reduce(
      state: JRPGBattleState(
        phase: .turnSelection, combatants: [hero.id: hero], playerIDs: [hero.id]),
      action: .useItem(user: hero.id, item: .potion, target: nil))
  }
}
