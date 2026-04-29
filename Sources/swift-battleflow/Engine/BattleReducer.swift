/// The reducer at the heart of the state-store pattern.
///
/// Combines an action and a state into a new state plus a collection of
/// generated effects.
public struct BattleReducer: Sendable {

    private let jrpgReducer: JRPGReducer

    public init(jrpgReducer: JRPGReducer = JRPGReducer()) {
        self.jrpgReducer = jrpgReducer
    }

    /// The primary reducer function.
    ///
    /// - Parameters:
    ///   - state: The current battle state.
    ///   - action: The action to evaluate.
    /// - Returns: A tuple containing the next state and any generated effects.
    public func reduce(state: BattleState, action: BattleAction) -> (BattleState, [any Effect]) {
        switch action {

        // MARK: - Battle Flow Control
        case .startBattle(let players, let enemies):
            return reduceStartBattle(state: state, players: players, enemies: enemies)

        case .endBattle(let result):
            return reduceEndBattle(state: state, result: result)
            
        case .advancePhase(let newPhase):
            return reduceAdvancePhase(state: state, newPhase: newPhase)
            
        case .advanceTurn:
            return reduceAdvanceTurn(state: state)
            
        // MARK: - JRPG Rules
        case .attack, .useSkill, .useItem, .defend, .escape,
             .changeHP, .changeMP, .applyStatusEffect, .removeStatusEffect,
             .aiDecideAction, .aiExecuteAction:
            return jrpgReducer.reduce(state: state, action: action)
            
        // MARK: - Turn Coordination
        case .setCurrentActor(let actorID):
            return reduceSetCurrentActor(state: state, actorID: actorID)
            
        case .beginActionSelection(let combatantID):
            return reduceBeginActionSelection(state: state, combatantID: combatantID)
            
        case .completeActionSelection(let combatantID, let action):
            return reduceCompleteActionSelection(state: state, combatantID: combatantID, action: action)
            
        // MARK: - Effect Management
        case .addEffects(let effectIDs):
            return reduceAddEffects(state: state, effectIDs: effectIDs)
            
        case .executeEffect(let effectID):
            return reduceExecuteEffect(state: state, effectID: effectID)
            
        case .clearEffects:
            return reduceClearEffects(state: state)
            
        }
    }
}

// MARK: - Private Reducer Methods

extension BattleReducer {
    
    // MARK: - Battle Flow Control
    
    private func reduceStartBattle(
        state: BattleState,
        players: [Combatant],
        enemies: [Combatant]
    ) -> (BattleState, [any Effect]) {
        
        var combatants: [CombatantID: Combatant] = [:]
        var playerIDs: Set<CombatantID> = []
        var enemyIDs: Set<CombatantID> = []
        
        // Register player combatants.
        for player in players {
            combatants[player.id] = player
            playerIDs.insert(player.id)
        }

        // Register enemy combatants.
        for enemy in enemies {
            combatants[enemy.id] = enemy
            enemyIDs.insert(enemy.id)
        }
        
        let newState = BattleState(
            phase: .turnSelection,
            combatants: combatants,
            playerCombatants: playerIDs,
            enemyCombatants: enemyIDs,
            turnCount: 1,
            currentActor: nil,
            pendingEffects: []
        )
        
        let effects: [any Effect] = [
            BaseEffect(id: "battle_start_animation", priority: 1),
            BaseEffect(id: "battle_music_start", priority: 1)
        ]
        
        return (newState, effects)
    }
    
    private func reduceEndBattle(
        state: BattleState,
        result: BattleResult
    ) -> (BattleState, [any Effect]) {
        
        let finalPhase: BattlePhase
        switch result {
        case .victory:
            finalPhase = .victory
        case .defeat:
            finalPhase = .defeat
        case .escape, .draw:
            finalPhase = .escape
        }
        
        let newState = state.withPhase(finalPhase)
        
        let effects: [any Effect] = [
            BaseEffect(id: "battle_end_\(result)", priority: 1),
            BaseEffect(id: "battle_music_stop", priority: 0)
        ]
        
        return (newState, effects)
    }
    
    private func reduceAdvancePhase(
        state: BattleState,
        newPhase: BattlePhase
    ) -> (BattleState, [any Effect]) {
        
        let newState = state.withPhase(newPhase)
        let effects: [any Effect] = [
            BaseEffect(id: "phase_transition_\(newPhase)", priority: 1)
        ]
        
        return (newState, effects)
    }
    
    private func reduceAdvanceTurn(state: BattleState) -> (BattleState, [any Effect]) {
        let newState = BattleState(
            phase: state.phase,
            combatants: state.combatants,
            playerCombatants: state.playerCombatants,
            enemyCombatants: state.enemyCombatants,
            turnCount: state.turnCount + 1,
            currentActor: nil,
            pendingEffects: state.pendingEffects
        )
        
        let effects: [any Effect] = [
            BaseEffect(id: "turn_advance", priority: 1)
        ]
        
        return (newState, effects)
    }
    
    // MARK: - Turn Coordination
    
    private func reduceSetCurrentActor(
        state: BattleState,
        actorID: CombatantID?
    ) -> (BattleState, [any Effect]) {
        
        let newState = BattleState(
            phase: state.phase,
            combatants: state.combatants,
            playerCombatants: state.playerCombatants,
            enemyCombatants: state.enemyCombatants,
            turnCount: state.turnCount,
            currentActor: actorID,
            pendingEffects: state.pendingEffects
        )
        
        return (newState, [])
    }
    
    private func reduceBeginActionSelection(
        state: BattleState,
        combatantID: CombatantID
    ) -> (BattleState, [any Effect]) {
        
        let effects: [any Effect] = [
            BaseEffect(id: "action_selection_begin_\(combatantID.value)", priority: 1)
        ]
        
        return (state, effects)
    }
    
    private func reduceCompleteActionSelection(
        state: BattleState,
        combatantID: CombatantID,
        action: SelectedAction
    ) -> (BattleState, [any Effect]) {
        
        let effects: [any Effect] = [
            BaseEffect(id: "action_selection_complete_\(combatantID.value)", priority: 1)
        ]
        
        return (state, effects)
    }
    
    // MARK: - Effect Management
    
    private func reduceAddEffects(
        state: BattleState,
        effectIDs: [String]
    ) -> (BattleState, [any Effect]) {
        
        let effects = effectIDs.map { BaseEffect(id: $0, priority: 1) }
        let newState = state.withEffects(effects)
        return (newState, [])
    }
    
    private func reduceExecuteEffect(
        state: BattleState,
        effectID: String
    ) -> (BattleState, [any Effect]) {
        
        // Effect execution is side-effect only and does not mutate state.
        return (state, [])
    }
    
    private func reduceClearEffects(state: BattleState) -> (BattleState, [any Effect]) {
        let newState = state.withClearedEffects()
        return (newState, [])
    }
}
