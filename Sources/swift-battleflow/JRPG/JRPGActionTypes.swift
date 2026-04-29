/// Represents the outcome of a JRPG battle.
public enum BattleResult: Sendable, Equatable {
  case victory  // Player victory.
  case defeat  // Player defeat.
  case escape  // Successful escape.
  case draw  // Neither side prevails.
}

/// The action that a combatant ultimately chooses to perform.
public enum SelectedAction: Sendable, Equatable {
  case attack(target: CombatantID)
  case skill(id: String, targets: [CombatantID])
  case item(id: String, target: CombatantID?)
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
      return BattleSelection(id: "jrpg.skill.\(id)")
    case .item(let id, _):
      return BattleSelection(id: "jrpg.item.\(id)")
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
