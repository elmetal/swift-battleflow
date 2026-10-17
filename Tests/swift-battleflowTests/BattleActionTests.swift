import Testing

@testable import swift_battleflow

// MARK: - Action Tests

@Test("JRPGAction metadata properties")
func testJRPGActionMetadata() async throws {
  let escapeAction = JRPGAction.escape(escaper: CombatantID("test"))
  #expect(escapeAction.metadata.priority == .escape)
  #expect(escapeAction.metadata.isInstant == true)

  let attackAction = JRPGAction.attack(
    attacker: CombatantID("a"), target: CombatantID("b"))
  #expect(attackAction.metadata.priority == .attack)
  #expect(attackAction.metadata.isInstant == false)
}

@Test("BattleAction equality")
func testBattleActionEquality() async throws {
  let heroID = CombatantID("hero")

  #expect(BattleAction.updateCurrentActor(heroID) == .updateCurrentActor(heroID))
  #expect(BattleAction.incrementTurn != .transitionPhase(.turnSelection))
}

@Test("Battle action selection is rule agnostic")
func testBattleActionSelectionIsRuleAgnostic() async throws {
  let heroID = CombatantID("hero")
  let selection = BattleSelection(id: "custom.rule.action")

  let action = BattleAction.completeSelection(selection, for: heroID)

  #expect(action == .completeSelection(selection, for: heroID))
}
