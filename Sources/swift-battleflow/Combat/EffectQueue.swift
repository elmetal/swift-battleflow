/// An effect waiting for a turn boundary.
public struct ScheduledEffect<Rules: CombatRules>: Sendable, Equatable {
  /// The effect to queue when it is due.
  public let effect: Rules.Effect

  /// The boundary that counts towards the effect.
  public let boundary: Rules.Turns.Boundary

  /// How many more times the boundary has to be reached; the effect is queued
  /// when this reaches zero.
  public internal(set) var remainingOccurrences: Int
}

/// The effects waiting to be applied, and the effects scheduled for later.
///
/// The combat layer applies effects one at a time from the front of the
/// queue. After each one, ``CombatRules/react(to:in:queue:random:)`` can add
/// effects that run next or last, or schedule effects for a turn boundary.
public struct EffectQueue<Rules: CombatRules>: Sendable {
  /// The effects waiting to be applied, in order.
  public private(set) var pending: [Rules.Effect]

  /// The effects waiting for a turn boundary.
  public private(set) var scheduled: [ScheduledEffect<Rules>]

  /// Creates a queue with the given effects and nothing scheduled.
  public init(_ effects: [Rules.Effect]) {
    self.init(effects, scheduled: [])
  }

  init(_ effects: [Rules.Effect], scheduled: [ScheduledEffect<Rules>]) {
    self.pending = effects
    self.scheduled = scheduled
  }

  /// Adds an effect that runs next, before every effect already waiting.
  public mutating func prepend(_ effect: Rules.Effect) {
    pending.insert(effect, at: 0)
  }

  /// Adds effects that run next, in the given order, before every effect
  /// already waiting.
  public mutating func prepend(contentsOf effects: [Rules.Effect]) {
    pending.insert(contentsOf: effects, at: 0)
  }

  /// Adds an effect that runs after every effect already waiting.
  public mutating func append(_ effect: Rules.Effect) {
    pending.append(effect)
  }

  /// Adds effects that run, in the given order, after every effect already
  /// waiting.
  public mutating func append(contentsOf effects: [Rules.Effect]) {
    pending.append(contentsOf: effects)
  }

  /// Schedules an effect to be queued when the turn system reaches a boundary
  /// for the given number of times.
  ///
  /// - Precondition: `occurrence` is at least 1.
  public mutating func schedule(
    _ effect: Rules.Effect, at boundary: Rules.Turns.Boundary, occurrence: Int = 1
  ) {
    precondition(occurrence >= 1, "A scheduled effect needs an occurrence of at least 1.")
    scheduled.append(
      ScheduledEffect(effect: effect, boundary: boundary, remainingOccurrences: occurrence))
  }

  /// Removes the scheduled effects that match the predicate.
  public mutating func cancelScheduled(where shouldCancel: (ScheduledEffect<Rules>) -> Bool) {
    scheduled.removeAll(where: shouldCancel)
  }

  /// Removes and returns the next effect to apply.
  mutating func popNext() -> Rules.Effect? {
    pending.isEmpty ? nil : pending.removeFirst()
  }

  /// Counts a reached boundary and returns the scheduled effects that became
  /// due, in the order they were scheduled.
  mutating func reach(_ boundary: Rules.Turns.Boundary) -> [Rules.Effect] {
    var due: [Rules.Effect] = []
    var remaining: [ScheduledEffect<Rules>] = []
    for var entry in scheduled {
      if entry.boundary == boundary {
        entry.remainingOccurrences -= 1
      }
      if entry.remainingOccurrences == 0 {
        due.append(entry.effect)
      } else {
        remaining.append(entry)
      }
    }
    scheduled = remaining
    return due
  }
}
