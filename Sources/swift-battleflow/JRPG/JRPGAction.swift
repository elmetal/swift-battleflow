/// Describes the intents that drive the default JRPG rule set.
///
/// Actions express what a participant wants to do. Outcomes such as damage are
/// derived by ``JRPGReducer`` from ``JRPGRules`` and the current state.
public enum JRPGAction: Sendable, Equatable {
  /// Forwards a rule-agnostic engine action to ``BattleReducer``.
  case engine(BattleAction)

  /// Starts a JRPG battle session.
  ///
  /// - Precondition: Every combatant ID is unique across both rosters.
  case startBattle(players: [Combatant], enemies: [Combatant])

  /// Ends the JRPG battle with the supplied result.
  case endBattle(result: BattleResult)

  /// Performs a basic attack.
  case attack(attacker: CombatantID, target: CombatantID)

  /// Uses a skill against one or more targets.
  case useSkill(user: CombatantID, skill: SkillID, targets: [CombatantID])

  /// Uses an item, optionally selecting a target.
  case useItem(user: CombatantID, item: ItemID, target: CombatantID?)

  /// Raises defenses for the specified combatant.
  case defend(defender: CombatantID)

  /// Attempts to flee from the encounter.
  case escape(escaper: CombatantID)

  /// Requests an AI-controlled combatant to select an action.
  case requestAIDecision(for: CombatantID)
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
