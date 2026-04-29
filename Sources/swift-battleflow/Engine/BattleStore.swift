import Foundation
import Observation

/// The central hub of the state-store pattern.
///
/// ``BattleStore`` owns the battle state, processes actions, and coordinates
/// effect execution.
@Observable
@MainActor
public final class BattleStore {

    /// The current battle state.
    public private(set) var state: BattleState

    /// An optional handler used to execute side effects.
    public var effectHandler: ((any Effect) async -> Void)?

    /// The reducer that encapsulates state transition logic.
    private let reducer: BattleReducer

    /// A debug-friendly log of dispatched actions.
    private var actionHistory: [BattleAction] = []

    /// Creates a store using the provided initial battle state.
    ///
    /// - Parameter initialState: The starting state. The default value produces
    ///   an empty battle.
    public init(initialState: BattleState = BattleState()) {
        self.state = initialState
        self.reducer = BattleReducer()
    }

    /// Dispatches a single action synchronously.
    ///
    /// - Parameter action: The action to process.
    public func dispatch(_ action: BattleAction) {
        // Record the action for debugging.
        actionHistory.append(action)

        // Compute the new state and effects via the reducer.
        let (newState, effects) = reducer.reduce(state: state, action: action)

        // Update the state.
        state = newState

        // Run any generated effects.
        Task {
            await executeEffects(effects)
        }
    }

    /// Dispatches a sequence of actions in order.
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
    public func dispatchAsync(_ action: BattleAction) async {
        dispatch(action)
    }

    /// Resets the state to the supplied value or a fresh battle.
    ///
    /// - Parameter newState: The replacement state. When omitted, a new
    ///   ``BattleState`` instance is used.
    public func resetState(_ newState: BattleState? = nil) {
        state = newState ?? BattleState()
        actionHistory.removeAll()
    }

    /// Returns a snapshot of the action history.
    public func getActionHistory() -> [BattleAction] {
        return actionHistory
    }

    /// Clears the recorded action history.
    public func clearActionHistory() {
        actionHistory.removeAll()
    }

    /// Returns the current battle state without mutating it.
    public func getStateSnapshot() -> BattleState {
        return state
    }
}

// MARK: - Effect Execution

extension BattleStore {

    /// Executes the supplied effects in priority order.
    ///
    /// - Parameter effects: The pending effects to run.
    private func executeEffects(_ effects: [any Effect]) async {
        // Sort effects by descending priority.
        let sortedEffects = effects.sorted { $0.priority > $1.priority }

        for effect in sortedEffects {
            await executeEffect(effect)
        }
    }

    /// Executes a single effect.
    ///
    /// - Parameter effect: The effect to run.
    private func executeEffect(_ effect: any Effect) async {
        // Delegate to the effect handler when available.
        if let handler = effectHandler {
            await handler(effect)
        } else {
            // Default behavior simply logs the effect execution.
            print("🎬 Effect executed: \(effect.id) (priority: \(effect.priority))")
        }

        // Inform the reducer that the effect has been executed.
        await MainActor.run {
            dispatch(.executeEffect(effect.id))
        }
    }
}

// MARK: - Convenience API

extension BattleStore {

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
        dispatch(.setCurrentActor(combatantID))
    }

    /// Advances the battle to the next turn.
    public func advanceTurn() {
        dispatch(.advanceTurn)
    }

    /// Moves the battle to a specific phase.
    ///
    /// - Parameter phase: The phase to enter.
    public func advanceToPhase(_ phase: BattlePhase) {
        dispatch(.advancePhase(phase))
    }
}

// MARK: - State Queries

extension BattleStore {

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

extension BattleStore {

    /// Prints a snapshot of the current state to the console.
    public func logCurrentState() {
        print("=== Battle State ===")
        print("Phase: \(state.phase)")
        print("Turn: \(state.turnCount)")
        print("Current Actor: \(state.currentActor?.value ?? "none")")
        print("Players: \(state.alivePlayers.count)/\(state.playerCombatants.count) alive")
        print("Enemies: \(state.aliveEnemies.count)/\(state.enemyCombatants.count) alive")
        print("Pending Effects: \(state.pendingEffects.count)")
        print("==================")
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
