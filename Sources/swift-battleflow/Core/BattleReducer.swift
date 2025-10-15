/// The reducer at the heart of the state-store pattern.
///
/// Combines an action and a state into a new state plus a collection of
/// generated effects.
public struct BattleReducer: Sendable {

    public init() {}

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
            
        // MARK: - Character Actions
        case .attack(let attacker, let target, let damage):
            return reduceAttack(state: state, attacker: attacker, target: target, damage: damage)
            
        case .useSkill(let user, let skillID, let targets):
            return reduceUseSkill(state: state, user: user, skillID: skillID, targets: targets)
            
        case .useItem(let user, let itemID, let target):
            return reduceUseItem(state: state, user: user, itemID: itemID, target: target)
            
        case .defend(let defender):
            return reduceDefend(state: state, defender: defender)
            
        case .escape(let escaper):
            return reduceEscape(state: state, escaper: escaper)
            
        // MARK: - Status Adjustments
        case .changeHP(let target, let amount):
            return reduceChangeHP(state: state, target: target, amount: amount)
            
        case .changeMP(let target, let amount):
            return reduceChangeMP(state: state, target: target, amount: amount)
            
        case .applyStatusEffect(let target, let effect, let duration):
            return reduceApplyStatusEffect(state: state, target: target, effect: effect, duration: duration)
            
        case .removeStatusEffect(let target, let effect):
            return reduceRemoveStatusEffect(state: state, target: target, effect: effect)
            
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
            
        // MARK: - AI Coordination
        case .aiDecideAction(let combatantID):
            return reduceAIDecideAction(state: state, combatantID: combatantID)
            
        case .aiExecuteAction(let combatantID, let action):
            return reduceAIExecuteAction(state: state, combatantID: combatantID, action: action)
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
    
    // MARK: - Character Actions
    
    private func reduceAttack(
        state: BattleState,
        attacker: CombatantID,
        target: CombatantID,
        damage: Int
    ) -> (BattleState, [any Effect]) {
        
        guard let targetCombatant = state.combatants[target] else {
            return (state, [])
        }
        
        let newHP = targetCombatant.stats.hp - damage
        let updatedStats = targetCombatant.stats.withHP(newHP)
        let updatedTarget = targetCombatant.withStats(updatedStats)
        
        let newState = state.withCombatant(updatedTarget)
        
        let effects: [any Effect] = [
            BaseEffect(id: "attack_animation_\(attacker.value)", priority: 3),
            BaseEffect(id: "damage_effect_\(target.value)_\(damage)", priority: 2),
            BaseEffect(id: "attack_sound", priority: 1)
        ]
        
        return (newState, effects)
    }
    
    private func reduceUseSkill(
        state: BattleState,
        user: CombatantID,
        skillID: String,
        targets: [CombatantID]
    ) -> (BattleState, [any Effect]) {
        
        // Placeholder implementation; extend with concrete skill logic.
        let effects: [any Effect] = [
            BaseEffect(id: "skill_animation_\(skillID)", priority: 3),
            BaseEffect(id: "skill_sound_\(skillID)", priority: 1)
        ]

        return (state, effects)
    }

    private func reduceUseItem(
        state: BattleState,
        user: CombatantID,
        itemID: String,
        target: CombatantID?
    ) -> (BattleState, [any Effect]) {
        
        // Placeholder implementation; extend with concrete item logic.
        let effects: [any Effect] = [
            BaseEffect(id: "item_use_\(itemID)", priority: 2)
        ]

        return (state, effects)
    }
    
    private func reduceDefend(
        state: BattleState,
        defender: CombatantID
    ) -> (BattleState, [any Effect]) {
        
        let effects: [any Effect] = [
            BaseEffect(id: "defend_animation_\(defender.value)", priority: 1)
        ]
        
        return (state, effects)
    }
    
    private func reduceEscape(
        state: BattleState,
        escaper: CombatantID
    ) -> (BattleState, [any Effect]) {
        
        // Player escape ends the encounter immediately.
        if state.playerCombatants.contains(escaper) {
            let newState = state.withPhase(.escape)
            let effects: [any Effect] = [
                BaseEffect(id: "escape_success", priority: 2)
            ]
            return (newState, effects)
        }

        // Enemy escape is a future enhancement.
        return (state, [])
    }

    // MARK: - Status Adjustments
    
    private func reduceChangeHP(
        state: BattleState,
        target: CombatantID,
        amount: Int
    ) -> (BattleState, [any Effect]) {
        
        guard let combatant = state.combatants[target] else {
            return (state, [])
        }
        
        let newHP = combatant.stats.hp + amount
        let updatedStats = combatant.stats.withHP(newHP)
        let updatedCombatant = combatant.withStats(updatedStats)
        
        
        let newState = state.withCombatant(updatedCombatant)
        
        let effectType = amount > 0 ? "heal" : "damage"
        let effects: [any Effect] = [
            BaseEffect(id: "\(effectType)_effect_\(target.value)_\(abs(amount))", priority: 2)
        ]
        
        return (newState, effects)
    }
    
    private func reduceChangeMP(
        state: BattleState,
        target: CombatantID,
        amount: Int
    ) -> (BattleState, [any Effect]) {
        
        guard let combatant = state.combatants[target] else {
            return (state, [])
        }
        
        let newMP = combatant.stats.mp + amount
        let updatedStats = combatant.stats.withMP(newMP)
        let updatedCombatant = combatant.withStats(updatedStats)
        
        let newState = state.withCombatant(updatedCombatant)
        
        let effects: [any Effect] = [
            BaseEffect(id: "mp_change_\(target.value)_\(amount)", priority: 1)
        ]
        
        return (newState, effects)
    }
    
    private func reduceApplyStatusEffect(
        state: BattleState,
        target: CombatantID,
        effect: String,
        duration: Int
    ) -> (BattleState, [any Effect]) {
        
        // Status ailments will be implemented in a future phase.
        let effects: [any Effect] = [
            BaseEffect(id: "status_effect_apply_\(effect)", priority: 2)
        ]

        return (state, effects)
    }
    
    private func reduceRemoveStatusEffect(
        state: BattleState,
        target: CombatantID,
        effect: String
    ) -> (BattleState, [any Effect]) {
        
        // Status ailments will be implemented in a future phase.
        let effects: [any Effect] = [
            BaseEffect(id: "status_effect_remove_\(effect)", priority: 1)
        ]

        return (state, effects)
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
    
    // MARK: - AI Coordination
    
    private func reduceAIDecideAction(
        state: BattleState,
        combatantID: CombatantID
    ) -> (BattleState, [any Effect]) {
        
        // AI decision-making will arrive in a future phase.
        let effects: [any Effect] = [
            BaseEffect(id: "ai_thinking_\(combatantID.value)", priority: 1)
        ]

        return (state, effects)
    }
    
    private func reduceAIExecuteAction(
        state: BattleState,
        combatantID: CombatantID,
        action: SelectedAction
    ) -> (BattleState, [any Effect]) {
        
        // AI execution will arrive in a future phase.
        return (state, [])
    }
}
