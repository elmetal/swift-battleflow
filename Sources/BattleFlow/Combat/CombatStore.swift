/// The result of reducing a ``CombatAction``: the new state and the
/// ``CombatEvent`` values it produced.
public typealias CombatReduction<Rules: CombatRules> = Reduction<
  CombatState<Rules>, CombatAction<Rules>, CombatEvent<Rules>
>

/// A store that runs a battle by a game's ``CombatRules``.
public typealias CombatStore<Rules: CombatRules> = Store<CombatReducer<Rules>>

extension Store {
  /// Creates a store for a battle that follows the given rules.
  public convenience init<Rules>(initialState: CombatState<Rules>, rules: Rules)
  where R == CombatReducer<Rules> {
    self.init(initialState: initialState, reducer: CombatReducer(rules: rules))
  }

  /// Starts the battle with the given roster.
  public func start<Rules>(_ roster: CombatRoster<Rules.Stats>) where R == CombatReducer<Rules> {
    dispatch(.start(roster))
  }

  /// Submits a combatant's command.
  public func submit<Rules>(_ command: Rules.Command, by actor: CombatantID)
  where R == CombatReducer<Rules> {
    dispatch(.submit(command, by: actor))
  }

  /// Performs the next command the turn system has ready.
  public func performNextAction<Rules>() where R == CombatReducer<Rules> {
    dispatch(.performNextAction)
  }

  /// Lets time pass, for turn systems that depend on time.
  public func advanceTime<Rules>(by seconds: Double) where R == CombatReducer<Rules> {
    dispatch(.advanceTime(by: seconds))
  }
}
