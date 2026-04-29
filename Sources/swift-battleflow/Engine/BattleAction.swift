/// Describes engine-level actions that coordinate battle flow and effects.
public enum EngineAction: Sendable, Equatable {
    /// Starts a battle session.
    case startBattleFlow(players: [Combatant], enemies: [Combatant])

    /// Ends the battle with the supplied result.
    case endBattleFlow(result: BattleResult)

    /// Advances to the next phase in the battle flow.
    case transitionPhase(BattlePhase)

    /// Moves the combat timeline to the next turn.
    case incrementTurn

    /// Sets the combatant that is currently acting.
    case updateCurrentActor(CombatantID?)

    /// Signals the beginning of an action selection phase for a combatant.
    case beginSelection(for: CombatantID)

    /// Completes an action selection with the specified decision.
    case completeSelection(for: CombatantID, action: SelectedAction)

    /// Queues one or more side-effect identifiers for later execution.
    case enqueueEffects([String])  // Effect identifiers.

    /// Executes a previously enqueued effect.
    case markEffectExecuted(String)  // Effect identifier.

    /// Clears all pending effects from the queue.
    case removeAllEffects
}

/// Describes every action that can occur during a battle.
///
/// This compatibility wrapper keeps the public `BattleAction.attack(...)`
/// spelling while separating engine actions from JRPG rule actions internally.
public enum BattleAction: Sendable, Equatable {
    case engine(EngineAction)
    case jrpg(JRPGAction)
}

extension BattleAction {

    // MARK: - Engine Factories

    public static func startBattle(players: [Combatant], enemies: [Combatant]) -> BattleAction {
        .engine(.startBattleFlow(players: players, enemies: enemies))
    }

    public static func endBattle(result: BattleResult) -> BattleAction {
        .engine(.endBattleFlow(result: result))
    }

    public static func advancePhase(_ phase: BattlePhase) -> BattleAction {
        .engine(.transitionPhase(phase))
    }

    public static var advanceTurn: BattleAction {
        .engine(.incrementTurn)
    }

    public static func setCurrentActor(_ actorID: CombatantID?) -> BattleAction {
        .engine(.updateCurrentActor(actorID))
    }

    public static func beginActionSelection(for combatantID: CombatantID) -> BattleAction {
        .engine(.beginSelection(for: combatantID))
    }

    public static func completeActionSelection(
        for combatantID: CombatantID,
        action: SelectedAction
    ) -> BattleAction {
        .engine(.completeSelection(for: combatantID, action: action))
    }

    public static func addEffects(_ effectIDs: [String]) -> BattleAction {
        .engine(.enqueueEffects(effectIDs))
    }

    public static func executeEffect(_ effectID: String) -> BattleAction {
        .engine(.markEffectExecuted(effectID))
    }

    public static var clearEffects: BattleAction {
        .engine(.removeAllEffects)
    }

    // MARK: - JRPG Factories

    public static func attack(
        attacker: CombatantID,
        target: CombatantID,
        damage: Int
    ) -> BattleAction {
        .jrpg(.attack(attacker: attacker, target: target, damage: damage))
    }

    public static func useSkill(
        user: CombatantID,
        skillID: String,
        targets: [CombatantID]
    ) -> BattleAction {
        .jrpg(.useSkill(user: user, skillID: skillID, targets: targets))
    }

    public static func useItem(
        user: CombatantID,
        itemID: String,
        target: CombatantID?
    ) -> BattleAction {
        .jrpg(.useItem(user: user, itemID: itemID, target: target))
    }

    public static func defend(defender: CombatantID) -> BattleAction {
        .jrpg(.defend(defender: defender))
    }

    public static func escape(escaper: CombatantID) -> BattleAction {
        .jrpg(.escape(escaper: escaper))
    }

    public static func changeHP(target: CombatantID, amount: Int) -> BattleAction {
        .jrpg(.changeHP(target: target, amount: amount))
    }

    public static func changeMP(target: CombatantID, amount: Int) -> BattleAction {
        .jrpg(.changeMP(target: target, amount: amount))
    }

    public static func applyStatusEffect(
        target: CombatantID,
        effect: String,
        duration: Int
    ) -> BattleAction {
        .jrpg(.applyStatusEffect(target: target, effect: effect, duration: duration))
    }

    public static func removeStatusEffect(target: CombatantID, effect: String) -> BattleAction {
        .jrpg(.removeStatusEffect(target: target, effect: effect))
    }

    public static func aiDecideAction(for combatantID: CombatantID) -> BattleAction {
        .jrpg(.aiDecideAction(for: combatantID))
    }

    public static func aiExecuteAction(
        for combatantID: CombatantID,
        action: SelectedAction
    ) -> BattleAction {
        .jrpg(.aiExecuteAction(for: combatantID, action: action))
    }

    /// Provides default metadata for the selected action.
    public var metadata: ActionMetadata {
        switch self {
        case .jrpg(.escape):
            return ActionMetadata(priority: .escape, isInstant: true)
        case .jrpg(.useItem):
            return ActionMetadata(priority: .item)
        case .jrpg(.defend):
            return ActionMetadata(priority: .defend)
        case .jrpg(.attack):
            return ActionMetadata(priority: .attack)
        case .jrpg(.useSkill):
            return ActionMetadata(priority: .skill)
        default:
            return ActionMetadata()
        }
    }
    
    /// Indicates whether the action manipulates the combat flow.
    public var isFlowControl: Bool {
        switch self {
        case .engine(.startBattleFlow), .engine(.endBattleFlow), .engine(.transitionPhase),
             .engine(.incrementTurn), .engine(.updateCurrentActor),
             .engine(.beginSelection), .engine(.completeSelection):
            return true
        default:
            return false
        }
    }

    /// Indicates whether the action is driven by a combatant's behavior.
    public var isCharacterAction: Bool {
        switch self {
        case .jrpg(.attack), .jrpg(.useSkill), .jrpg(.useItem),
             .jrpg(.defend), .jrpg(.escape):
            return true
        default:
            return false
        }
    }
}
