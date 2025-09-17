/// State-Storeパターンの核となるReducer
/// Action + State → (State, [Effect]) の純粋関数を提供する
public struct BattleReducer: Sendable {
    
    public init() {}
    
    /// メインのReducer関数
    /// - Parameters:
    ///   - state: 現在の戦闘状態
    ///   - action: 実行するアクション
    /// - Returns: 新しい状態と発生するエフェクトのタプル
    public func reduce(state: BattleState, action: BattleAction) -> (BattleState, [any Effect]) {
        switch action {
        
        // MARK: - 戦闘フロー制御
        case .startBattle(let players, let enemies):
            return reduceStartBattle(state: state, players: players, enemies: enemies)
            
        case .endBattle(let result):
            return reduceEndBattle(state: state, result: result)
            
        case .advancePhase(let newPhase):
            return reduceAdvancePhase(state: state, newPhase: newPhase)
            
        case .advanceTurn:
            return reduceAdvanceTurn(state: state)
            
        // MARK: - キャラクター行動
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
            
        // MARK: - ステータス変更
        case .changeHP(let target, let amount):
            return reduceChangeHP(state: state, target: target, amount: amount)
            
        case .changeMP(let target, let amount):
            return reduceChangeMP(state: state, target: target, amount: amount)
            
        case .applyStatusEffect(let target, let effect, let duration):
            return reduceApplyStatusEffect(state: state, target: target, effect: effect, duration: duration)
            
        case .removeStatusEffect(let target, let effect):
            return reduceRemoveStatusEffect(state: state, target: target, effect: effect)
            
        // MARK: - ターン制御
        case .setCurrentActor(let actorID):
            return reduceSetCurrentActor(state: state, actorID: actorID)
            
        case .beginActionSelection(let combatantID):
            return reduceBeginActionSelection(state: state, combatantID: combatantID)
            
        case .completeActionSelection(let combatantID, let action):
            return reduceCompleteActionSelection(state: state, combatantID: combatantID, action: action)
            
        // MARK: - エフェクト制御
        case .addEffects(let effectIDs):
            return reduceAddEffects(state: state, effectIDs: effectIDs)
            
        case .executeEffect(let effectID):
            return reduceExecuteEffect(state: state, effectID: effectID)
            
        case .clearEffects:
            return reduceClearEffects(state: state)
            
        // MARK: - AI制御
        case .aiDecideAction(let combatantID):
            return reduceAIDecideAction(state: state, combatantID: combatantID)
            
        case .aiExecuteAction(let combatantID, let action):
            return reduceAIExecuteAction(state: state, combatantID: combatantID, action: action)
        }
    }
}

// MARK: - Private Reducer Methods

extension BattleReducer {
    
    // MARK: - 戦闘フロー制御
    
    private func reduceStartBattle(
        state: BattleState,
        players: [Combatant],
        enemies: [Combatant]
    ) -> (BattleState, [any Effect]) {
        
        var combatants: [CombatantID: Combatant] = [:]
        var playerIDs: Set<CombatantID> = []
        var enemyIDs: Set<CombatantID> = []
        
        // プレイヤーキャラクターを追加
        for player in players {
            combatants[player.id] = player
            playerIDs.insert(player.id)
        }
        
        // 敵キャラクターを追加
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
    
    // MARK: - キャラクター行動
    
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
        
        // 現在は基本実装のみ
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
        
        // 現在は基本実装のみ
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
        
        // プレイヤーの逃走の場合は戦闘終了
        if state.playerCombatants.contains(escaper) {
            let newState = state.withPhase(.escape)
            let effects: [any Effect] = [
                BaseEffect(id: "escape_success", priority: 2)
            ]
            return (newState, effects)
        }
        
        // 敵の逃走（未実装）
        return (state, [])
    }
    
    // MARK: - ステータス変更
    
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
        
        // 状態異常システムは将来のフェーズで実装
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
        
        // 状態異常システムは将来のフェーズで実装
        let effects: [any Effect] = [
            BaseEffect(id: "status_effect_remove_\(effect)", priority: 1)
        ]
        
        return (state, effects)
    }
    
    // MARK: - ターン制御
    
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
    
    // MARK: - エフェクト制御
    
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
        
        // エフェクト実行は副作用なので、状態変更は行わない
        return (state, [])
    }
    
    private func reduceClearEffects(state: BattleState) -> (BattleState, [any Effect]) {
        let newState = state.withClearedEffects()
        return (newState, [])
    }
    
    // MARK: - AI制御
    
    private func reduceAIDecideAction(
        state: BattleState,
        combatantID: CombatantID
    ) -> (BattleState, [any Effect]) {
        
        // AI行動決定は将来のフェーズで実装
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
        
        // AI行動実行は将来のフェーズで実装
        return (state, [])
    }
}
