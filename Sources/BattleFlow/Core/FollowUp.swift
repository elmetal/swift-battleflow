/// Asynchronous work that can feed a follow-up action back into a store.
///
/// Follow-ups suit work that happens outside the reducer and ends in an action,
/// such as waiting for a timer or for input, or asking a server. Use ``Command``
/// for one-way work that doesn't produce a new action.
public struct FollowUp<Action: Sendable>: Sendable {
  private let operation: @Sendable () async -> Action?

  /// Creates a follow-up from an asynchronous operation.
  ///
  /// - Parameter operation: A closure that optionally returns an action.
  public init(_ operation: @escaping @Sendable () async -> Action?) {
    self.operation = operation
  }

  /// Creates a follow-up that immediately returns an action.
  ///
  /// - Parameter action: The action to send back into the store.
  public static func send(_ action: Action) -> FollowUp {
    FollowUp { action }
  }

  /// Creates a follow-up that performs no work.
  public static var none: FollowUp {
    FollowUp { nil }
  }

  /// Runs the follow-up and returns the action it produces, if any.
  public func run() async -> Action? {
    await operation()
  }

  /// Returns a follow-up that transforms the produced action.
  ///
  /// Use this to embed a child reducer's follow-ups into a parent action type.
  ///
  /// - Parameter transform: A closure that converts the produced action.
  public func map<NewAction: Sendable>(
    _ transform: @escaping @Sendable (Action) -> NewAction
  ) -> FollowUp<NewAction> {
    FollowUp<NewAction> { await self.run().map(transform) }
  }
}
