import Foundation
import Observation

/// A battle store for the default JRPG rule set.
@Observable
@MainActor
public final class JRPGBattleStore {

  /// The current JRPG battle state.
  public private(set) var state: JRPGBattleState

  /// An optional handler used to execute side effects.
  public var effectHandler: ((any Effect) async -> Void)?

  /// A debug-friendly log of dispatched JRPG actions.
  private var actionHistory: [JRPGAction] = []

  /// A debug-friendly log of dispatched engine actions.
  private var battleActionHistory: [BattleAction] = []

  /// Creates a store using the provided initial JRPG battle state.
  ///
  /// - Parameter initialState: The starting state. The default value produces
  ///   an empty battle.
  public init(initialState: JRPGBattleState = JRPGBattleState()) {
    self.state = initialState
  }

  /// Dispatches a single action synchronously.
  ///
  /// - Parameter action: The action to process.
  public func dispatch(_ action: JRPGAction) {
    actionHistory.append(action)

    let (newState, effects) = JRPGReducer().reduce(state: state, action: action)
    state = newState

    Task {
      await executeEffects(effects)
    }
  }

  /// Dispatches a single engine action synchronously.
  ///
  /// - Parameter action: The engine action to process.
  public func dispatch(_ action: BattleAction) {
    battleActionHistory.append(action)

    let (newState, effects) = BattleReducer().reduce(state: state, action: action)
    state = newState

    Task {
      await executeEffects(effects)
    }
  }

  /// Dispatches a sequence of actions in order.
  ///
  /// - Parameter actions: The ordered actions to process.
  public func dispatch(_ actions: [JRPGAction]) {
    for action in actions {
      dispatch(action)
    }
  }

  /// Dispatches a sequence of engine actions in order.
  ///
  /// - Parameter actions: The ordered actions to process.
  public func dispatch(_ actions: [BattleAction]) {
    for action in actions {
      dispatch(action)
    }
  }

  /// Dispatches an action from asynchronous contexts.
  ///
  /// - Parameter action: The action to process.
  public func dispatchAsync(_ action: JRPGAction) async {
    dispatch(action)
  }

  /// Dispatches an engine action from asynchronous contexts.
  ///
  /// - Parameter action: The action to process.
  public func dispatchAsync(_ action: BattleAction) async {
    dispatch(action)
  }

  /// Resets the state to the supplied value or a fresh battle.
  ///
  /// - Parameter newState: The replacement state. When omitted, a new
  ///   ``JRPGBattleState`` instance is used.
  public func resetState(_ newState: JRPGBattleState? = nil) {
    state = newState ?? JRPGBattleState()
    actionHistory.removeAll()
    battleActionHistory.removeAll()
  }

  /// Returns a snapshot of the action history.
  public func getActionHistory() -> [JRPGAction] {
    return actionHistory
  }

  /// Returns a snapshot of the engine action history.
  public func getBattleActionHistory() -> [BattleAction] {
    return battleActionHistory
  }

  /// Clears the recorded action history.
  public func clearActionHistory() {
    actionHistory.removeAll()
    battleActionHistory.removeAll()
  }

  /// Returns the current battle state without mutating it.
  public func getStateSnapshot() -> JRPGBattleState {
    return state
  }
}

// MARK: - Effect Execution

extension JRPGBattleStore {

  /// Executes the supplied effects in priority order.
  ///
  /// - Parameter effects: The pending effects to run.
  private func executeEffects(_ effects: [any Effect]) async {
    let sortedEffects = effects.sorted { $0.priority > $1.priority }

    for effect in sortedEffects {
      await executeEffect(effect)
    }
  }

  /// Executes a single effect.
  ///
  /// - Parameter effect: The effect to run.
  private func executeEffect(_ effect: any Effect) async {
    if let handler = effectHandler {
      await handler(effect)
    } else {
      print("🎬 Effect executed: \(effect.id) (priority: \(effect.priority))")
    }

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

  /// Performs an attack action with precomputed damage.
  ///
  /// - Parameters:
  ///   - attacker: The attacking combatant.
  ///   - target: The combatant receiving the attack.
  ///   - damage: The amount of damage to apply.
  public func performAttack(attacker: CombatantID, target: CombatantID, damage: Int) {
    dispatch(.attack(attacker: attacker, target: target, damage: damage))
  }

  /// Adjusts a combatant's hit points.
  ///
  /// - Parameters:
  ///   - target: The combatant receiving the change.
  ///   - amount: The delta to apply. Positive values heal, negative values
  ///     inflict damage.
  public func changeHP(target: CombatantID, amount: Int) {
    dispatch(.changeHP(target: target, amount: amount))
  }

  /// Updates the currently acting combatant.
  ///
  /// - Parameter combatantID: The acting combatant, or `nil` to clear it.
  public func setCurrentActor(_ combatantID: CombatantID?) {
    dispatch(.updateCurrentActor(combatantID))
  }

  /// Advances the battle to the next turn.
  public func advanceTurn() {
    dispatch(.incrementTurn)
  }

  /// Moves the battle to a specific phase.
  ///
  /// - Parameter phase: The phase to enter.
  public func advanceToPhase(_ phase: BattlePhase) {
    dispatch(.transitionPhase(phase))
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
  public var currentTurn: Int {
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
  public func getCombatant(_ id: CombatantID) -> Combatant? {
    return state.combatants[id]
  }

  /// Determines whether the identifier references a player-controlled combatant.
  ///
  /// - Parameter id: The identifier to inspect.
  /// - Returns: ``true`` when the combatant is controlled by the player.
  public func isPlayerCombatant(_ id: CombatantID) -> Bool {
    return state.playerCombatants.contains(id)
  }

  /// Determines whether the identifier references an enemy combatant.
  ///
  /// - Parameter id: The identifier to inspect.
  /// - Returns: ``true`` when the combatant is an enemy.
  public func isEnemyCombatant(_ id: CombatantID) -> Bool {
    return state.enemyCombatants.contains(id)
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
    print("Players: \(state.alivePlayers.count)/\(state.playerCombatants.count) alive")
    print("Enemies: \(state.aliveEnemies.count)/\(state.enemyCombatants.count) alive")
    print("Pending Effects: \(state.pendingEffects.count)")
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
