/// Describes every action that can occur during a battle.
///
/// Each case represents an event that triggers a state transition within the
/// state-store architecture.
public enum BattleAction: Sendable {

    // MARK: - Battle Flow Control
    /// Starts a battle session.
    case startBattle(players: [Combatant], enemies: [Combatant])

    /// Ends the battle with the supplied result.
    case endBattle(result: BattleResult)

    /// Advances to the next phase in the battle flow.
    case advancePhase(BattlePhase)

    /// Moves the combat timeline to the next turn.
    case advanceTurn

    // MARK: - Character Actions
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

    // MARK: - Status Adjustments
    /// Modifies the target's hit points by a positive or negative amount.
    case changeHP(target: CombatantID, amount: Int)

    /// Modifies the target's magic points by a positive or negative amount.
    case changeMP(target: CombatantID, amount: Int)

    /// Applies a named status effect for a given duration.
    case applyStatusEffect(target: CombatantID, effect: String, duration: Int)

    /// Removes a specific status effect from the target.
    case removeStatusEffect(target: CombatantID, effect: String)

    // MARK: - Turn Coordination
    /// Sets the combatant that is currently acting.
    case setCurrentActor(CombatantID?)

    /// Signals the beginning of an action selection phase for a combatant.
    case beginActionSelection(for: CombatantID)

    /// Completes an action selection with the specified decision.
    case completeActionSelection(for: CombatantID, action: SelectedAction)

    // MARK: - Effect Management
    /// Queues one or more side-effect identifiers for later execution.
    case addEffects([String])  // Effect identifiers.

    /// Executes a previously enqueued effect.
    case executeEffect(String)  // Effect identifier.

    /// Clears all pending effects from the queue.
    case clearEffects

    // MARK: - AI Coordination
    /// Requests an AI-controlled combatant to select an action.
    case aiDecideAction(for: CombatantID)

    /// Executes the decision returned by the AI.
    case aiExecuteAction(for: CombatantID, action: SelectedAction)
}

/// Represents the outcome of a battle.
public enum BattleResult: Sendable, Equatable {
    case victory    // Player victory.
    case defeat     // Player defeat.
    case escape     // Successful escape.
    case draw       // Neither side prevails.
}

/// The action that a combatant ultimately chooses to perform.
public enum SelectedAction: Sendable, Equatable {
    case attack(target: CombatantID)
    case skill(id: String, targets: [CombatantID])
    case item(id: String, target: CombatantID?)
    case defend
    case escape
}

/// The relative priority assigned to an action.
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

/// Metadata that influences how an action is scheduled or executed.
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

extension BattleAction: Equatable {
    public static func == (lhs: BattleAction, rhs: BattleAction) -> Bool {
        switch (lhs, rhs) {
        case (.startBattle(let lp, let le), .startBattle(let rp, let re)):
            return lp == rp && le == re
        case (.endBattle(let lr), .endBattle(let rr)):
            return lr == rr
        case (.advancePhase(let lp), .advancePhase(let rp)):
            return lp == rp
        case (.advanceTurn, .advanceTurn):
            return true
        case (.attack(let la, let lt, let ld), .attack(let ra, let rt, let rd)):
            return la == ra && lt == rt && ld == rd
        case (.changeHP(let lt, let la), .changeHP(let rt, let ra)):
            return lt == rt && la == ra
        case (.addEffects(let le), .addEffects(let re)):
            return le == re
        case (.executeEffect(let le), .executeEffect(let re)):
            return le == re
        case (.clearEffects, .clearEffects):
            return true
        default:
            return false
        }
    }
    
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
    
    /// Indicates whether the action manipulates the combat flow.
    public var isFlowControl: Bool {
        switch self {
        case .startBattle, .endBattle, .advancePhase, .advanceTurn,
             .setCurrentActor, .beginActionSelection, .completeActionSelection:
            return true
        default:
            return false
        }
    }

    /// Indicates whether the action is driven by a combatant's behavior.
    public var isCharacterAction: Bool {
        switch self {
        case .attack, .useSkill, .useItem, .defend, .escape:
            return true
        default:
            return false
        }
    }
}
