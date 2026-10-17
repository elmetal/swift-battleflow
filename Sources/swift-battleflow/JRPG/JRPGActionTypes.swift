/// Represents the outcome of a JRPG battle.
public enum BattleResult: Sendable, Equatable {
  case victory  // Player victory.
  case defeat  // Player defeat.
  case escape  // Successful escape.
  case draw  // Neither side prevails.
}

/// Engine outcomes for the default JRPG results.
extension BattleOutcome {
  public static let victory = BattleOutcome("jrpg.victory")
  public static let defeat = BattleOutcome("jrpg.defeat")
  public static let escape = BattleOutcome("jrpg.escape")
  public static let draw = BattleOutcome("jrpg.draw")
}

extension BattleResult {
  /// The engine outcome that represents this result.
  public var outcome: BattleOutcome {
    switch self {
    case .victory: .victory
    case .defeat: .defeat
    case .escape: .escape
    case .draw: .draw
    }
  }

  /// Creates the result that corresponds to an engine outcome, or `nil` when
  /// the outcome does not belong to the JRPG rule set.
  public init?(outcome: BattleOutcome) {
    switch outcome {
    case .victory: self = .victory
    case .defeat: self = .defeat
    case .escape: self = .escape
    case .draw: self = .draw
    default: return nil
    }
  }
}

/// Identifies a skill in the default JRPG rule set.
public struct SkillID: Hashable, Sendable {
  public let value: String

  public init(_ value: String) {
    precondition(!value.isEmpty, "SkillID value must not be empty.")
    self.value = value
  }
}

/// Identifies an item in the default JRPG rule set.
public struct ItemID: Hashable, Sendable {
  public let value: String

  public init(_ value: String) {
    precondition(!value.isEmpty, "ItemID value must not be empty.")
    self.value = value
  }
}

/// Calculates outcomes for the default JRPG rule set.
public struct JRPGRules: Sendable {
  /// Returns the physical damage dealt by an attacker to a defender.
  ///
  /// The result must not be negative.
  public let physicalDamage: @Sendable (_ attacker: Stats, _ defender: Stats) -> Int

  public init(physicalDamage: @escaping @Sendable (_ attacker: Stats, _ defender: Stats) -> Int) {
    self.physicalDamage = physicalDamage
  }

  /// The default rules: attack minus half of defense, with a minimum of one.
  public static let standard = JRPGRules { attacker, defender in
    max(1, attacker.attack - defender.defense / 2)
  }
}

/// The action that a combatant ultimately chooses to perform.
public enum SelectedAction: Sendable, Equatable {
  case attack(target: CombatantID)
  case skill(id: SkillID, targets: [CombatantID])
  case item(id: ItemID, target: CombatantID?)
  case defend
  case escape
}

extension SelectedAction {
  /// Provides the engine-level selection identity for this JRPG action.
  public var battleSelection: BattleSelection {
    switch self {
    case .attack:
      return BattleSelection(id: "jrpg.attack")
    case .skill(let id, _):
      return BattleSelection(id: "jrpg.skill.\(id.value)")
    case .item(let id, _):
      return BattleSelection(id: "jrpg.item.\(id.value)")
    case .defend:
      return BattleSelection(id: "jrpg.defend")
    case .escape:
      return BattleSelection(id: "jrpg.escape")
    }
  }
}

/// The relative priority assigned to a JRPG action.
public enum ActionPriority: Int, CaseIterable, Sendable {
  case lowest = 0
  case low = 1
  case normal = 2
  case high = 3
  case highest = 4

  /// The priority used when a combatant attempts to escape.
  public static let escape: ActionPriority = .highest

  /// The priority used when a combatant consumes an item.
  public static let item: ActionPriority = .high

  /// The default priority assigned to skill usage.
  public static let skill: ActionPriority = .normal

  /// The priority used for standard attacks.
  public static let attack: ActionPriority = .normal

  /// The priority used when a combatant defends.
  public static let defend: ActionPriority = .low
}

/// Metadata that influences how a JRPG action is scheduled or executed.
public struct ActionMetadata: Sendable, Equatable {
  public let priority: ActionPriority
  public let speed: Int
  public let isInstant: Bool  // Indicates immediate execution.

  public init(
    priority: ActionPriority = .normal,
    speed: Int = 0,
    isInstant: Bool = false
  ) {
    self.priority = priority
    self.speed = speed
    self.isInstant = isInstant
  }
}
