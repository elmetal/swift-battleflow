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
      var progress = Progress(state: state.with(turns: turns, random: random))
      progress.reachBoundaries(rules: rules)
      return progress.reduction

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
      var progress = Progress(state: state.with(turns: turns))
      progress.reachBoundaries(rules: rules)
      return progress.reduction

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
        engineState = engineState.withParticipant(id, in: side)
      }
    }

    var turns = Rules.Turns()
    turns.begin(with: roster, rules: rules)

    var progress = Progress(
      state: state.with(
        engineState: engineState.withPhase(.ongoing), stats: roster.stats, turns: turns),
      events: [CombatEvent<Rules>.started])
    progress.reachBoundaries(rules: rules)
    return progress.reduction
  }

  private func reducePerformNextAction(state: State) -> Reduction<State, Action> {
    var turns = state.turns
    var random = state.random
    let next = turns.takeNextAction(in: state.roster, rules: rules, random: &random)

    var progress = Progress(state: state.with(turns: turns, random: random))
    progress.reachBoundaries(rules: rules)
    guard let (actor, command) = next, progress.state.isOngoing else {
      return progress.reduction
    }

    progress.state = progress.state.with(
      engineState: progress.state.engineState.withCurrentActor(actor))
    guard progress.state.roster[actor]?.canAct == true else {
      progress.events.append(CombatEvent<Rules>.skipped(actor: actor))
      return progress.reduction
    }

    random = progress.state.random
    let effects = rules.resolve(command, by: actor, in: progress.state, random: &random)
    progress.state = progress.state.with(random: random)
    progress.apply(effects, rules: rules)
    progress.events.append(
      CombatEvent<Rules>.performed(actor: actor, command: command, effects: effects))
    progress.decideOutcome(rules: rules)
    guard progress.state.isOngoing else {
      return progress.reduction
    }

    turns = progress.state.turns
    turns.didPerform(effects, by: actor, in: progress.state.roster, rules: rules)
    progress.state = progress.state.with(turns: turns)
    progress.reachBoundaries(rules: rules)
    return progress.reduction
  }
}

/// A battle state together with the events emitted while it changes.
private struct Progress<Rules: CombatRules> {
  var state: CombatState<Rules>
  var events: [any Command] = []

  var reduction: Reduction<CombatState<Rules>, CombatAction<Rules>> {
    Reduction(state: state, commands: events)
  }

  /// Applies effects to the roster.
  mutating func apply(_ effects: [Rules.Effect], rules: Rules) {
    var roster = state.roster
    for effect in effects {
      rules.apply(effect, to: &roster)
    }
    state = state.with(stats: roster.stats)
  }

  /// Ends the battle if the rules decide it.
  mutating func decideOutcome(rules: Rules) {
    guard let outcome = rules.outcome(of: state.roster) else {
      return
    }
    state = state.with(engineState: state.engineState.withPhase(.ended(outcome)))
    events.append(CombatEvent<Rules>.ended(outcome))
  }

  /// Handles the boundaries the turn system reached, in order, until the
  /// battle ends.
  mutating func reachBoundaries(rules: Rules) {
    var turns = state.turns
    let boundaries = turns.takeBoundaries()
    state = state.with(turns: turns)

    for boundary in boundaries {
      guard state.isOngoing else {
        return
      }
      var random = state.random
      let effects = rules.effects(at: boundary, in: state, random: &random)
      state = state.with(random: random)
      apply(effects, rules: rules)
      events.append(CombatEvent<Rules>.boundary(boundary, effects: effects))
      decideOutcome(rules: rules)
    }
  }
}
