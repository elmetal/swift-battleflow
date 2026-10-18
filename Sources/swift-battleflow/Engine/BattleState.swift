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

/// Represents the current phase of a battle.
///
/// Phases within an ongoing battle, such as selecting commands or waiting for
/// gauges, depend on the turn system, so turn systems track them themselves.
public enum BattlePhase: Sendable, Equatable {
  case preparation  // The battle has not started.
  case ongoing  // The battle is in progress.
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

/// An immutable structure that stores the entire battle state.
public struct BattleState: Sendable, Equatable {
  /// The current phase of the battle.
  public private(set) var phase: BattlePhase

  /// The combatants taking part in the battle.
  public private(set) var participants: Set<CombatantID>

  /// Participant groups known to the engine.
  public private(set) var groups: [BattleGroupID: Set<CombatantID>]

  /// The current turn counter.
  public private(set) var turnCount: Int

  /// The combatant that is currently acting, if any.
  public private(set) var currentActor: CombatantID?

  public init(
    phase: BattlePhase = .preparation,
    participants: Set<CombatantID> = [],
    groups: [BattleGroupID: Set<CombatantID>] = [:],
    turnCount: Int = 0,
    currentActor: CombatantID? = nil
  ) {
    self.phase = phase
    self.participants = participants
    self.groups = groups
    self.turnCount = turnCount
    self.currentActor = currentActor
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

  /// Returns a new state that includes the participant, optionally in a group.
  public func withParticipant(_ id: CombatantID, in group: BattleGroupID? = nil) -> BattleState {
    updating { state in
      state.participants.insert(id)
      if let group {
        state.groups[group, default: []].insert(id)
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

}
