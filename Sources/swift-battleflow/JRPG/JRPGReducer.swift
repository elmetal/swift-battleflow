/// Applies the default JRPG battle rules on top of the battle engine.
public struct JRPGReducer: Sendable {

    public init() {}

    /// Reduces actions that belong to the default JRPG rule set.
    public func reduce(state: BattleState, action: BattleAction) -> (BattleState, [any Effect]) {
        switch action {
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

        case .changeHP(let target, let amount):
            return reduceChangeHP(state: state, target: target, amount: amount)

        case .changeMP(let target, let amount):
            return reduceChangeMP(state: state, target: target, amount: amount)

        case .applyStatusEffect(let target, let effect, let duration):
            return reduceApplyStatusEffect(state: state, target: target, effect: effect, duration: duration)

        case .removeStatusEffect(let target, let effect):
            return reduceRemoveStatusEffect(state: state, target: target, effect: effect)

        case .aiDecideAction(let combatantID):
            return reduceAIDecideAction(state: state, combatantID: combatantID)

        case .aiExecuteAction(let combatantID, let action):
            return reduceAIExecuteAction(state: state, combatantID: combatantID, action: action)

        default:
            return (state, [])
        }
    }
}

private extension JRPGReducer {

    // MARK: - Character Actions

    func reduceAttack(
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

    func reduceUseSkill(
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

    func reduceUseItem(
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

    func reduceDefend(
        state: BattleState,
        defender: CombatantID
    ) -> (BattleState, [any Effect]) {

        let effects: [any Effect] = [
            BaseEffect(id: "defend_animation_\(defender.value)", priority: 1)
        ]

        return (state, effects)
    }

    func reduceEscape(
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

    func reduceChangeHP(
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

    func reduceChangeMP(
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

    func reduceApplyStatusEffect(
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

    func reduceRemoveStatusEffect(
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

    // MARK: - AI Coordination

    func reduceAIDecideAction(
        state: BattleState,
        combatantID: CombatantID
    ) -> (BattleState, [any Effect]) {

        // AI decision-making will arrive in a future phase.
        let effects: [any Effect] = [
            BaseEffect(id: "ai_thinking_\(combatantID.value)", priority: 1)
        ]

        return (state, effects)
    }

    func reduceAIExecuteAction(
        state: BattleState,
        combatantID: CombatantID,
        action: SelectedAction
    ) -> (BattleState, [any Effect]) {

        // AI execution will arrive in a future phase.
        return (state, [])
    }
}
