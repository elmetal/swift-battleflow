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
/// The combat reducer emits these as commands, in the order they happened.
public enum CombatEvent<Rules: CombatRules>: Command {
  /// The battle started.
  case started

  /// A combatant performed a command with the given effects.
  case performed(actor: CombatantID, command: Rules.Command, effects: [Rules.Effect])

  /// A combatant's turn came, but it could no longer act.
  case skipped(actor: CombatantID)

  /// The battle reached a turn boundary, with the rules' effects for it.
  case boundary(Rules.Turns.Boundary, effects: [Rules.Effect])

  /// The battle ended.
  case ended(BattleOutcome)

  public var id: String {
    switch self {
    case .started: "combat.started"
    case .performed(let actor, _, _): "combat.performed.\(actor.value)"
    case .skipped(let actor): "combat.skipped.\(actor.value)"
    case .boundary: "combat.boundary"
    case .ended(let outcome): "combat.ended.\(outcome.value)"
    }
  }

  /// Events in one reduction run in the order they happened: an action
  /// before the end of the battle it caused.
  public var priority: Int {
    switch self {
    case .ended: 0
    default: 1
    }
  }
}
