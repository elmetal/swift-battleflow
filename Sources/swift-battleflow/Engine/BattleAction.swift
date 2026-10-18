/// Describes engine-level actions that coordinate battle flow.
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
}
