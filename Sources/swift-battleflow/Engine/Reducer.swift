/// A type that transforms state in response to actions.
public protocol Reducer: Sendable {
  associatedtype State: Sendable
  associatedtype Action: Sendable

  /// Returns the result of applying an action to a state.
  ///
  /// - Parameters:
  ///   - state: The state to transform.
  ///   - action: The action to apply.
  /// - Returns: A reduction containing the transformed state and generated work.
  func reduce(state: State, action: Action) -> Reduction<State, Action>
}

/// The result of reducing an action into state.
public struct Reduction<State: Sendable, Action: Sendable>: Sendable {
  /// The transformed state.
  public let state: State

  /// One-way work for animation, sound, logging, or UI updates.
  public let commands: [any Command]

  /// Asynchronous work that can produce follow-up actions.
  public let effects: [Effect<Action>]

  /// Creates a reduction result.
  ///
  /// - Parameters:
  ///   - state: The transformed state.
  ///   - commands: One-way work for external systems.
  ///   - effects: Asynchronous work that can produce follow-up actions.
  public init(
    state: State,
    commands: [any Command] = [],
    effects: [Effect<Action>] = []
  ) {
    self.state = state
    self.commands = commands
    self.effects = effects
  }
}
