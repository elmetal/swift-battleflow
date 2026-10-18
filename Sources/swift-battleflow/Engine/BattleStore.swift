import Foundation
import Observation

/// The central hub of a state-store feature.
///
/// A store owns state, applies actions through a reducer, executes commands, and
/// starts asynchronous effects that can send follow-up actions.
@Observable
@MainActor
public final class Store<R: Reducer> {

  /// The current state.
  public private(set) var state: R.State

  /// An optional handler used to execute commands.
  public var commandHandler: ((any Command) async -> Void)?

  /// The reducer that encapsulates state transition logic.
  private let reducer: R

  /// A debug-friendly log of dispatched actions.
  public private(set) var actionHistory: [R.Action] = []

  /// The most recently enqueued unit of work.
  ///
  /// Each dispatch chains its work after this task, so commands run in
  /// dispatch order even when the command handler suspends.
  @ObservationIgnored private var lastWork: Task<Void, Never>?

  /// Creates a store using the provided initial state and reducer.
  ///
  /// - Parameters:
  ///   - initialState: The starting state.
  ///   - reducer: The reducer that handles actions.
  public init(initialState: R.State, reducer: R) {
    self.state = initialState
    self.reducer = reducer
  }

  /// Dispatches a single action synchronously.
  ///
  /// The state updates immediately. The reduction's commands run after the
  /// commands of every earlier dispatch, and its effects start once those
  /// commands finish. Effects run concurrently, so their follow-up actions are
  /// dispatched in completion order.
  ///
  /// - Parameter action: The action to process.
  public func dispatch(_ action: R.Action) {
    actionHistory.append(action)

    let reduction = reducer.reduce(state: state, action: action)
    state = reduction.state

    let previousWork = lastWork
    lastWork = Task {
      await previousWork?.value
      await executeCommands(reduction.commands)
      startEffects(reduction.effects)
    }
  }

  /// Waits until the commands of every dispatched action have run, including
  /// actions dispatched while waiting.
  ///
  /// Effects are started but not awaited.
  public func waitForPendingCommands() async {
    while let work = lastWork {
      await work.value
      if lastWork == work {
        lastWork = nil
      }
    }
  }

  /// Dispatches a sequence of actions in order.
  ///
  /// - Parameter actions: The ordered actions to process.
  public func dispatch(_ actions: [R.Action]) {
    for action in actions {
      dispatch(action)
    }
  }

  /// Replaces the state and clears the action history.
  ///
  /// - Parameter newState: The replacement state.
  public func reset(to newState: R.State) {
    state = newState
    actionHistory.removeAll()
  }

  /// Clears the recorded action history.
  public func clearActionHistory() {
    actionHistory.removeAll()
  }
}

/// A store specialized for the rule-agnostic battle engine.
public typealias BattleStore = Store<BattleReducer>

extension BattleStore {
  /// Creates a store using the provided initial engine state.
  ///
  /// - Parameter initialState: The starting state. The default value produces
  ///   an empty battle.
  public convenience init(initialState: BattleState = BattleState()) {
    self.init(initialState: initialState, reducer: BattleReducer())
  }

  /// Resets the store to a fresh battle and clears the action history.
  public func reset() {
    reset(to: BattleState())
  }
}

// MARK: - Work Execution

extension Store {

  /// Executes the supplied commands in priority order.
  ///
  /// - Parameter commands: The pending commands to run.
  private func executeCommands(_ commands: [any Command]) async {
    let sortedCommands = commands.sorted { $0.priority > $1.priority }

    for command in sortedCommands {
      await executeCommand(command)
    }
  }

  /// Executes a single command.
  ///
  /// - Parameter command: The command to run.
  private func executeCommand(_ command: any Command) async {
    if let handler = commandHandler {
      await handler(command)
    } else {
      print("🎬 Command executed: \(command.id) (priority: \(command.priority))")
    }
  }

  /// Starts effects that can produce follow-up actions.
  ///
  /// - Parameter effects: The effects to run.
  private func startEffects(_ effects: [Effect<R.Action>]) {
    for effect in effects {
      Task {
        if let action = await effect.run() {
          dispatch(action)
        }
      }
    }
  }
}

// MARK: - Convenience API

extension BattleStore {

  /// Updates the currently acting participant.
  ///
  /// - Parameter participantID: The acting participant, or `nil` to clear it.
  public func updateCurrentActor(to participantID: CombatantID?) {
    dispatch(.updateCurrentActor(participantID))
  }

  /// Advances the battle to the next turn.
  public func advanceTurn() {
    dispatch(.incrementTurn)
  }

  /// Moves the battle to a specific phase.
  ///
  /// - Parameter phase: The phase to enter.
  public func advance(to phase: BattlePhase) {
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
  public var turnCount: Int {
    return state.turnCount
  }

  /// The participant currently performing an action.
  public var currentActor: CombatantID? {
    return state.currentActor
  }

  /// Returns whether the combatant takes part in the battle.
  public func isParticipant(_ id: CombatantID) -> Bool {
    return state.participants.contains(id)
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
