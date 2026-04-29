/// Describes actions that belong to the default JRPG rule set.
public enum JRPGAction: Sendable, Equatable {
  /// Starts a JRPG battle session.
  case startBattle(players: [Combatant], enemies: [Combatant])

  /// Ends the JRPG battle with the supplied result.
  case endBattle(result: BattleResult)

  /// Performs a basic attack.
  case attack(attacker: CombatantID, target: CombatantID, damage: Int)

  /// Uses a skill against one or more targets.
  case useSkill(user: CombatantID, skillID: String, targets: [CombatantID])

  /// Uses an item, optionally selecting a target.
  case useItem(user: CombatantID, itemID: String, target: CombatantID?)

  /// Raises defenses for the specified combatant.
  case defend(defender: CombatantID)

  /// Attempts to flee from the encounter.
  case escape(escaper: CombatantID)

  /// Modifies the target's hit points by a positive or negative amount.
  case changeHP(target: CombatantID, amount: Int)

  /// Modifies the target's magic points by a positive or negative amount.
  case changeMP(target: CombatantID, amount: Int)

  /// Applies a named status effect for a given duration.
  case applyStatusEffect(target: CombatantID, effect: String, duration: Int)

  /// Removes a specific status effect from the target.
  case removeStatusEffect(target: CombatantID, effect: String)

  /// Requests an AI-controlled combatant to select an action.
  case aiDecideAction(for: CombatantID)

  /// Executes the decision returned by the AI.
  case aiExecuteAction(for: CombatantID, action: SelectedAction)
}

extension JRPGAction {
  /// Provides default metadata for the selected action.
  public var metadata: ActionMetadata {
    switch self {
    case .escape:
      return ActionMetadata(priority: .escape, isInstant: true)
    case .useItem:
      return ActionMetadata(priority: .item)
    case .defend:
      return ActionMetadata(priority: .defend)
    case .attack:
      return ActionMetadata(priority: .attack)
    case .useSkill:
      return ActionMetadata(priority: .skill)
    default:
      return ActionMetadata()
    }
  }
}
