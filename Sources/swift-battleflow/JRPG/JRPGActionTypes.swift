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

  /// Returns the effect of an item, or `nil` when the item is not defined.
  ///
  /// Effect amounts must be positive.
  public let itemEffect: @Sendable (ItemID) -> ItemEffect?

  public init(
    physicalDamage: @escaping @Sendable (_ attacker: Stats, _ defender: Stats) -> Int,
    itemEffect: @escaping @Sendable (ItemID) -> ItemEffect? = { _ in nil }
  ) {
    self.physicalDamage = physicalDamage
    self.itemEffect = itemEffect
  }

  /// The default rules.
  ///
  /// Physical damage is attack minus half of defense, with a minimum of one.
  /// A potion restores 50 HP, an ether restores 30 MP, and a phoenix down
  /// revives with 1 HP.
  public static let standard = JRPGRules(
    physicalDamage: { attacker, defender in
      max(1, attacker.attack - defender.defense / 2)
    },
    itemEffect: { item in
      switch item {
      case .potion: .restoreHP(50)
      case .ether: .restoreMP(30)
      case .phoenixDown: .revive(hp: 1)
      default: nil
      }
    }
  )
}

/// Describes what an item does to its target.
public enum ItemEffect: Sendable, Equatable {
  /// Restores HP of a living target, up to its maximum.
  case restoreHP(Int)

  /// Restores MP of a living target, up to its maximum.
  case restoreMP(Int)

  /// Revives a defeated target with the given HP, up to its maximum.
  case revive(hp: Int)
}

/// Items defined by the standard rules.
extension ItemID {
  public static let potion = ItemID("potion")
  public static let ether = ItemID("ether")
  public static let phoenixDown = ItemID("phoenix_down")
}

/// The action that a combatant ultimately chooses to perform.
public enum SelectedAction: Sendable, Equatable {
  case attack(target: CombatantID)
  case skill(id: SkillID, targets: [CombatantID])
  case item(id: ItemID, target: CombatantID?)
  case defend
  case escape
}

/// The relative priority assigned to a JRPG action.
///
/// Within a turn, actions with a higher priority are performed first.
public enum ActionPriority: Int, CaseIterable, Comparable, Sendable {
  case lowest = 0
  case low = 1
  case normal = 2
  case high = 3
  case highest = 4

  public static func < (lhs: ActionPriority, rhs: ActionPriority) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

extension SelectedAction {
  /// The priority used to order this action within a turn.
  ///
  /// Escaping and defending take effect before attacks, items come next, and
  /// attacks and skills follow.
  public var priority: ActionPriority {
    switch self {
    case .escape, .defend: .highest
    case .item: .high
    case .attack, .skill: .normal
    }
  }

  /// Returns the intent that performs this action for the given actor.
  func intent(by actor: CombatantID) -> JRPGAction {
    switch self {
    case .attack(let target): .attack(attacker: actor, target: target)
    case .skill(let id, let targets): .useSkill(user: actor, skill: id, targets: targets)
    case .item(let id, let target): .useItem(user: actor, item: id, target: target)
    case .defend: .defend(defender: actor)
    case .escape: .escape(escaper: actor)
    }
  }
}
