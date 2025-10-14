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

@Test("BattleState derived collections and updates")
func testBattleStateDerivedCollections() async throws {
    let alivePlayer = BattleFlow.createCharacter(name: "Hero", hp: 80, isPlayer: true)
    let defeatedPlayer = BattleFlow.createCharacter(name: "Knight", hp: 0, maxHP: 80, isPlayer: true)
    let aliveEnemy = BattleFlow.createCharacter(name: "Goblin", hp: 40, isPlayer: false)
    let defeatedEnemy = BattleFlow.createCharacter(name: "Orc", hp: 0, maxHP: 120, isPlayer: false)

    let state = BattleState(
        phase: .turnSelection,
        combatants: [
            alivePlayer.id: alivePlayer,
            defeatedPlayer.id: defeatedPlayer,
            aliveEnemy.id: aliveEnemy,
            defeatedEnemy.id: defeatedEnemy
        ],
        playerCombatants: [alivePlayer.id, defeatedPlayer.id],
        enemyCombatants: [aliveEnemy.id, defeatedEnemy.id]
    )

    #expect(Set(state.alivePlayers.map(\.id)) == Set([alivePlayer.id]))
    #expect(Set(state.aliveEnemies.map(\.id)) == Set([aliveEnemy.id]))

    let healedState = state.withCombatant(defeatedPlayer.withStats(defeatedPlayer.stats.withHP(50)))
    #expect(healedState.alivePlayers.contains { $0.id == defeatedPlayer.id })
    #expect(healedState.phase == state.phase)
    #expect(healedState.turnCount == state.turnCount)
}
