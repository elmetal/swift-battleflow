/// A source of randomness that a reducer can use without giving up purity.
///
/// A battle generator is a value: it lives in battle state, and the reducer
/// stores the advanced generator in the state it returns. As a result, the same
/// state and action always produce the same result, which keeps battles
/// replayable and testable.
///
/// Conforming types must be values. Two generators that compare equal must
/// produce the same rolls, so the next rolls depend only on the stored
/// properties. Sources that consult the outside world on every call, such as
/// `SystemRandomNumberGenerator`, are side effects rather than values; use them to
/// create a seed instead. See <doc:ChoosingARandomGenerator>.
public protocol BattleRandomGenerator: Sendable, Equatable {
  /// Returns the next roll and advances the generator.
  ///
  /// - Postcondition: The roll is in `0..<1`.
  mutating func nextRoll() -> Double
}

/// A seedable generator that implements SplitMix64.
///
/// The algorithm is fixed, so a seed reproduces the same rolls on every
/// platform and Swift version.
public struct SeededBattleRandomGenerator: BattleRandomGenerator {
  private var state: UInt64

  /// Creates a generator whose rolls are determined by the seed.
  public init(seed: UInt64) {
    self.state = seed
  }

  public mutating func nextRoll() -> Double {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    z ^= z >> 31

    // Use the top 53 bits, which a Double represents exactly, to get 0..<1.
    return Double(z >> 11) * 0x1.0p-53
  }
}

/// A generator that returns predetermined rolls in order.
///
/// Use it in tests to make a specific outcome happen, for example a roll of
/// `0.99` for a critical hit.
public struct ScriptedBattleRandomGenerator: BattleRandomGenerator {
  /// The rolls that have not been returned yet.
  public private(set) var remainingRolls: [Double]

  /// Creates a generator that returns the rolls in order.
  ///
  /// - Precondition: Every roll is in `0..<1`.
  public init(_ rolls: [Double]) {
    precondition(rolls.allSatisfy { (0..<1).contains($0) }, "Rolls must be in 0..<1.")
    self.remainingRolls = rolls
  }

  /// Returns the next scripted roll.
  ///
  /// - Precondition: At least one roll remains.
  public mutating func nextRoll() -> Double {
    precondition(!remainingRolls.isEmpty, "ScriptedBattleRandomGenerator ran out of rolls.")
    return remainingRolls.removeFirst()
  }
}
