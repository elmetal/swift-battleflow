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

    case .scheduleActions(let order):
      return Reduction(state: state.withActionOrder(order))

    case .advanceActor:
      return Reduction(state: state.advancingActor())

    // MARK: - Command Management
    case .enqueueCommands(let commands):
      return reduceEnqueueCommands(state: state, commands: commands)

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
    let newState = state.advancingTurn()

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

    let newState = state.withCurrentActor(actorID)

    return Reduction(state: newState)
  }

  // MARK: - Command Management

  private func reduceEnqueueCommands(
    state: BattleState,
    commands: [any Command]
  ) -> Reduction<BattleState, BattleAction> {

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
