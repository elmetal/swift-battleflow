import Foundation
import Observation

/// The central hub of the engine state-store pattern.
///
/// ``BattleStore`` owns rule-agnostic battle state, processes engine actions,
/// and coordinates effect execution.
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

  /// Creates a store using the provided initial engine state.
  ///
  /// - Parameter initialState: The starting state. The default value produces
  ///   an empty battle.
  public init(initialState: BattleState = BattleState()) {
    self.state = initialState
    self.reducer = BattleReducer()
  }

  /// Dispatches a single engine action synchronously.
  ///
  /// - Parameter action: The engine action to process.
  public func dispatch(_ action: BattleAction) {
    actionHistory.append(action)

    let (newState, effects) = reducer.reduce(state: state, action: action)
    state = newState

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

    await MainActor.run {
      dispatch(.markEffectExecuted(effect.id))
    }
  }
}

// MARK: - Convenience API

extension BattleStore {

  /// Updates the currently acting participant.
  ///
  /// - Parameter participantID: The acting participant, or `nil` to clear it.
  public func setCurrentActor(_ participantID: CombatantID?) {
    dispatch(.updateCurrentActor(participantID))
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

extension BattleStore {

  /// Indicates whether the battle has ended.
  public var isBattleEnded: Bool {
    return state.isBattleEnded
  }

  /// The battle's current phase.
  public var currentPhase: BattlePhase {
    return state.phase
  }

  /// The number of turns that have elapsed.
  public var currentTurn: Int {
    return state.turnCount
  }

  /// The participant currently performing an action.
  public var currentActor: CombatantID? {
    return state.currentActor
  }

  /// Looks up a participant by identifier.
  ///
  /// - Parameter id: The identifier to search for.
  /// - Returns: The matching participant, or `nil` when not found.
  public func getParticipant(_ id: CombatantID) -> BattleParticipant? {
    return state.participants[id]
  }

  /// Returns whether the participant belongs to the provided group.
  public func isParticipant(_ id: CombatantID, in group: BattleGroupID) -> Bool {
    return state.participantIDs(in: group).contains(id)
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
    print("Participants: \(state.participants.count)")
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
