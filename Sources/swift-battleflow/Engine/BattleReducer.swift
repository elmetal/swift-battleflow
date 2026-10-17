/// A reducer that applies engine actions to battle state.
///
/// Use a reducer to transform an immutable ``BattleState`` with a
/// ``BattleAction``. The reducer returns the updated state and any work that the
/// caller should execute after the state transition completes.
public struct BattleReducer: Reducer {
  public typealias State = BattleState
  public typealias Action = BattleAction

  /// Creates a battle reducer.
  public init() {}

  /// Returns the result of applying an action to a battle state.
  ///
  /// - Parameters:
  ///   - state: The battle state to transform.
  ///   - action: The engine action to apply.
  /// - Returns: A reduction containing the transformed state and generated work.
  public func reduce(state: BattleState, action: BattleAction) -> Reduction<
    BattleState, BattleAction
  > {
    switch action {

    case .transitionPhase(let newPhase):
      return reduceTransitionPhase(state: state, newPhase: newPhase)

    case .incrementTurn:
      return reduceIncrementTurn(state: state)

    // MARK: - Turn Coordination
    case .updateCurrentActor(let actorID):
      return reduceUpdateCurrentActor(state: state, actorID: actorID)

    case .beginSelection(let combatantID):
      return reduceBeginSelection(state: state, combatantID: combatantID)

    case .completeSelection(let selection, let combatantID):
      return reduceCompleteSelection(
        state: state, combatantID: combatantID, selection: selection)

    // MARK: - Command Management
    case .enqueueCommands(let commandIDs):
      return reduceEnqueueCommands(state: state, commandIDs: commandIDs)

    case .markCommandExecuted(let commandID):
      return reduceMarkCommandExecuted(state: state, commandID: commandID)

    case .removeAllCommands:
      return reduceRemoveAllCommands(state: state)

    }
  }
}

// MARK: - Private Reducer Methods

extension BattleReducer {

  // MARK: - Battle Flow Control

  private func reduceTransitionPhase(
    state: BattleState,
    newPhase: BattlePhase
  ) -> Reduction<BattleState, BattleAction> {

    let newState = state.withPhase(newPhase)
    let commands: [any Command] = [
      BaseCommand(id: "phase_transition_\(newPhase)", priority: 1)
    ]

    return Reduction(state: newState, commands: commands)
  }

  private func reduceIncrementTurn(state: BattleState) -> Reduction<BattleState, BattleAction> {
    let newState = BattleState(
      phase: state.phase,
      participants: state.participants,
      groups: state.groups,
      turnCount: state.turnCount + 1,
      currentActor: nil,
      pendingCommands: state.pendingCommands
    )

    let commands: [any Command] = [
      BaseCommand(id: "turn_advance", priority: 1)
    ]

    return Reduction(state: newState, commands: commands)
  }

  // MARK: - Turn Coordination

  private func reduceUpdateCurrentActor(
    state: BattleState,
    actorID: CombatantID?
  ) -> Reduction<BattleState, BattleAction> {

    let newState = BattleState(
      phase: state.phase,
      participants: state.participants,
      groups: state.groups,
      turnCount: state.turnCount,
      currentActor: actorID,
      pendingCommands: state.pendingCommands
    )

    return Reduction(state: newState)
  }

  private func reduceBeginSelection(
    state: BattleState,
    combatantID: CombatantID
  ) -> Reduction<BattleState, BattleAction> {

    let commands: [any Command] = [
      BaseCommand(id: "action_selection_begin_\(combatantID.value)", priority: 1)
    ]

    return Reduction(state: state, commands: commands)
  }

  private func reduceCompleteSelection(
    state: BattleState,
    combatantID: CombatantID,
    selection: BattleSelection
  ) -> Reduction<BattleState, BattleAction> {

    let commands: [any Command] = [
      BaseCommand(id: "action_selection_complete_\(combatantID.value)", priority: 1)
    ]

    return Reduction(state: state, commands: commands)
  }

  // MARK: - Command Management

  private func reduceEnqueueCommands(
    state: BattleState,
    commandIDs: [String]
  ) -> Reduction<BattleState, BattleAction> {

    let commands = commandIDs.map { BaseCommand(id: $0, priority: 1) }
    let newState = state.appendingCommands(commands)
    return Reduction(state: newState)
  }

  private func reduceMarkCommandExecuted(
    state: BattleState,
    commandID: String
  ) -> Reduction<BattleState, BattleAction> {

    let newState = state.removingFirstCommand(withID: commandID)
    return Reduction(state: newState)
  }

  private func reduceRemoveAllCommands(state: BattleState) -> Reduction<BattleState, BattleAction> {
    let newState = state.removingAllCommands()
    return Reduction(state: newState)
  }
}
