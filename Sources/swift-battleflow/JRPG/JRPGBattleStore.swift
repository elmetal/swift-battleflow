/// A store specialized for the default JRPG rule set.
public typealias JRPGBattleStore = Store<JRPGReducer>

extension JRPGBattleStore {
  /// Creates a store using the provided initial JRPG battle state.
  ///
  /// - Parameter initialState: The starting state. The default value produces
  ///   an empty battle.
  public convenience init(initialState: JRPGBattleState = JRPGBattleState()) {
    self.init(initialState: initialState, reducer: JRPGReducer())
  }

  /// Creates an empty-battle store that applies the provided reducer.
  ///
  /// - Parameter reducer: The reducer that applies the JRPG rules.
  public convenience init(reducer: JRPGReducer) {
    self.init(initialState: JRPGBattleState(), reducer: reducer)
  }

  /// Resets the store to a fresh battle and clears the action history.
  public func reset() {
    reset(to: JRPGBattleState())
  }
}

// MARK: - Convenience API

extension JRPGBattleStore {

  /// Starts a battle with the provided player and enemy rosters.
  ///
  /// - Parameters:
  ///   - players: The player-controlled combatants.
  ///   - enemies: The opposing combatants.
  public func startBattle(players: [Combatant], enemies: [Combatant]) {
    dispatch(.startBattle(players: players, enemies: enemies))
  }

  /// Ends the battle with the specified result.
  ///
  /// - Parameter result: The resolved outcome.
  public func endBattle(with result: BattleResult) {
    dispatch(.endBattle(result: result))
  }

  /// Records the action a combatant will perform this turn.
  ///
  /// - Parameters:
  ///   - selection: The action to perform.
  ///   - combatantID: The combatant that selects the action.
  public func select(_ selection: SelectedAction, by combatantID: CombatantID) {
    dispatch(.select(selection, by: combatantID))
  }

  /// Orders the selected actions and starts performing them.
  public func executeTurn() {
    dispatch(.executeTurn)
  }

  /// Performs the next actor's selected action, or ends the turn.
  public func performNextAction() {
    dispatch(.performNextAction)
  }

  /// Performs a basic attack. Damage is derived from the store's rules.
  ///
  /// - Parameters:
  ///   - attacker: The attacking combatant.
  ///   - target: The combatant receiving the attack.
  public func performAttack(attacker: CombatantID, target: CombatantID) {
    dispatch(.attack(attacker: attacker, target: target))
  }

  /// Updates the currently acting combatant.
  ///
  /// - Parameter combatantID: The acting combatant, or `nil` to clear it.
  public func updateCurrentActor(to combatantID: CombatantID?) {
    dispatch(.engine(.updateCurrentActor(combatantID)))
  }

  /// Advances the battle to the next turn.
  public func advanceTurn() {
    dispatch(.engine(.incrementTurn))
  }

  /// Moves the battle to a specific phase.
  ///
  /// - Parameter phase: The phase to enter.
  public func advance(to phase: BattlePhase) {
    dispatch(.engine(.transitionPhase(phase)))
  }
}

// MARK: - State Queries

extension JRPGBattleStore {

  /// Indicates whether the battle has ended.
  public var isBattleEnded: Bool {
    return state.isBattleEnded
  }

  /// Returns the player-controlled combatants that are still active.
  public var alivePlayers: [Combatant] {
    return state.alivePlayers
  }

  /// Returns the enemy combatants that are still active.
  public var aliveEnemies: [Combatant] {
    return state.aliveEnemies
  }

  /// The battle's current phase.
  public var currentPhase: BattlePhase {
    return state.phase
  }

  /// The number of turns that have elapsed.
  public var turnCount: Int {
    return state.turnCount
  }

  /// The combatant currently performing an action.
  public var currentActor: CombatantID? {
    return state.currentActor
  }

  /// Looks up a combatant by identifier.
  ///
  /// - Parameter id: The identifier to search for.
  /// - Returns: The matching combatant, or `nil` when not found.
  public func combatant(for id: CombatantID) -> Combatant? {
    return state.combatants[id]
  }

  /// Determines whether the identifier references a player-controlled combatant.
  ///
  /// - Parameter id: The identifier to inspect.
  /// - Returns: ``true`` when the combatant is controlled by the player.
  public func isPlayer(_ id: CombatantID) -> Bool {
    return state.playerIDs.contains(id)
  }

  /// Determines whether the identifier references an enemy combatant.
  ///
  /// - Parameter id: The identifier to inspect.
  /// - Returns: ``true`` when the combatant is an enemy.
  public func isEnemy(_ id: CombatantID) -> Bool {
    return state.enemyIDs.contains(id)
  }
}

// MARK: - Debug Utilities

extension JRPGBattleStore {

  /// Prints a snapshot of the current state to the console.
  public func logCurrentState() {
    print("=== JRPG Battle State ===")
    print("Phase: \(state.phase)")
    print("Turn: \(state.turnCount)")
    print("Current Actor: \(state.currentActor?.value ?? "none")")
    print("Players: \(state.alivePlayers.count)/\(state.playerIDs.count) alive")
    print("Enemies: \(state.aliveEnemies.count)/\(state.enemyIDs.count) alive")
    print("Pending Commands: \(state.pendingCommands.count)")
    print("=========================")
  }

  /// Prints the recorded action history to the console.
  public func logActionHistory() {
    print("=== Action History ===")
    for (index, action) in actionHistory.enumerated() {
      print("\(index + 1). \(action)")
    }
    print("=====================")
  }
}
