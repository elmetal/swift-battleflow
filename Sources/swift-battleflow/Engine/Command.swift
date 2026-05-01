/// Describes external work that a reducer requests after a state transition.
///
/// Commands represent one-way notifications such as animations, sounds, logging,
/// and UI updates. They don't feed actions back into the store.
public protocol Command: Sendable, Equatable {
  /// A unique identifier for the command.
  var id: String { get }

  /// The execution priority, where larger values run first.
  var priority: Int { get }
}

/// A convenience implementation of ``Command``.
public struct BaseCommand: Command {
  public let id: String
  public let priority: Int

  public init(id: String, priority: Int = 0) {
    self.id = id
    self.priority = priority
  }
}

/// A sentinel command used when no work is required.
public struct NoCommand: Command {
  public let id: String = "no_command"
  public let priority: Int = 0

  public init() {}
}

/// Asynchronous work that can feed an action back into a store.
///
/// Effects are appropriate for work such as AI decisions, random rolls, timers,
/// and input waits. Use ``Command`` for one-way work that doesn't produce a new
/// action.
public struct Effect<Action: Sendable>: Sendable {
  private let operation: @Sendable () async -> Action?

  /// Creates an effect from an asynchronous operation.
  ///
  /// - Parameter operation: A closure that optionally returns an action.
  public init(_ operation: @escaping @Sendable () async -> Action?) {
    self.operation = operation
  }

  /// Creates an effect that immediately returns an action.
  ///
  /// - Parameter action: The action to send back into the store.
  public static func send(_ action: Action) -> Effect {
    Effect { action }
  }

  /// Creates an effect that performs no work.
  public static var none: Effect {
    Effect { nil }
  }

  /// Runs the effect and returns the action it produces, if any.
  public func run() async -> Action? {
    await operation()
  }
}
