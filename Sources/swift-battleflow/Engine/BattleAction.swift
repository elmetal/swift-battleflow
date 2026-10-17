/// A rule-agnostic action selection chosen by a combatant.
public struct BattleSelection: Sendable, Equatable {
  public let id: String

  public init(id: String) {
    precondition(!id.isEmpty, "BattleSelection id must not be empty.")
    self.id = id
  }
}

/// Describes engine-level actions that coordinate battle flow and commands.
public enum BattleAction: Sendable, Equatable {
  /// Advances to the next phase in the battle flow.
  case transitionPhase(BattlePhase)

  /// Moves the combat timeline to the next turn.
  case incrementTurn

  /// Sets the combatant that is currently acting.
  case updateCurrentActor(CombatantID?)

  /// Signals the beginning of an action selection phase for a combatant.
  case beginSelection(for: CombatantID)

  /// Completes an action selection with the specified decision.
  case completeSelection(BattleSelection, for: CombatantID)

  /// Queues one or more command identifiers for later execution.
  case enqueueCommands([String])

  /// Marks a previously enqueued command as executed and removes it from the
  /// queue. When several pending commands share the ID, only the first is
  /// removed; an ID that is not pending is ignored.
  case markCommandExecuted(String)

  /// Clears all pending commands from the queue.
  case removeAllCommands
}
