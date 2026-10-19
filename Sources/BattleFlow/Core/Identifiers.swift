/// Identifies how a battle ended.
///
/// The library is rule-agnostic, so rule sets define their own outcomes, for
/// example as static members in an extension.
public struct BattleOutcome: Hashable, Sendable {
  public let value: String

  public init(_ value: String) {
    precondition(!value.isEmpty, "BattleOutcome value must not be empty.")
    self.value = value
  }
}

/// Identifies a combatant participating in the battle.
public struct CombatantID: Hashable, Sendable {
  public let value: String

  public init(_ value: String) {
    precondition(!value.isEmpty, "CombatantID value must not be empty.")
    self.value = value
  }
}

/// Identifies a participant group in a battle.
public struct BattleGroupID: Hashable, Sendable, Equatable {
  public let value: String

  public init(_ value: String) {
    precondition(!value.isEmpty, "BattleGroupID value must not be empty.")
    self.value = value
  }
}
