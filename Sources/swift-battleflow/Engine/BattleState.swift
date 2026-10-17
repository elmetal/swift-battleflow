import Foundation

/// Identifies how a battle ended.
///
/// The engine is rule-agnostic, so rule sets define their own outcomes, for
/// example as static members in an extension.
public struct BattleOutcome: Hashable, Sendable {
  public let value: String

  public init(_ value: String) {
    precondition(!value.isEmpty, "BattleOutcome value must not be empty.")
    self.value = value
  }
}

/// Represents the current phase of a battle sequence.
public enum BattlePhase: Sendable, Equatable {
  case preparation  // Battle setup.
  case turnSelection  // Choosing the next actor.
  case actionExecution  // Resolving chosen actions.
  case effectResolution  // Processing pending effects.
  case ended(BattleOutcome)  // The battle is over with a rule-defined outcome.
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
  public private(set) var phase: BattlePhase

  /// A lookup table of all engine-level participants.
  public private(set) var participants: [CombatantID: BattleParticipant]

  /// Participant groups known to the engine.
  public private(set) var groups: [BattleGroupID: Set<CombatantID>]

  /// The current turn counter.
  public private(set) var turnCount: Int

  /// The combatant that is currently acting, if any.
  public private(set) var currentActor: CombatantID?

  /// Pending commands awaiting execution.
  public private(set) var pendingCommands: [any Command]

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
    outcome != nil
  }

  /// The outcome of the battle, or `nil` while it is ongoing.
  public var outcome: BattleOutcome? {
    guard case .ended(let outcome) = phase else {
      return nil
    }
    return outcome
  }

  /// Returns the participant identifiers in a group.
  public func participantIDs(in group: BattleGroupID) -> Set<CombatantID> {
    groups[group] ?? []
  }

  /// Returns a copy of the state with the changes applied.
  private func updating(_ update: (inout BattleState) -> Void) -> BattleState {
    var newState = self
    update(&newState)
    return newState
  }
}

// MARK: - Transformations

extension BattleState {

  /// Returns a new state with the provided participant updated or inserted.
  public func withParticipant(
    _ participant: BattleParticipant,
    in group: BattleGroupID? = nil
  ) -> BattleState {
    updating { state in
      state.participants[participant.id] = participant
      if let group {
        state.groups[group, default: []].insert(participant.id)
      }
    }
  }

  /// Returns a new state with a different battle phase.
  public func withPhase(_ newPhase: BattlePhase) -> BattleState {
    updating { $0.phase = newPhase }
  }

  /// Returns a new state that starts the next turn.
  ///
  /// The turn counter increments, and the current actor is cleared.
  public func advancingTurn() -> BattleState {
    updating { state in
      state.turnCount += 1
      state.currentActor = nil
    }
  }

  /// Returns a new state with a different current actor.
  public func withCurrentActor(_ actorID: CombatantID?) -> BattleState {
    updating { $0.currentActor = actorID }
  }

  /// Returns a new state with additional pending commands appended.
  public func appendingCommands(_ commands: [any Command]) -> BattleState {
    updating { $0.pendingCommands += commands }
  }

  /// Returns a new state without the first pending command that has the given ID.
  ///
  /// The state is returned unchanged when no pending command has the ID.
  public func removingFirstCommand(withID id: String) -> BattleState {
    guard let index = pendingCommands.firstIndex(where: { $0.id == id }) else {
      return self
    }
    return updating { _ = $0.pendingCommands.remove(at: index) }
  }

  /// Returns a new state with all pending commands removed.
  public func removingAllCommands() -> BattleState {
    updating { $0.pendingCommands = [] }
  }
}

extension BattleState {
  /// Custom ``Equatable`` implementation.
  ///
  /// Pending commands are type-erased, so they are compared element by element
  /// with ``Command/isEqual(to:)``, which also requires matching concrete types.
  public static func == (lhs: BattleState, rhs: BattleState) -> Bool {
    lhs.phase == rhs.phase && lhs.participants == rhs.participants && lhs.groups == rhs.groups
      && lhs.turnCount == rhs.turnCount && lhs.currentActor == rhs.currentActor
      && lhs.pendingCommands.elementsEqual(rhs.pendingCommands) { $0.isEqual(to: $1) }
  }
}
