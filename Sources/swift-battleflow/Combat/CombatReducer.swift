/// A reducer that runs a battle by a game's ``CombatRules``.
public struct CombatReducer<Rules: CombatRules>: Reducer {
  public typealias State = CombatState<Rules>
  public typealias Action = CombatAction<Rules>

  /// The game's rules.
  public let rules: Rules

  public init(rules: Rules) {
    self.rules = rules
  }

  public func reduce(state: State, action: Action) -> Reduction<State, Action> {
    switch action {
    case .start(let roster):
      guard state.engineState.phase == .preparation else {
        return Reduction(state: state)
      }
      return reduceStart(state: state, roster: roster)

    case .submit(let command, let actor):
      guard state.awaitingCommand.contains(actor) else {
        return Reduction(state: state)
      }
      var turns = state.turns
      var random = state.random
      turns.record(command, by: actor, in: state.roster, rules: rules, random: &random)
      return Reduction(state: state.with(turns: turns, random: random))

    case .performNextAction:
      guard state.isOngoing else {
        return Reduction(state: state)
      }
      return reducePerformNextAction(state: state)

    case .advanceTime(let seconds):
      precondition(seconds >= 0, "Time cannot go backwards.")
      guard state.isOngoing else {
        return Reduction(state: state)
      }
      var turns = state.turns
      turns.advanceTime(by: seconds, in: state.roster, rules: rules)
      return Reduction(state: state.with(turns: turns))

    case .end(let outcome):
      guard state.isOngoing else {
        return Reduction(state: state)
      }
      return Reduction(
        state: state.with(engineState: state.engineState.withPhase(.ended(outcome))),
        commands: [CombatEvent<Rules>.ended(outcome)])
    }
  }
}

extension CombatReducer {

  private func reduceStart(
    state: State, roster: CombatRoster<Rules.Stats>
  ) -> Reduction<State, Action> {
    var engineState = state.engineState
    for (side, members) in roster.sides {
      for id in members {
        engineState = engineState.withParticipant(BattleParticipant(id: id), in: side)
      }
    }

    var turns = Rules.Turns()
    turns.begin(with: roster, rules: rules)

    let newState = state.with(
      engineState: engineState.withPhase(.ongoing), stats: roster.stats, turns: turns)
    return Reduction(state: newState, commands: [CombatEvent<Rules>.started])
  }

  private func reducePerformNextAction(state: State) -> Reduction<State, Action> {
    var turns = state.turns
    var random = state.random

    guard
      let (actor, command) = turns.takeNextAction(in: state.roster, rules: rules, random: &random)
    else {
      return Reduction(state: state.with(turns: turns, random: random))
    }

    let acting = state.with(
      engineState: state.engineState.withCurrentActor(actor), turns: turns, random: random)

    guard acting.roster[actor]?.canAct == true else {
      return Reduction(state: acting, commands: [CombatEvent<Rules>.skipped(actor: actor)])
    }

    let effects = rules.resolve(command, by: actor, in: acting, random: &random)
    var roster = acting.roster
    for effect in effects {
      rules.apply(effect, to: &roster)
    }
    turns.didPerform(effects, by: actor, in: roster, rules: rules)

    var events: [any Command] = [
      CombatEvent<Rules>.performed(actor: actor, command: command, effects: effects)
    ]
    var engineState = acting.engineState
    if let outcome = rules.outcome(of: roster) {
      engineState = engineState.withPhase(.ended(outcome))
      events.append(CombatEvent<Rules>.ended(outcome))
    }

    return Reduction(
      state: acting.with(
        engineState: engineState, stats: roster.stats, turns: turns, random: random),
      commands: events)
  }
}
