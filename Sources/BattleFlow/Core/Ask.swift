/// Asynchronous work that a reducer asks the outside world to do, whose
/// answer, if any, is dispatched back as the next action.
///
/// Asks suit work that happens outside the reducer and ends in an action, such
/// as waiting for a timer or for input, or asking a server. Use a reducer's
/// outputs for things the outside world only needs to hear about.
public struct Ask<Action: Sendable>: Sendable {
  private let operation: @Sendable () async -> Action?

  /// Creates an ask from an asynchronous operation.
  ///
  /// - Parameter operation: A closure that returns the answer, or `nil` for
  ///   none.
  public init(_ operation: @escaping @Sendable () async -> Action?) {
    self.operation = operation
  }

  /// Creates an ask that answers with an action right away.
  public static func answer(_ action: Action) -> Ask {
    Ask { action }
  }

  /// Creates an ask that does nothing and never answers.
  public static var none: Ask {
    Ask { nil }
  }

  /// Runs the ask and returns its answer, if any.
  public func run() async -> Action? {
    await operation()
  }

  /// Returns an ask that transforms the answer.
  ///
  /// Use this to embed a child reducer's asks into a parent action type.
  ///
  /// - Parameter transform: A closure that converts the answer.
  public func map<NewAction: Sendable>(
    _ transform: @escaping @Sendable (Action) -> NewAction
  ) -> Ask<NewAction> {
    Ask<NewAction> { await self.run().map(transform) }
  }
}
