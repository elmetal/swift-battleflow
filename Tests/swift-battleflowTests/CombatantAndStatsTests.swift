import Testing
@testable import swift_battleflow

// MARK: - Combatant & Stats Tests

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
