/// Identifiers for the default JRPG participant groups.
extension BattleGroupID {
  public static let players = BattleGroupID("jrpg.players")
  public static let enemies = BattleGroupID("jrpg.enemies")
}

/// Stores JRPG-specific battle state on top of the rule-agnostic engine state.
public struct JRPGBattleState: Sendable, Equatable {
  public let engineState: BattleState
  public let combatants: [CombatantID: Combatant]
  public let playerIDs: Set<CombatantID>
  public let enemyIDs: Set<CombatantID>

  public init(
    engineState: BattleState = BattleState(),
    combatants: [CombatantID: Combatant] = [:],
    playerIDs: Set<CombatantID> = [],
    enemyIDs: Set<CombatantID> = []
  ) {
    self.engineState = engineState
    self.combatants = combatants
    self.playerIDs = playerIDs
    self.enemyIDs = enemyIDs
  }

  public init(
    phase: BattlePhase = .preparation,
    combatants: [CombatantID: Combatant] = [:],
    playerIDs: Set<CombatantID> = [],
    enemyIDs: Set<CombatantID> = [],
    turnCount: Int = 0,
    currentActor: CombatantID? = nil,
    pendingCommands: [any Command] = []
  ) {
    var participants: [CombatantID: BattleParticipant] = [:]
    for id in combatants.keys {
      participants[id] = BattleParticipant(id: id)
    }

    let engineState = BattleState(
      phase: phase,
      participants: participants,
      groups: [
        .players: playerIDs,
        .enemies: enemyIDs,
      ],
      turnCount: turnCount,
      currentActor: currentActor,
      pendingCommands: pendingCommands
    )

    self.init(
      engineState: engineState,
      combatants: combatants,
      playerIDs: playerIDs,
      enemyIDs: enemyIDs
    )
  }

  public var phase: BattlePhase {
    engineState.phase
  }

  public var turnCount: Int {
    engineState.turnCount
  }

  public var currentActor: CombatantID? {
    engineState.currentActor
  }

  public var pendingCommands: [any Command] {
    engineState.pendingCommands
  }

  public var isBattleEnded: Bool {
    engineState.isBattleEnded
  }

  /// Returns the player-controlled combatants that are still active.
  public var alivePlayers: [Combatant] {
    playerIDs.compactMap { id in
      combatants[id]?.stats.isDefeated == false ? combatants[id] : nil
    }
  }

  /// Returns the enemy combatants that are still active.
  public var aliveEnemies: [Combatant] {
    enemyIDs.compactMap { id in
      combatants[id]?.stats.isDefeated == false ? combatants[id] : nil
    }
  }

  public func withEngineState(_ newEngineState: BattleState) -> JRPGBattleState {
    JRPGBattleState(
      engineState: newEngineState,
      combatants: combatants,
      playerIDs: playerIDs,
      enemyIDs: enemyIDs
    )
  }

  /// Returns a new state with the provided combatant updated or inserted.
  public func withCombatant(_ combatant: Combatant) -> JRPGBattleState {
    var newCombatants = combatants
    newCombatants[combatant.id] = combatant

    var newEngineState = engineState.withParticipant(BattleParticipant(id: combatant.id))
    if playerIDs.contains(combatant.id) {
      newEngineState = newEngineState.withParticipant(
        BattleParticipant(id: combatant.id), in: .players)
    }
    if enemyIDs.contains(combatant.id) {
      newEngineState = newEngineState.withParticipant(
        BattleParticipant(id: combatant.id), in: .enemies)
    }

    return JRPGBattleState(
      engineState: newEngineState,
      combatants: newCombatants,
      playerIDs: playerIDs,
      enemyIDs: enemyIDs
    )
  }

  /// Returns a new state with a different battle phase.
  public func withPhase(_ newPhase: BattlePhase) -> JRPGBattleState {
    withEngineState(engineState.withPhase(newPhase))
  }

  /// Returns a new state with additional pending commands appended.
  public func appendingCommands(_ commands: [any Command]) -> JRPGBattleState {
    withEngineState(engineState.appendingCommands(commands))
  }

  /// Returns a new state with all pending commands removed.
  public func removingAllCommands() -> JRPGBattleState {
    withEngineState(engineState.removingAllCommands())
  }

  public static func == (lhs: JRPGBattleState, rhs: JRPGBattleState) -> Bool {
    lhs.engineState == rhs.engineState && lhs.combatants == rhs.combatants
      && lhs.playerIDs == rhs.playerIDs && lhs.enemyIDs == rhs.enemyIDs
  }
}
