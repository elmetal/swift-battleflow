import Testing
@testable import swift_battleflow

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
