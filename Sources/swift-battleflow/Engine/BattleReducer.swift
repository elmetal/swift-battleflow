/// A reducer that applies engine actions to battle state.
///
/// Use a reducer to transform an immutable ``BattleState`` with a
/// ``BattleAction``. The reducer returns the updated state and any effects that
/// the caller should execute after the state transition completes.
public struct BattleReducer: Sendable {

  /// Creates a battle reducer.
  public init() {}

  /// Returns the result of applying an action to a battle state.
  ///
  /// - Parameters:
  ///   - state: The battle state to transform.
  ///   - action: The engine action to apply.
  /// - Returns: A tuple containing the transformed state and the generated
  ///   effects.
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

    // Executing an effect does not change engine state.
    return (state, [])
  }

  private func reduceClearEffects(state: BattleState) -> (BattleState, [any Effect]) {
    let newState = state.withClearedEffects()
    return (newState, [])
  }
}
