/// Swift BattleFlow - A JRPG-style turn-based combat system library.
///
/// This module is written in pure Swift and embraces a state-store pattern that
/// isolates side effects as `Effect` values. It delivers a modern, testable
/// combat system that remains maintainable as your project scales.

// MARK: - Core Exports

@_exported import Foundation
@_exported import Observation

// Core Components are directly available through their module

// MARK: - Convenience Factory

/// The primary entry point for the BattleFlow library.
public struct BattleFlow {

    /// Creates a new battle store configured for the provided initial state.
    ///
    /// - Parameter initialState: The starting state for the battle. The default
    ///   value creates an empty battle.
    /// - Returns: A fully initialized ``BattleStore`` ready to process actions.
    @MainActor
    public static func createStore(initialState: BattleState = BattleState()) -> BattleStore {
        return BattleStore(initialState: initialState)
    }

    /// Creates a convenience combatant for demonstrations or quick testing.
    ///
    /// - Parameters:
    ///   - name: The display name of the character.
    ///   - hp: The current hit points.
    ///   - maxHP: The maximum hit points. When omitted, the current hit points
    ///     value is reused.
    ///   - mp: The current magic points.
    ///   - maxMP: The maximum magic points. When omitted, the current magic
    ///     points value is reused.
    ///   - attack: The attack strength used for physical calculations.
    ///   - defense: The defense strength used to reduce incoming damage.
    ///   - speed: The initiative value used to order turns.
    ///   - isPlayer: A Boolean value that indicates whether this combatant is
    ///     controlled by the player.
    /// - Returns: A configured ``Combatant`` instance that can be inserted into
    ///   a battle state.
    public static func createCharacter(
        name: String,
        hp: Int = 100,
        maxHP: Int? = nil,
        mp: Int = 50,
        maxMP: Int? = nil,
        attack: Int = 20,
        defense: Int = 15,
        speed: Int = 10,
        isPlayer: Bool = true
    ) -> Combatant {
        let id = CombatantID(name.lowercased().replacingOccurrences(of: " ", with: "_"))
        let stats = Stats(
            hp: hp, 
            maxHP: maxHP ?? hp,
            mp: mp, 
            maxMP: maxMP ?? mp,
            attack: attack,
            defense: defense,
            speed: speed
        )
        
        return Combatant(
            id: id,
            name: name,
            stats: stats,
            isPlayerControlled: isPlayer
        )
    }
}
