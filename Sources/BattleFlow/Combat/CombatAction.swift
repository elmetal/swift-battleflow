/// The actions that drive a battle following a game's ``CombatRules``.
public enum CombatAction<Rules: CombatRules>: Sendable, Equatable {
  /// Starts the battle with the given roster.
  ///
  /// Ignored once the battle has started.
  case start(CombatRoster<Rules.Stats>)

  /// Submits a combatant's command.
  ///
  /// Ignored unless the battle is ongoing and the combatant can act and is
  /// awaiting a command.
  case submit(Rules.Command, by: CombatantID)

  /// Withdraws a combatant's submitted command, so that it can submit
  /// another one.
  ///
  /// Ignored unless the battle is ongoing and the turn system lets the
  /// combatant withdraw its command. The rules choose again for a
  /// computer-controlled combatant.
  case withdraw(by: CombatantID)

  /// Performs the next command the turn system has ready.
  ///
  /// Ignored unless the battle is ongoing.
  case performNextAction

  /// Lets time pass, for turn systems that depend on time.
  ///
  /// - Precondition: `seconds` is not negative.
  case advanceTime(by: Double)

  /// Ends the battle with the given outcome, for example for scripted events.
  ///
  /// Ignored unless the battle is ongoing.
  case end(BattleOutcome)
}

/// What happened in a battle, for presentation.
///
/// These are the combat reducer's outputs, delivered in the order they
/// happened.
public enum CombatEvent<Rules: CombatRules>: Sendable, Equatable {
  /// The battle started.
  case started

  /// The rules submitted a command for a computer-controlled combatant.
  case submittedAutomatically(actor: CombatantID, command: Rules.Command)

  /// A combatant performed a command with the given effects.
  case performed(actor: CombatantID, command: Rules.Command, effects: [Rules.Effect])

  /// A combatant's turn came, but it could no longer act.
  case skipped(actor: CombatantID)

  /// The battle reached a turn boundary, with the rules' effects for it.
  case boundary(Rules.Turns.Boundary, effects: [Rules.Effect])

  /// The battle ended.
  case ended(BattleOutcome)
}
