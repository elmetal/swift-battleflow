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
