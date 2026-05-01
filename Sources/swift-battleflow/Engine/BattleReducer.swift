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

    // MARK: - Command Management
    case .enqueueCommands(let commandIDs):
      return reduceAddCommands(state: state, commandIDs: commandIDs)

    case .markCommandExecuted(let commandID):
      return reduceExecuteCommand(state: state, commandID: commandID)

    case .removeAllCommands:
      return reduceClearCommands(state: state)

    }
  }
}

// MARK: - Private Reducer Methods

extension BattleReducer {

  // MARK: - Battle Flow Control

  private func reduceAdvancePhase(
    state: BattleState,
    newPhase: BattlePhase
  ) -> Reduction<BattleState, BattleAction> {

    let newState = state.withPhase(newPhase)
    let commands: [any Command] = [
      BaseCommand(id: "phase_transition_\(newPhase)", priority: 1)
    ]

    return Reduction(state: newState, commands: commands)
  }

  private func reduceAdvanceTurn(state: BattleState) -> Reduction<BattleState, BattleAction> {
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

  private func reduceSetCurrentActor(
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

  private func reduceBeginActionSelection(
    state: BattleState,
    combatantID: CombatantID
  ) -> Reduction<BattleState, BattleAction> {

    let commands: [any Command] = [
      BaseCommand(id: "action_selection_begin_\(combatantID.value)", priority: 1)
    ]

    return Reduction(state: state, commands: commands)
  }

  private func reduceCompleteActionSelection(
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

  private func reduceAddCommands(
    state: BattleState,
    commandIDs: [String]
  ) -> Reduction<BattleState, BattleAction> {

    let commands = commandIDs.map { BaseCommand(id: $0, priority: 1) }
    let newState = state.withCommands(commands)
    return Reduction(state: newState)
  }

  private func reduceExecuteCommand(
    state: BattleState,
    commandID: String
  ) -> Reduction<BattleState, BattleAction> {

    // Executing a command does not change engine state.
    return Reduction(state: state)
  }

  private func reduceClearCommands(state: BattleState) -> Reduction<BattleState, BattleAction> {
    let newState = state.withClearedCommands()
    return Reduction(state: newState)
  }
}
