/// A type that transforms state in response to actions.
///
/// A reducer is a pure function. Besides the new state, it describes what the
/// outside world should hear about, as outputs, and what it needs from the
/// outside world, as asks. The store delivers the outputs and runs the asks.
public protocol Reducer: Sendable {
  associatedtype State: Sendable
  associatedtype Action: Sendable

  /// What the reducer tells the outside world, such as facts for a
  /// presentation layer or instructions to play a sound. Use `Never` when the
  /// reducer has no outputs.
  associatedtype Output: Sendable

  /// Returns the result of applying an action to a state.
  ///
  /// - Parameters:
  ///   - state: The state to transform.
  ///   - action: The action to apply.
  /// - Returns: A reduction containing the transformed state, its outputs,
  ///   and its asks.
  func reduce(state: State, action: Action) -> Reduction<State, Action, Output>
}

/// The result of reducing an action into state.
public struct Reduction<State: Sendable, Action: Sendable, Output: Sendable>: Sendable {
  /// The transformed state.
  public let state: State

  /// What to tell the outside world, in order. Outputs get no reply.
  public let outputs: [Output]

  /// What to ask of the outside world. An ask's answer, if any, is dispatched
  /// back as the next action.
  public let asks: [Ask<Action>]

  /// Creates a reduction result.
  ///
  /// - Parameters:
  ///   - state: The transformed state.
  ///   - outputs: What to tell the outside world, in order.
  ///   - asks: What to ask of the outside world.
  public init(state: State, outputs: [Output] = [], asks: [Ask<Action>] = []) {
    self.state = state
    self.outputs = outputs
    self.asks = asks
  }
}
