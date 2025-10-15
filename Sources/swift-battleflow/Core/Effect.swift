/// Describes a side effect that occurs as part of the battle system.
///
/// Effects capture animation, sound, UI updates, and other external work so it
/// can remain separate from the pure battle logic.
public protocol Effect: Sendable, Equatable {
    /// A unique identifier for the effect.
    var id: String { get }

    /// The execution priority, where larger values run first.
    var priority: Int { get }
}

/// A convenience implementation of ``Effect``.
public struct BaseEffect: Effect {
    public let id: String
    public let priority: Int
    
    public init(id: String, priority: Int = 0) {
        self.id = id
        self.priority = priority
    }
}

/// A sentinel effect used when no work is required.
public struct NoEffect: Effect {
    public let id: String = "no_effect"
    public let priority: Int = 0
    
    public init() {}
}
