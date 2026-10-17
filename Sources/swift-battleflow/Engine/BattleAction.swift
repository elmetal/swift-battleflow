/// Describes engine-level actions that coordinate battle flow and commands.
public enum BattleAction: Sendable, Equatable {
  /// Advances to the next phase in the battle flow.
  case transitionPhase(BattlePhase)

  /// Moves the combat timeline to the next turn.
  case incrementTurn

  /// Sets the combatant that is currently acting.
  case updateCurrentActor(CombatantID?)

  /// Sets the order in which participants act this turn.
  ///
  /// - Precondition: Every ID is a known participant and appears only once.
  case scheduleActions([CombatantID])

  /// Makes the next participant in the action order the current actor, or
  /// clears the current actor when no participant is left.
  case advanceActor

  /// Queues commands for later execution.
  case enqueueCommands([any Command])

  /// Marks a previously enqueued command as executed and removes it from the
  /// queue. When several pending commands share the ID, only the first is
  /// removed; an ID that is not pending is ignored.
  case markCommandExecuted(String)

  /// Clears all pending commands from the queue.
  case removeAllCommands
}

extension BattleAction {
  /// Custom ``Equatable`` implementation.
  ///
  /// Enqueued commands are type-erased, so they are compared element by
  /// element with ``Command/isEqual(to:)``.
  public static func == (lhs: BattleAction, rhs: BattleAction) -> Bool {
    switch (lhs, rhs) {
    case (.transitionPhase(let lhs), .transitionPhase(let rhs)):
      return lhs == rhs
    case (.incrementTurn, .incrementTurn), (.advanceActor, .advanceActor),
      (.removeAllCommands, .removeAllCommands):
      return true
    case (.updateCurrentActor(let lhs), .updateCurrentActor(let rhs)):
      return lhs == rhs
    case (.scheduleActions(let lhs), .scheduleActions(let rhs)):
      return lhs == rhs
    case (.enqueueCommands(let lhs), .enqueueCommands(let rhs)):
      return lhs.elementsEqual(rhs) { $0.isEqual(to: $1) }
    case (.markCommandExecuted(let lhs), .markCommandExecuted(let rhs)):
      return lhs == rhs
    default:
      return false
    }
  }
}
