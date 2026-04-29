/// The reducer at the heart of the state-store pattern.
///
/// Combines an action and a state into a new state plus a collection of
/// generated effects.
public struct BattleReducer: Sendable {

  public init() {}

  /// Reduces engine-level actions while preserving JRPG rule state.
  public func reduce(
    state: JRPGBattleState,
    action: BattleAction
  ) -> (JRPGBattleState, [any Effect]) {
    let (engineState, effects) = reduce(state: state.engineState, action: action)
    return (state.withEngineState(engineState), effects)
  }

  /// Reduces engine-level actions.
  public func reduce(state: BattleState, action: BattleAction) -> (BattleState, [any Effect]) {
    switch action {

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
