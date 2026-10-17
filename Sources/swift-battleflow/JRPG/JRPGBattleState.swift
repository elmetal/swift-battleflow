/// Identifiers for the default JRPG participant groups.
extension BattleGroupID {
  public static let players = BattleGroupID("jrpg.players")
  public static let enemies = BattleGroupID("jrpg.enemies")
}

/// Stores JRPG-specific battle state on top of the rule-agnostic engine state.
///
/// The engine state is the single source of truth for participants and
/// groups; ``playerIDs`` and ``enemyIDs`` are derived from its groups.
public struct JRPGBattleState: Sendable, Equatable {
  public let engineState: BattleState
  public let combatants: [CombatantID: Combatant]

  /// The actions that combatants selected for the current turn.
  public let selections: [CombatantID: SelectedAction]

  /// Creates a state from an engine state, its combatants, and their
  /// selections.
  ///
  /// - Precondition: The combatant IDs match the engine participant IDs, and
  ///   every selection belongs to a combatant.
  public init(
    engineState: BattleState = BattleState(),
    combatants: [CombatantID: Combatant] = [:],
    selections: [CombatantID: SelectedAction] = [:]
  ) {
    precondition(
      Set(combatants.keys) == Set(engineState.participants.keys),
      "Every combatant must be an engine participant, and vice versa.")
    precondition(
      selections.keys.allSatisfy { combatants[$0] != nil },
      "Every selection must belong to a combatant.")

    self.engineState = engineState
    self.combatants = combatants
    self.selections = selections
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

    self.init(engineState: engineState, combatants: combatants)
  }

  /// The player-controlled combatant IDs, derived from the engine groups.
  public var playerIDs: Set<CombatantID> {
    engineState.participantIDs(in: .players)
  }

  /// The enemy combatant IDs, derived from the engine groups.
  public var enemyIDs: Set<CombatantID> {
    engineState.participantIDs(in: .enemies)
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

  /// The JRPG result of the battle, or `nil` while it is ongoing.
  public var result: BattleResult? {
    engineState.outcome.flatMap(BattleResult.init(outcome:))
  }

  /// Returns the player-controlled combatants that are still active.
  public var alivePlayers: [Combatant] {
    playerIDs.compactMap { id in
      combatants[id]?.stats.isDefeated == false ? combatants[id] : nil
    }
  }

  /// Returns every combatant that is still active.
  public var livingCombatants: [Combatant] {
    combatants.values.filter { !$0.stats.isDefeated }
  }

  /// Returns the enemy combatants that are still active.
  public var aliveEnemies: [Combatant] {
    enemyIDs.compactMap { id in
      combatants[id]?.stats.isDefeated == false ? combatants[id] : nil
    }
  }

  public func withEngineState(_ newEngineState: BattleState) -> JRPGBattleState {
    JRPGBattleState(engineState: newEngineState, combatants: combatants, selections: selections)
  }

  /// Returns a new state that records the combatant's selection.
  public func withSelection(_ selection: SelectedAction, for id: CombatantID) -> JRPGBattleState {
    var newSelections = selections
    newSelections[id] = selection
    return JRPGBattleState(
      engineState: engineState, combatants: combatants, selections: newSelections)
  }

  /// Returns a new state without any selections.
  public func removingAllSelections() -> JRPGBattleState {
    JRPGBattleState(engineState: engineState, combatants: combatants)
  }

  /// Returns a new state with the provided combatant updated or inserted.
  public func withCombatant(_ combatant: Combatant) -> JRPGBattleState {
    var newCombatants = combatants
    newCombatants[combatant.id] = combatant

    return JRPGBattleState(
      engineState: engineState.withParticipant(BattleParticipant(id: combatant.id)),
      combatants: newCombatants,
      selections: selections
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
}
