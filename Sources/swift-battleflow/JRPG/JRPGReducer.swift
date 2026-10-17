/// Applies the default JRPG battle rules on top of the battle engine.
public struct JRPGReducer: Reducer {
  public typealias State = JRPGBattleState
  public typealias Action = JRPGAction

  /// The rules used to derive action outcomes.
  public let rules: JRPGRules

  public init(rules: JRPGRules = .standard) {
    self.rules = rules
  }

  /// Reduces actions that belong to the default JRPG rule set.
  ///
  /// Combatant intents are ignored unless the battle is ongoing and every
  /// referenced combatant exists and is not defeated.
  public func reduce(state: JRPGBattleState, action: JRPGAction) -> Reduction<
    JRPGBattleState, JRPGAction
  > {
    switch action {
    case .startBattle(let players, let enemies):
      return reduceStartBattle(state: state, players: players, enemies: enemies)

    case .endBattle(let result):
      return reduceEndBattle(state: state, result: result)

    case .attack(let attacker, let target):
      guard canAct(attacker, in: state), canBeTargeted(target, in: state) else {
        return Reduction(state: state)
      }
      return reduceAttack(state: state, attacker: attacker, target: target)

    case .useSkill(let user, let skill, let targets):
      guard canAct(user, in: state), targets.allSatisfy({ canBeTargeted($0, in: state) }) else {
        return Reduction(state: state)
      }
      return reduceUseSkill(state: state, user: user, skill: skill, targets: targets)

    case .useItem(let user, let item, let target):
      guard canAct(user, in: state), target.map({ canBeTargeted($0, in: state) }) ?? true else {
        return Reduction(state: state)
      }
      return reduceUseItem(state: state, user: user, item: item, target: target)

    case .defend(let defender):
      guard canAct(defender, in: state) else {
        return Reduction(state: state)
      }
      return reduceDefend(state: state, defender: defender)

    case .escape(let escaper):
      guard canAct(escaper, in: state) else {
        return Reduction(state: state)
      }
      return reduceEscape(state: state, escaper: escaper)

    case .aiDecideAction(let combatantID):
      guard canAct(combatantID, in: state) else {
        return Reduction(state: state)
      }
      return reduceAIDecideAction(state: state, combatantID: combatantID)
    }
  }
}

extension JRPGReducer {

  // MARK: - Preconditions

  /// Indicates whether the combatant may take an action in the given state.
  fileprivate func canAct(_ id: CombatantID, in state: JRPGBattleState) -> Bool {
    !state.isBattleEnded && canBeTargeted(id, in: state)
  }

  /// Indicates whether the combatant exists and is not defeated.
  fileprivate func canBeTargeted(_ id: CombatantID, in state: JRPGBattleState) -> Bool {
    state.combatants[id]?.stats.isDefeated == false
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
    target: CombatantID
  ) -> Reduction<JRPGBattleState, JRPGAction> {

    guard let attackerCombatant = state.combatants[attacker],
      let targetCombatant = state.combatants[target]
    else {
      preconditionFailure("Attack preconditions must be checked before reducing.")
    }

    let damage = rules.physicalDamage(attackerCombatant.stats, targetCombatant.stats)
    precondition(damage >= 0, "JRPGRules.physicalDamage must not return a negative value.")

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
    skill: SkillID,
    targets: [CombatantID]
  ) -> Reduction<JRPGBattleState, JRPGAction> {

    // Placeholder implementation; extend with concrete skill logic.
    let commands: [any Command] = [
      BaseCommand(id: "skill_animation_\(skill.value)", priority: 3),
      BaseCommand(id: "skill_sound_\(skill.value)", priority: 1),
    ]

    return Reduction(state: state, commands: commands)
  }

  fileprivate func reduceUseItem(
    state: JRPGBattleState,
    user: CombatantID,
    item: ItemID,
    target: CombatantID?
  ) -> Reduction<JRPGBattleState, JRPGAction> {

    // Placeholder implementation; extend with concrete item logic.
    let commands: [any Command] = [
      BaseCommand(id: "item_use_\(item.value)", priority: 2)
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
}
