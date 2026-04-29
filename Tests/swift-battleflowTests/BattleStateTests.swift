import Testing

@testable import swift_battleflow

// MARK: - BattleState Tests

@Test("BattleState creation with default values")
func testBattleStateCreation() async throws {
  let state = BattleState()

  #expect(state.phase == .preparation)
  #expect(state.turnCount == 0)
  #expect(state.currentActor == nil)
  #expect(state.participants.isEmpty)
  #expect(state.groups.isEmpty)
}

@Test("BattleState manages engine participants without JRPG combatants")
func testBattleStateParticipants() async throws {
  let heroID = CombatantID("hero")
  let enemyID = CombatantID("enemy")
  let state = BattleState()
    .withParticipant(BattleParticipant(id: heroID), in: BattleGroupID("left"))
    .withParticipant(BattleParticipant(id: enemyID), in: BattleGroupID("right"))

  #expect(state.participants[heroID]?.id == heroID)
  #expect(state.participantIDs(in: BattleGroupID("left")) == Set([heroID]))
  #expect(state.participantIDs(in: BattleGroupID("right")) == Set([enemyID]))
}

@Test("JRPGBattleState derived collections and updates")
func testJRPGBattleStateDerivedCollections() async throws {
  let alivePlayer = JRPGBattleFlow.createCharacter(name: "Hero", hp: 80, isPlayer: true)
  let defeatedPlayer = JRPGBattleFlow.createCharacter(
    name: "Knight", hp: 0, maxHP: 80, isPlayer: true)
  let aliveEnemy = JRPGBattleFlow.createCharacter(name: "Goblin", hp: 40, isPlayer: false)
  let defeatedEnemy = JRPGBattleFlow.createCharacter(
    name: "Orc", hp: 0, maxHP: 120, isPlayer: false)

  let state = JRPGBattleState(
    phase: .turnSelection,
    combatants: [
      alivePlayer.id: alivePlayer,
      defeatedPlayer.id: defeatedPlayer,
      aliveEnemy.id: aliveEnemy,
      defeatedEnemy.id: defeatedEnemy,
    ],
    playerCombatants: [alivePlayer.id, defeatedPlayer.id],
    enemyCombatants: [aliveEnemy.id, defeatedEnemy.id]
  )

  #expect(Set(state.alivePlayers.map(\.id)) == Set([alivePlayer.id]))
  #expect(Set(state.aliveEnemies.map(\.id)) == Set([aliveEnemy.id]))
  #expect(
    state.engineState.participantIDs(in: .players) == Set([alivePlayer.id, defeatedPlayer.id]))

  let healedState = state.withCombatant(defeatedPlayer.withStats(defeatedPlayer.stats.withHP(50)))
  #expect(healedState.alivePlayers.contains { $0.id == defeatedPlayer.id })
  #expect(healedState.phase == state.phase)
  #expect(healedState.turnCount == state.turnCount)
}
