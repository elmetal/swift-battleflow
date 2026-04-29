/// Applies the default JRPG battle rules on top of the battle engine.
public struct JRPGReducer: Sendable {

  public init() {}

  /// Reduces actions that belong to the default JRPG rule set.
  public func reduce(state: JRPGBattleState, action: JRPGAction) -> (JRPGBattleState, [any Effect])
  {
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
      return reduceApplyStatusEffect(
        state: state, target: target, effect: effect, duration: duration)

    case .removeStatusEffect(let target, let effect):
      return reduceRemoveStatusEffect(state: state, target: target, effect: effect)

    case .aiDecideAction(let combatantID):
      return reduceAIDecideAction(state: state, combatantID: combatantID)

    case .aiExecuteAction(let combatantID, let action):
      return reduceAIExecuteAction(state: state, combatantID: combatantID, action: action)
    }
  }
}

extension JRPGReducer {

  // MARK: - Character Actions

  fileprivate func reduceAttack(
    state: JRPGBattleState,
    attacker: CombatantID,
    target: CombatantID,
    damage: Int
  ) -> (JRPGBattleState, [any Effect]) {

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
      BaseEffect(id: "attack_sound", priority: 1),
    ]

    return (newState, effects)
  }

  fileprivate func reduceUseSkill(
    state: JRPGBattleState,
    user: CombatantID,
    skillID: String,
    targets: [CombatantID]
  ) -> (JRPGBattleState, [any Effect]) {

    // Placeholder implementation; extend with concrete skill logic.
    let effects: [any Effect] = [
      BaseEffect(id: "skill_animation_\(skillID)", priority: 3),
      BaseEffect(id: "skill_sound_\(skillID)", priority: 1),
    ]

    return (state, effects)
  }

  fileprivate func reduceUseItem(
    state: JRPGBattleState,
    user: CombatantID,
    itemID: String,
    target: CombatantID?
  ) -> (JRPGBattleState, [any Effect]) {

    // Placeholder implementation; extend with concrete item logic.
    let effects: [any Effect] = [
      BaseEffect(id: "item_use_\(itemID)", priority: 2)
    ]

    return (state, effects)
  }

  fileprivate func reduceDefend(
    state: JRPGBattleState,
    defender: CombatantID
  ) -> (JRPGBattleState, [any Effect]) {

    let effects: [any Effect] = [
      BaseEffect(id: "defend_animation_\(defender.value)", priority: 1)
    ]

    return (state, effects)
  }

  fileprivate func reduceEscape(
    state: JRPGBattleState,
    escaper: CombatantID
  ) -> (JRPGBattleState, [any Effect]) {

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

  fileprivate func reduceChangeHP(
    state: JRPGBattleState,
    target: CombatantID,
    amount: Int
  ) -> (JRPGBattleState, [any Effect]) {

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

  fileprivate func reduceChangeMP(
    state: JRPGBattleState,
    target: CombatantID,
    amount: Int
  ) -> (JRPGBattleState, [any Effect]) {

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

  fileprivate func reduceApplyStatusEffect(
    state: JRPGBattleState,
    target: CombatantID,
    effect: String,
    duration: Int
  ) -> (JRPGBattleState, [any Effect]) {

    // Status ailments will be implemented in a future phase.
    let effects: [any Effect] = [
      BaseEffect(id: "status_effect_apply_\(effect)", priority: 2)
    ]

    return (state, effects)
  }

  fileprivate func reduceRemoveStatusEffect(
    state: JRPGBattleState,
    target: CombatantID,
    effect: String
  ) -> (JRPGBattleState, [any Effect]) {

    // Status ailments will be implemented in a future phase.
    let effects: [any Effect] = [
      BaseEffect(id: "status_effect_remove_\(effect)", priority: 1)
    ]

    return (state, effects)
  }

  // MARK: - AI Coordination

  fileprivate func reduceAIDecideAction(
    state: JRPGBattleState,
    combatantID: CombatantID
  ) -> (JRPGBattleState, [any Effect]) {

    // AI decision-making will arrive in a future phase.
    let effects: [any Effect] = [
      BaseEffect(id: "ai_thinking_\(combatantID.value)", priority: 1)
    ]

    return (state, effects)
  }

  fileprivate func reduceAIExecuteAction(
    state: JRPGBattleState,
    combatantID: CombatantID,
    action: SelectedAction
  ) -> (JRPGBattleState, [any Effect]) {

    // AI execution will arrive in a future phase.
    return (state, [])
  }
}
