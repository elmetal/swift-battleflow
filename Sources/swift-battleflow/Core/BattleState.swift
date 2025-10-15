import Foundation

/// Represents the current phase of a battle sequence.
public enum BattlePhase: Sendable, Equatable {
    case preparation    // Battle setup.
    case turnSelection  // Choosing the next actor.
    case actionExecution // Resolving chosen actions.
    case effectResolution // Processing pending effects.
    case victory       // Players succeed.
    case defeat        // Players lose.
    case escape        // Battle ends by escape.
}

/// Identifies a combatant participating in the battle.
public struct CombatantID: Hashable, Sendable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }
}

/// Captures the core stats used for battle calculations.
public struct Stats: Sendable, Equatable {
    public let hp: Int
    public let maxHP: Int
    public let mp: Int
    public let maxMP: Int
    public let attack: Int
    public let defense: Int
    public let speed: Int
    
    public init(
        hp: Int,
        maxHP: Int,
        mp: Int,
        maxMP: Int,
        attack: Int,
        defense: Int,
        speed: Int
    ) {
        self.hp = hp
        self.maxHP = maxHP
        self.mp = mp
        self.maxMP = maxMP
        self.attack = attack
        self.defense = defense
        self.speed = speed
    }
    
    /// Indicates whether the combatant has been defeated.
    public var isDefeated: Bool {
        return hp <= 0
    }

    /// Returns a copy of the stats with updated hit points.
    public func withHP(_ newHP: Int) -> Stats {
        Stats(
            hp: max(0, min(newHP, maxHP)),
            maxHP: maxHP,
            mp: mp,
            maxMP: maxMP,
            attack: attack,
            defense: defense,
            speed: speed
        )
    }
    
    /// Returns a copy of the stats with updated magic points.
    public func withMP(_ newMP: Int) -> Stats {
        Stats(
            hp: hp,
            maxHP: maxHP,
            mp: max(0, min(newMP, maxMP)),
            maxMP: maxMP,
            attack: attack,
            defense: defense,
            speed: speed
        )
    }
}

/// Describes a participant in the battle.
public struct Combatant: Sendable, Equatable {
    public let id: CombatantID
    public let name: String
    public let stats: Stats
    public let isPlayerControlled: Bool
    
    public init(
        id: CombatantID,
        name: String,
        stats: Stats,
        isPlayerControlled: Bool
    ) {
        self.id = id
        self.name = name
        self.stats = stats
        self.isPlayerControlled = isPlayerControlled
    }
    
    /// Returns a copy of the combatant using updated stats.
    public func withStats(_ newStats: Stats) -> Combatant {
        Combatant(
            id: id,
            name: name,
            stats: newStats,
            isPlayerControlled: isPlayerControlled
        )
    }
}

/// An immutable structure that stores the entire battle state.
public struct BattleState: Sendable, Equatable {
    /// The current phase of the battle.
    public let phase: BattlePhase

    /// A lookup table of all combatants.
    public let combatants: [CombatantID: Combatant]

    /// The set of player-controlled combatant identifiers.
    public let playerCombatants: Set<CombatantID>

    /// The set of enemy combatant identifiers.
    public let enemyCombatants: Set<CombatantID>

    /// The current turn counter.
    public let turnCount: Int

    /// The combatant that is currently acting, if any.
    public let currentActor: CombatantID?

    /// Pending effects awaiting execution.
    public let pendingEffects: [any Effect]
    
    public init(
        phase: BattlePhase = .preparation,
        combatants: [CombatantID: Combatant] = [:],
        playerCombatants: Set<CombatantID> = [],
        enemyCombatants: Set<CombatantID> = [],
        turnCount: Int = 0,
        currentActor: CombatantID? = nil,
        pendingEffects: [any Effect] = []
    ) {
        self.phase = phase
        self.combatants = combatants
        self.playerCombatants = playerCombatants
        self.enemyCombatants = enemyCombatants
        self.turnCount = turnCount
        self.currentActor = currentActor
        self.pendingEffects = pendingEffects
    }
    
    /// Indicates whether the battle has reached a terminal phase.
    public var isBattleEnded: Bool {
        switch phase {
        case .victory, .defeat, .escape:
            return true
        default:
            return false
        }
    }

    /// Returns the player-controlled combatants that are still active.
    public var alivePlayers: [Combatant] {
        playerCombatants.compactMap { id in
            combatants[id]?.stats.isDefeated == false ? combatants[id] : nil
        }
    }

    /// Returns the enemy combatants that are still active.
    public var aliveEnemies: [Combatant] {
        enemyCombatants.compactMap { id in
            combatants[id]?.stats.isDefeated == false ? combatants[id] : nil
        }
    }

    /// Returns a new state with the provided combatant updated or inserted.
    public func withCombatant(_ combatant: Combatant) -> BattleState {
        var newCombatants = combatants
        newCombatants[combatant.id] = combatant
        
        return BattleState(
            phase: phase,
            combatants: newCombatants,
            playerCombatants: playerCombatants,
            enemyCombatants: enemyCombatants,
            turnCount: turnCount,
            currentActor: currentActor,
            pendingEffects: pendingEffects
        )
    }
    
    /// Returns a new state with a different battle phase.
    public func withPhase(_ newPhase: BattlePhase) -> BattleState {
        BattleState(
            phase: newPhase,
            combatants: combatants,
            playerCombatants: playerCombatants,
            enemyCombatants: enemyCombatants,
            turnCount: turnCount,
            currentActor: currentActor,
            pendingEffects: pendingEffects
        )
    }
    
    /// Returns a new state with additional pending effects appended.
    public func withEffects(_ effects: [any Effect]) -> BattleState {
        BattleState(
            phase: phase,
            combatants: combatants,
            playerCombatants: playerCombatants,
            enemyCombatants: enemyCombatants,
            turnCount: turnCount,
            currentActor: currentActor,
            pendingEffects: pendingEffects + effects
        )
    }
    
    /// Returns a new state with all pending effects removed.
    public func withClearedEffects() -> BattleState {
        BattleState(
            phase: phase,
            combatants: combatants,
            playerCombatants: playerCombatants,
            enemyCombatants: enemyCombatants,
            turnCount: turnCount,
            currentActor: currentActor,
            pendingEffects: []
        )
    }
}

extension BattleState {
    /// Custom ``Equatable`` implementation.
    ///
    /// Pending effects are type-erased, so only their counts are compared at
    /// this stage. Extend this logic if more granular comparisons are needed in
    /// the future.
    public static func == (lhs: BattleState, rhs: BattleState) -> Bool {
        lhs.phase == rhs.phase &&
        lhs.combatants == rhs.combatants &&
        lhs.playerCombatants == rhs.playerCombatants &&
        lhs.enemyCombatants == rhs.enemyCombatants &&
        lhs.turnCount == rhs.turnCount &&
        lhs.currentActor == rhs.currentActor &&
        lhs.pendingEffects.count == rhs.pendingEffects.count
        // Note: Extend this comparison with detailed effect matching when needed.
    }
}
