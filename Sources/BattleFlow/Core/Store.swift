import Observation

/// The central hub of a state-store feature.
///
/// A store owns state, applies actions through a reducer, delivers the
/// reducer's outputs, and runs its asks, dispatching their answers.
@Observable
@MainActor
public final class Store<R: Reducer> {

  /// The current state.
  public private(set) var state: R.State

  /// Receives the reducer's outputs, in the order they were emitted.
  ///
  /// Without a handler, outputs are dropped.
  public var outputHandler: ((R.Output) async -> Void)?

  /// The reducer that encapsulates state transition logic.
  private let reducer: R

  /// A debug-friendly log of dispatched actions.
  public private(set) var actionHistory: [R.Action] = []

  /// The most recently enqueued unit of work.
  ///
  /// Each dispatch chains its work after this task, so outputs are delivered
  /// in dispatch order even when the output handler suspends.
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
  /// The state updates immediately. The reduction's outputs are delivered in
  /// order after the outputs of every earlier dispatch, and its asks start
  /// once those outputs have been handled. Asks run concurrently, so their
  /// answers are dispatched in completion order.
  ///
  /// - Parameter action: The action to process.
  public func dispatch(_ action: R.Action) {
    actionHistory.append(action)

    let reduction = reducer.reduce(state: state, action: action)
    state = reduction.state

    let previousWork = lastWork
    lastWork = Task {
      await previousWork?.value
      await deliver(reduction.outputs)
      start(reduction.asks)
    }
  }

  /// Waits until the outputs of every dispatched action have been handled,
  /// including actions dispatched while waiting.
  ///
  /// Asks are started but not awaited.
  public func waitForPendingOutputs() async {
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

// MARK: - Work Execution

extension Store {

  /// Delivers outputs to the handler, in order.
  private func deliver(_ outputs: [R.Output]) async {
    guard let outputHandler else {
      return
    }
    for output in outputs {
      await outputHandler(output)
    }
  }

  /// Starts asks, dispatching each answer when it arrives.
  private func start(_ asks: [Ask<R.Action>]) {
    for ask in asks {
      Task {
        if let action = await ask.run() {
          dispatch(action)
        }
      }
    }
  }
}
