/// Applies the default JRPG battle rules on top of the battle engine.
public struct JRPGReducer<Generator: BattleRandomGenerator>: Reducer {
  public typealias State = JRPGBattleState<Generator>
  public typealias Action = JRPGAction

  /// The rules used to derive action outcomes.
  public let rules: JRPGRules

  public init(rules: JRPGRules = .standard) {
    self.rules = rules
  }

  /// Reduces actions that belong to the default JRPG rule set.
  ///
  /// Combatant intents are ignored unless the battle is ongoing and every
  /// referenced combatant exists and is not defeated. When an action during
  /// the battle changes combatants and one side is wiped out, the battle ends
  /// automatically.
  public func reduce(state: State, action: JRPGAction) -> Reduction<
    State, JRPGAction
  > {
    let reduction = reduceAction(state: state, action: action)

    // Starting a battle sets up combatants rather than changing them in play.
    if case .startBattle = action {
      return reduction
    }
    return resolvingOutcome(of: reduction, from: state)
  }

  private func reduceAction(state: State, action: JRPGAction) -> Reduction<
    State, JRPGAction
  > {
    switch action {
    case .engine(let engineAction):
      return reduceEngine(state: state, action: engineAction)

    case .startBattle(let players, let enemies):
      return reduceStartBattle(state: state, players: players, enemies: enemies)

    case .endBattle(let result):
      return reduceEndBattle(state: state, result: result)

    case .select(let selection, let combatantID):
      guard state.phase == .turnSelection, canAct(combatantID, in: state) else {
        return Reduction(state: state)
      }
      return Reduction(state: state.withSelection(selection, for: combatantID))

    case .executeTurn:
      guard state.phase == .turnSelection,
        state.livingCombatants.allSatisfy({ state.selections[$0.id] != nil })
      else {
        return Reduction(state: state)
      }
      return reduceExecuteTurn(state: state)

    case .performNextAction:
      guard state.phase == .actionExecution else {
        return Reduction(state: state)
      }
      return reducePerformNextAction(state: state)

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
      let target = target ?? user
      guard canAct(user, in: state),
        let effect = rules.itemEffect(item),
        canReceive(effect, target: target, in: state)
      else {
        return Reduction(state: state)
      }
      return reduceUseItem(state: state, item: item, effect: effect, target: target)

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

    case .requestAIDecision(let combatantID):
      guard canAct(combatantID, in: state) else {
        return Reduction(state: state)
      }
      return reduceRequestAIDecision(state: state, combatantID: combatantID)
    }
  }
}

extension JRPGReducer {

  // MARK: - Preconditions

  /// Indicates whether the combatant may take an action in the given state.
  fileprivate func canAct(_ id: CombatantID, in state: State) -> Bool {
    !state.isBattleEnded && canBeTargeted(id, in: state)
  }

  /// Indicates whether the item effect can apply to the target: revival needs
  /// a defeated target, and other effects need a living one.
  fileprivate func canReceive(
    _ effect: ItemEffect, target: CombatantID, in state: State
  ) -> Bool {
    guard let stats = state.combatants[target]?.stats else {
      return false
    }
    if case .revive = effect {
      return stats.isDefeated
    }
    return !stats.isDefeated
  }

  /// Indicates whether the combatant exists and is not defeated.
  fileprivate func canBeTargeted(_ id: CombatantID, in state: State) -> Bool {
    state.combatants[id]?.stats.isDefeated == false
  }
}

extension JRPGReducer {

  // MARK: - Outcome

  /// Ends the battle when the reduction changed combatants and one side has
  /// been wiped out.
  fileprivate func resolvingOutcome(
    of reduction: Reduction<State, JRPGAction>,
    from previousState: State
  ) -> Reduction<State, JRPGAction> {

    let state = reduction.state
    guard !state.isBattleEnded, state.combatants != previousState.combatants,
      let result = decidedResult(in: state)
    else {
      return reduction
    }

    let ending = reduceEndBattle(state: state, result: result)
    return Reduction(
      state: ending.state,
      commands: reduction.commands + ending.commands,
      effects: reduction.effects
    )
  }

  /// Returns the result decided by the combatants' state, if any. A side with
  /// no members never counts as defeated.
  fileprivate func decidedResult(in state: State) -> BattleResult? {
    if !state.enemyIDs.isEmpty && state.aliveEnemies.isEmpty {
      return .victory
    }
    if !state.playerIDs.isEmpty && state.alivePlayers.isEmpty {
      return .defeat
    }
    return nil
  }

  // MARK: - Engine Forwarding

  fileprivate func reduceEngine(
    state: State,
    action: BattleAction
  ) -> Reduction<State, JRPGAction> {

    let reduction = BattleReducer().reduce(state: state.engineState, action: action)

    return Reduction(
      state: state.withEngineState(reduction.state),
      commands: reduction.commands,
      effects: reduction.effects.map { $0.map(JRPGAction.engine) }
    )
  }

  // MARK: - Battle Flow Control

  fileprivate func reduceStartBattle(
    state: State,
    players: [Combatant],
    enemies: [Combatant]
  ) -> Reduction<State, JRPGAction> {

    let combatants = Dictionary(
      (players + enemies).map { ($0.id, $0) },
      uniquingKeysWith: { _, _ in
        preconditionFailure("startBattle requires unique combatant IDs across both rosters.")
      })
    let playerIDs = Set(players.map(\.id))
    let enemyIDs = Set(enemies.map(\.id))

    let newState = State(
      phase: .turnSelection,
      combatants: combatants,
      playerIDs: playerIDs,
      enemyIDs: enemyIDs,
      turnCount: 1,
      currentActor: nil,
      pendingCommands: [],
      random: state.random
    )

    let commands: [any Command] = [
      BaseCommand(id: "battle_start_animation", priority: 1),
      BaseCommand(id: "battle_music_start", priority: 1),
    ]

    return Reduction(state: newState, commands: commands)
  }

  fileprivate func reduceEndBattle(
    state: State,
    result: BattleResult
  ) -> Reduction<State, JRPGAction> {

    let newState = state.withPhase(.ended(result.outcome))

    let commands: [any Command] = [
      BaseCommand(id: "battle_end_\(result)", priority: 1),
      BaseCommand(id: "battle_music_stop", priority: 0),
    ]

    return Reduction(state: newState, commands: commands)
  }

  // MARK: - Turn Flow

  fileprivate func reduceExecuteTurn(
    state: State
  ) -> Reduction<State, JRPGAction> {

    // Draw one roll per actor in ID order, so the roll each actor receives
    // does not depend on dictionary order.
    var random = state.random
    let actors = state.livingCombatants.sorted { $0.id.value < $1.id.value }.map { combatant in
      guard let selection = state.selections[combatant.id] else {
        preconditionFailure("Every living combatant must select before the turn executes.")
      }
      return (
        id: combatant.id, priority: selection.priority, speed: combatant.stats.speed,
        roll: random.nextRoll()
      )
    }

    // Higher priority first, then higher speed, then the higher roll breaks
    // ties. The ID is compared in swapped order so that it sorts ascending if
    // rolls are equal.
    let order = actors.sorted { lhs, rhs in
      (lhs.priority, lhs.speed, lhs.roll, rhs.id.value)
        > (rhs.priority, rhs.speed, rhs.roll, lhs.id.value)
    }.map(\.id)

    let newState = state.withRandom(random).withEngineState(
      state.engineState.withPhase(.actionExecution).withActionOrder(order))

    let commands: [any Command] = [
      BaseCommand(id: "turn_execution_begin", priority: 1)
    ]

    return Reduction(state: newState, commands: commands)
  }

  fileprivate func reducePerformNextAction(
    state: State
  ) -> Reduction<State, JRPGAction> {

    let advanced = state.withEngineState(state.engineState.advancingActor())

    guard let actor = advanced.currentActor else {
      let nextTurn = advanced.removingAllSelections().withEngineState(
        advanced.engineState.advancingTurn().withPhase(.turnSelection))
      let commands: [any Command] = [
        BaseCommand(id: "turn_end", priority: 1)
      ]
      return Reduction(state: nextTurn, commands: commands)
    }

    guard let selection = advanced.selections[actor] else {
      preconditionFailure("Every scheduled actor must have a selection.")
    }

    // The intent's own preconditions apply, so an actor defeated earlier in
    // the turn, or an invalid target, results in no action.
    return reduce(state: advanced, action: selection.intent(by: actor))
  }

  // MARK: - Character Actions

  fileprivate func reduceAttack(
    state: State,
    attacker: CombatantID,
    target: CombatantID
  ) -> Reduction<State, JRPGAction> {

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
    state: State,
    user: CombatantID,
    skill: SkillID,
    targets: [CombatantID]
  ) -> Reduction<State, JRPGAction> {

    // Placeholder implementation; extend with concrete skill logic.
    let commands: [any Command] = [
      BaseCommand(id: "skill_animation_\(skill.value)", priority: 3),
      BaseCommand(id: "skill_sound_\(skill.value)", priority: 1),
    ]

    return Reduction(state: state, commands: commands)
  }

  fileprivate func reduceUseItem(
    state: State,
    item: ItemID,
    effect: ItemEffect,
    target: CombatantID
  ) -> Reduction<State, JRPGAction> {

    guard let targetCombatant = state.combatants[target] else {
      preconditionFailure("Item preconditions must be checked before reducing.")
    }
    let stats = targetCombatant.stats

    let updatedStats: Stats
    switch effect {
    case .restoreHP(let amount):
      precondition(amount > 0, "ItemEffect.restoreHP amount must be positive.")
      updatedStats = stats.withHP(stats.hp + amount)
    case .restoreMP(let amount):
      precondition(amount > 0, "ItemEffect.restoreMP amount must be positive.")
      updatedStats = stats.withMP(stats.mp + amount)
    case .revive(let hp):
      precondition(hp > 0, "ItemEffect.revive hp must be positive.")
      updatedStats = stats.withHP(hp)
    }

    let newState = state.withCombatant(targetCombatant.withStats(updatedStats))

    let commands: [any Command] = [
      BaseCommand(id: "item_use_\(item.value)", priority: 2),
      BaseCommand(id: "item_effect_\(target.value)", priority: 1),
    ]

    return Reduction(state: newState, commands: commands)
  }

  fileprivate func reduceDefend(
    state: State,
    defender: CombatantID
  ) -> Reduction<State, JRPGAction> {

    let commands: [any Command] = [
      BaseCommand(id: "defend_animation_\(defender.value)", priority: 1)
    ]

    return Reduction(state: state, commands: commands)
  }

  fileprivate func reduceEscape(
    state: State,
    escaper: CombatantID
  ) -> Reduction<State, JRPGAction> {

    // Player escape ends the encounter immediately.
    if state.playerIDs.contains(escaper) {
      let newState = state.withPhase(.ended(.escape))
      let commands: [any Command] = [
        BaseCommand(id: "escape_success", priority: 2)
      ]
      return Reduction(state: newState, commands: commands)
    }

    // Enemy escape is a future enhancement.
    return Reduction(state: state)
  }

  // MARK: - AI Coordination

  fileprivate func reduceRequestAIDecision(
    state: State,
    combatantID: CombatantID
  ) -> Reduction<State, JRPGAction> {

    // AI decision-making will arrive in a future phase.
    let commands: [any Command] = [
      BaseCommand(id: "ai_thinking_\(combatantID.value)", priority: 1)
    ]

    return Reduction(state: state, commands: commands)
  }
}
