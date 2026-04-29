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
    case .engine(let action):
      return reduce(state: state, action: action)

    case .jrpg:
      return (state, [])
    }
  }

  /// Reduces actions against the default JRPG battle state.
  public func reduce(
    state: JRPGBattleState,
    action: BattleAction
  ) -> (JRPGBattleState, [any Effect]) {
    switch action {
    case .engine(let action):
      return reduce(state: state, action: action)

    case .jrpg(let action):
      return jrpgReducer.reduce(state: state, action: action)
    }
  }

  /// Reduces engine-level actions while preserving JRPG rule state.
  public func reduce(
    state: JRPGBattleState,
    action: EngineAction
  ) -> (JRPGBattleState, [any Effect]) {
    switch action {
    case .startBattleFlow(let players, let enemies):
      return reduceStartBattle(state: state, players: players, enemies: enemies)

    case .endBattleFlow(let result):
      return reduceEndBattle(state: state, result: result)

    default:
      let (engineState, effects) = reduce(state: state.engineState, action: action)
      return (state.withEngineState(engineState), effects)
    }
  }

  /// Reduces engine-level actions.
  public func reduce(state: BattleState, action: EngineAction) -> (BattleState, [any Effect]) {
    switch action {

    // MARK: - Battle Flow Control
    case .startBattleFlow(let players, let enemies):
      return reduceStartBattleFlow(state: state, players: players, enemies: enemies)

    case .endBattleFlow(let result):
      return reduceEndBattleFlow(state: state, result: result)

    case .transitionPhase(let newPhase):
      return reduceAdvancePhase(state: state, newPhase: newPhase)

    case .incrementTurn:
      return reduceAdvanceTurn(state: state)

    // MARK: - Turn Coordination
    case .updateCurrentActor(let actorID):
      return reduceSetCurrentActor(state: state, actorID: actorID)

    case .beginSelection(let combatantID):
      return reduceBeginActionSelection(state: state, combatantID: combatantID)

    case .completeSelection(let combatantID, let selection):
      return reduceCompleteActionSelection(
        state: state, combatantID: combatantID, selection: selection)

    // MARK: - Effect Management
    case .enqueueEffects(let effectIDs):
      return reduceAddEffects(state: state, effectIDs: effectIDs)

    case .markEffectExecuted(let effectID):
      return reduceExecuteEffect(state: state, effectID: effectID)

    case .removeAllEffects:
      return reduceClearEffects(state: state)

    }
  }
}

// MARK: - Private Reducer Methods

extension BattleReducer {

  // MARK: - Battle Flow Control

  private func reduceStartBattle(
    state: JRPGBattleState,
    players: [Combatant],
    enemies: [Combatant]
  ) -> (JRPGBattleState, [any Effect]) {

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

    let newState = JRPGBattleState(
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
      BaseEffect(id: "battle_music_start", priority: 1),
    ]

    return (newState, effects)
  }

  private func reduceStartBattleFlow(
    state: BattleState,
    players: [Combatant],
    enemies: [Combatant]
  ) -> (BattleState, [any Effect]) {
    var participants: [CombatantID: BattleParticipant] = [:]
    var playerIDs: Set<CombatantID> = []
    var enemyIDs: Set<CombatantID> = []

    for player in players {
      participants[player.id] = BattleParticipant(id: player.id)
      playerIDs.insert(player.id)
    }

    for enemy in enemies {
      participants[enemy.id] = BattleParticipant(id: enemy.id)
      enemyIDs.insert(enemy.id)
    }

    let newState = BattleState(
      phase: .turnSelection,
      participants: participants,
      groups: [
        .players: playerIDs,
        .enemies: enemyIDs,
      ],
      turnCount: 1,
      currentActor: nil,
      pendingEffects: []
    )

    let effects: [any Effect] = [
      BaseEffect(id: "battle_start_animation", priority: 1),
      BaseEffect(id: "battle_music_start", priority: 1),
    ]

    return (newState, effects)
  }

  private func reduceEndBattle(
    state: JRPGBattleState,
    result: BattleResult
  ) -> (JRPGBattleState, [any Effect]) {

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
      BaseEffect(id: "battle_music_stop", priority: 0),
    ]

    return (newState, effects)
  }

  private func reduceEndBattleFlow(
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
      BaseEffect(id: "battle_music_stop", priority: 0),
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
      participants: state.participants,
      groups: state.groups,
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
      participants: state.participants,
      groups: state.groups,
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
    selection: BattleSelection
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
