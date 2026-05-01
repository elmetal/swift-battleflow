import Foundation

/// Represents the current phase of a battle sequence.
public enum BattlePhase: Sendable, Equatable {
  case preparation  // Battle setup.
  case turnSelection  // Choosing the next actor.
  case actionExecution  // Resolving chosen actions.
  case effectResolution  // Processing pending effects.
  case victory  // Players succeed.
  case defeat  // Players lose.
  case escape  // Battle ends by escape.
}

/// Identifies a combatant participating in the battle.
public struct CombatantID: Hashable, Sendable {
  public let value: String

  public init(_ value: String) {
    self.value = value
  }
}

/// Identifies a participant group in a battle.
public struct BattleGroupID: Hashable, Sendable, Equatable {
  public let value: String

  public init(_ value: String) {
    precondition(!value.isEmpty, "BattleGroupID value must not be empty.")
    self.value = value
  }
}

/// Describes a rule-agnostic participant known by the battle engine.
public struct BattleParticipant: Sendable, Equatable {
  public let id: CombatantID

  public init(id: CombatantID) {
    self.id = id
  }
}

/// An immutable structure that stores the entire battle state.
public struct BattleState: Sendable, Equatable {
  /// The current phase of the battle.
  public let phase: BattlePhase

  /// A lookup table of all engine-level participants.
  public let participants: [CombatantID: BattleParticipant]

  /// Participant groups known to the engine.
  public let groups: [BattleGroupID: Set<CombatantID>]

  /// The current turn counter.
  public let turnCount: Int

  /// The combatant that is currently acting, if any.
  public let currentActor: CombatantID?

  /// Pending commands awaiting execution.
  public let pendingCommands: [any Command]

  public init(
    phase: BattlePhase = .preparation,
    participants: [CombatantID: BattleParticipant] = [:],
    groups: [BattleGroupID: Set<CombatantID>] = [:],
    turnCount: Int = 0,
    currentActor: CombatantID? = nil,
    pendingCommands: [any Command] = []
  ) {
    self.phase = phase
    self.participants = participants
    self.groups = groups
    self.turnCount = turnCount
    self.currentActor = currentActor
    self.pendingCommands = pendingCommands
  }

  /// Indicates whether the battle has reached a terminal phase.
  public var isBattleEnded: Bool {
    switch phase {
    case .victory, .defeat, .escape:
      return true
    default:
      return false
    }
  }

  /// Returns a new state with the provided participant updated or inserted.
  public func withParticipant(
    _ participant: BattleParticipant,
    in group: BattleGroupID? = nil
  ) -> BattleState {
    var newParticipants = participants
    var newGroups = groups
    newParticipants[participant.id] = participant

    if let group {
      newGroups[group, default: []].insert(participant.id)
    }

    return BattleState(
      phase: phase,
      participants: newParticipants,
      groups: newGroups,
      turnCount: turnCount,
      currentActor: currentActor,
      pendingCommands: pendingCommands
    )
  }

  /// Returns the participant identifiers in a group.
  public func participantIDs(in group: BattleGroupID) -> Set<CombatantID> {
    groups[group] ?? []
  }

  /// Returns a new state with a different battle phase.
  public func withPhase(_ newPhase: BattlePhase) -> BattleState {
    BattleState(
      phase: newPhase,
      participants: participants,
      groups: groups,
      turnCount: turnCount,
      currentActor: currentActor,
      pendingCommands: pendingCommands
    )
  }

  /// Returns a new state with additional pending commands appended.
  public func withCommands(_ commands: [any Command]) -> BattleState {
    BattleState(
      phase: phase,
      participants: participants,
      groups: groups,
      turnCount: turnCount,
      currentActor: currentActor,
      pendingCommands: pendingCommands + commands
    )
  }

  /// Returns a new state with all pending commands removed.
  public func withClearedCommands() -> BattleState {
    BattleState(
      phase: phase,
      participants: participants,
      groups: groups,
      turnCount: turnCount,
      currentActor: currentActor,
      pendingCommands: []
    )
  }
}

extension BattleState {
  /// Custom ``Equatable`` implementation.
  ///
  /// Pending commands are type-erased, so only their counts are compared at
  /// this stage. Extend this logic if more granular comparisons are needed in
  /// the future.
  public static func == (lhs: BattleState, rhs: BattleState) -> Bool {
    lhs.phase == rhs.phase && lhs.participants == rhs.participants && lhs.groups == rhs.groups
      && lhs.turnCount == rhs.turnCount && lhs.currentActor == rhs.currentActor
      && lhs.pendingCommands.count == rhs.pendingCommands.count
    // Note: Extend this comparison with detailed command matching when needed.
  }
}
