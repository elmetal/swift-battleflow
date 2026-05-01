/// Applies the default JRPG battle rules on top of the battle engine.
public struct JRPGReducer: Reducer {
  public typealias State = JRPGBattleState
  public typealias Action = JRPGAction

  public init() {}

  /// Reduces actions that belong to the default JRPG rule set.
  public func reduce(state: JRPGBattleState, action: JRPGAction) -> Reduction<
    JRPGBattleState, JRPGAction
  > {
    switch action {
    case .startBattle(let players, let enemies):
      return reduceStartBattle(state: state, players: players, enemies: enemies)

    case .endBattle(let result):
      return reduceEndBattle(state: state, result: result)

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

  // MARK: - Battle Flow Control

  fileprivate func reduceStartBattle(
    state: JRPGBattleState,
    players: [Combatant],
    enemies: [Combatant]
  ) -> Reduction<JRPGBattleState, JRPGAction> {

    var combatants: [CombatantID: Combatant] = [:]
    var playerIDs: Set<CombatantID> = []
    var enemyIDs: Set<CombatantID> = []

    for player in players {
      combatants[player.id] = player
      playerIDs.insert(player.id)
    }

    for enemy in enemies {
      combatants[enemy.id] = enemy
      enemyIDs.insert(enemy.id)
    }

    let newState = JRPGBattleState(
      phase: .turnSelection,
      combatants: combatants,
      playerCombatants: playerIDs,
      enemyCombatants: enemyIDs,
      turnCount: 1,
      currentActor: nil,
      pendingCommands: []
    )

    let commands: [any Command] = [
      BaseCommand(id: "battle_start_animation", priority: 1),
      BaseCommand(id: "battle_music_start", priority: 1),
    ]

    return Reduction(state: newState, commands: commands)
  }

  fileprivate func reduceEndBattle(
    state: JRPGBattleState,
    result: BattleResult
  ) -> Reduction<JRPGBattleState, JRPGAction> {

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

    let commands: [any Command] = [
      BaseCommand(id: "battle_end_\(result)", priority: 1),
      BaseCommand(id: "battle_music_stop", priority: 0),
    ]

    return Reduction(state: newState, commands: commands)
  }

  // MARK: - Character Actions

  fileprivate func reduceAttack(
    state: JRPGBattleState,
    attacker: CombatantID,
    target: CombatantID,
    damage: Int
  ) -> Reduction<JRPGBattleState, JRPGAction> {

    guard let targetCombatant = state.combatants[target] else {
      return Reduction(state: state)
    }

    let newHP = targetCombatant.stats.hp - damage
    let updatedStats = targetCombatant.stats.withHP(newHP)
    let updatedTarget = targetCombatant.withStats(updatedStats)

    let newState = state.withCombatant(updatedTarget)

    let commands: [any Command] = [
      BaseCommand(id: "attack_animation_\(attacker.value)", priority: 3),
      BaseCommand(id: "damage_effect_\(target.value)_\(damage)", priority: 2),
      BaseCommand(id: "attack_sound", priority: 1),
    ]

    return Reduction(state: newState, commands: commands)
  }

  fileprivate func reduceUseSkill(
    state: JRPGBattleState,
    user: CombatantID,
    skillID: String,
    targets: [CombatantID]
  ) -> Reduction<JRPGBattleState, JRPGAction> {

    // Placeholder implementation; extend with concrete skill logic.
    let commands: [any Command] = [
      BaseCommand(id: "skill_animation_\(skillID)", priority: 3),
      BaseCommand(id: "skill_sound_\(skillID)", priority: 1),
    ]

    return Reduction(state: state, commands: commands)
  }

  fileprivate func reduceUseItem(
    state: JRPGBattleState,
    user: CombatantID,
    itemID: String,
    target: CombatantID?
  ) -> Reduction<JRPGBattleState, JRPGAction> {

    // Placeholder implementation; extend with concrete item logic.
    let commands: [any Command] = [
      BaseCommand(id: "item_use_\(itemID)", priority: 2)
    ]

    return Reduction(state: state, commands: commands)
  }

  fileprivate func reduceDefend(
    state: JRPGBattleState,
    defender: CombatantID
  ) -> Reduction<JRPGBattleState, JRPGAction> {

    let commands: [any Command] = [
      BaseCommand(id: "defend_animation_\(defender.value)", priority: 1)
    ]

    return Reduction(state: state, commands: commands)
  }

  fileprivate func reduceEscape(
    state: JRPGBattleState,
    escaper: CombatantID
  ) -> Reduction<JRPGBattleState, JRPGAction> {

    // Player escape ends the encounter immediately.
    if state.playerCombatants.contains(escaper) {
      let newState = state.withPhase(.escape)
      let commands: [any Command] = [
        BaseCommand(id: "escape_success", priority: 2)
      ]
      return Reduction(state: newState, commands: commands)
    }

    // Enemy escape is a future enhancement.
    return Reduction(state: state)
  }

  // MARK: - Status Adjustments

  fileprivate func reduceChangeHP(
    state: JRPGBattleState,
    target: CombatantID,
    amount: Int
  ) -> Reduction<JRPGBattleState, JRPGAction> {

    guard let combatant = state.combatants[target] else {
      return Reduction(state: state)
    }

    let newHP = combatant.stats.hp + amount
    let updatedStats = combatant.stats.withHP(newHP)
    let updatedCombatant = combatant.withStats(updatedStats)

    let newState = state.withCombatant(updatedCombatant)

    let effectType = amount > 0 ? "heal" : "damage"
    let commands: [any Command] = [
      BaseCommand(id: "\(effectType)_effect_\(target.value)_\(abs(amount))", priority: 2)
    ]

    return Reduction(state: newState, commands: commands)
  }

  fileprivate func reduceChangeMP(
    state: JRPGBattleState,
    target: CombatantID,
    amount: Int
  ) -> Reduction<JRPGBattleState, JRPGAction> {

    guard let combatant = state.combatants[target] else {
      return Reduction(state: state)
    }

    let newMP = combatant.stats.mp + amount
    let updatedStats = combatant.stats.withMP(newMP)
    let updatedCombatant = combatant.withStats(updatedStats)

    let newState = state.withCombatant(updatedCombatant)

    let commands: [any Command] = [
      BaseCommand(id: "mp_change_\(target.value)_\(amount)", priority: 1)
    ]

    return Reduction(state: newState, commands: commands)
  }

  fileprivate func reduceApplyStatusEffect(
    state: JRPGBattleState,
    target: CombatantID,
    effect: String,
    duration: Int
  ) -> Reduction<JRPGBattleState, JRPGAction> {

    // Status ailments will be implemented in a future phase.
    let commands: [any Command] = [
      BaseCommand(id: "status_effect_apply_\(effect)", priority: 2)
    ]

    return Reduction(state: state, commands: commands)
  }

  fileprivate func reduceRemoveStatusEffect(
    state: JRPGBattleState,
    target: CombatantID,
    effect: String
  ) -> Reduction<JRPGBattleState, JRPGAction> {

    // Status ailments will be implemented in a future phase.
    let commands: [any Command] = [
      BaseCommand(id: "status_effect_remove_\(effect)", priority: 1)
    ]

    return Reduction(state: state, commands: commands)
  }

  // MARK: - AI Coordination

  fileprivate func reduceAIDecideAction(
    state: JRPGBattleState,
    combatantID: CombatantID
  ) -> Reduction<JRPGBattleState, JRPGAction> {

    // AI decision-making will arrive in a future phase.
    let commands: [any Command] = [
      BaseCommand(id: "ai_thinking_\(combatantID.value)", priority: 1)
    ]

    return Reduction(state: state, commands: commands)
  }

  fileprivate func reduceAIExecuteAction(
    state: JRPGBattleState,
    combatantID: CombatantID,
    action: SelectedAction
  ) -> Reduction<JRPGBattleState, JRPGAction> {

    // AI execution will arrive in a future phase.
    return Reduction(state: state)
  }
}
