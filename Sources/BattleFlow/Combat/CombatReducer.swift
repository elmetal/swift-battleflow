/// A reducer that runs a battle by a game's ``CombatRules``.
public struct CombatReducer<Rules: CombatRules>: Reducer {
  public typealias State = CombatState<Rules>
  public typealias Action = CombatAction<Rules>
  public typealias Output = CombatEvent<Rules>

  /// The game's rules.
  public let rules: Rules

  public init(rules: Rules) {
    self.rules = rules
  }

  /// Reduces an action, then submits the rules' automatic commands for
  /// combatants that are awaiting one.
  public func reduce(state: State, action: Action) -> Reduction<State, Action, Output> {
    let reduction = reduceAction(state: state, action: action)
    var progress = Progress(state: reduction.state, events: reduction.outputs)
    progress.submitAutomaticCommands(rules: rules)
    return progress.reduction
  }

  private func reduceAction(state: State, action: Action) -> Reduction<State, Action, Output> {
    switch action {
    case .start(let roster):
      guard state.phase == .preparation else {
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

    case .withdraw(let actor):
      guard state.withdrawableCommands.contains(actor) else {
        return Reduction(state: state)
      }
      var turns = state.turns
      turns.withdrawCommand(of: actor, in: state.roster, rules: rules)
      let withdrawn = state.with(turns: turns)
      precondition(
        withdrawn.awaitingCommand.contains(actor),
        "A turn system must await a combatant again once its command is withdrawn.")
      var progress = Progress(state: withdrawn)
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
        state: state.with(phase: .ended(outcome)),
        outputs: [.ended(outcome)])
    }
  }
}

extension CombatReducer {

  private func reduceStart(
    state: State, roster: CombatRoster<Rules.Stats>
  ) -> Reduction<State, Action, Output> {
    var turns = Rules.Turns()
    turns.begin(with: roster, rules: rules)

    var progress = Progress(
      state: state.with(phase: .ongoing, roster: roster, turns: turns),
      events: [CombatEvent<Rules>.started])
    progress.reachBoundaries(rules: rules)
    return progress.reduction
  }

  private func reducePerformNextAction(state: State) -> Reduction<State, Action, Output> {
    var turns = state.turns
    var random = state.random
    let next = turns.takeNextAction(in: state.roster, rules: rules, random: &random)

    var progress = Progress(state: state.with(turns: turns, random: random))
    progress.reachBoundaries(rules: rules)
    guard let (actor, command) = next, progress.state.isOngoing else {
      return progress.reduction
    }

    progress.state = progress.state.with(
      currentActor: actor)
    guard progress.state.roster[actor]?.canAct == true else {
      progress.events.append(CombatEvent<Rules>.skipped(actor: actor))
      return progress.reduction
    }

    random = progress.state.random
    let effects = rules.resolve(command, by: actor, in: progress.state, random: &random)
    progress.state = progress.state.with(random: random)
    let result = progress.run(effects, rules: rules)
    progress.events.append(
      CombatEvent<Rules>.performed(actor: actor, command: command, effects: result.applied))
    if let outcome = result.outcome {
      progress.events.append(CombatEvent<Rules>.ended(outcome))
      return progress.reduction
    }

    turns = progress.state.turns
    turns.didPerform(result.applied, by: actor, in: progress.state.roster, rules: rules)
    progress.state = progress.state.with(turns: turns)
    progress.reachBoundaries(rules: rules)
    return progress.reduction
  }
}

/// A battle state together with the events emitted while it changes.
private struct Progress<Rules: CombatRules> {
  var state: CombatState<Rules>
  var events: [CombatEvent<Rules>] = []

  var reduction: CombatReduction<Rules> {
    Reduction(state: state, outputs: events)
  }

  /// Applies effects one at a time, letting the rules react to each, until
  /// the queue is empty or the battle is decided.
  ///
  /// - Returns: The effects that were applied, in order, and the outcome if
  ///   the battle was decided.
  mutating func run(
    _ effects: [Rules.Effect], rules: Rules
  ) -> (applied: [Rules.Effect], outcome: BattleOutcome?) {
    var queue = EffectQueue<Rules>(effects, scheduled: state.scheduledEffects)
    var applied: [Rules.Effect] = []
    var outcome: BattleOutcome?

    while outcome == nil, let effect = queue.popNext() {
      var roster = state.roster
      rules.apply(effect, to: &roster)
      update(roster, rules: rules)
      applied.append(effect)

      if let decided = rules.outcome(of: roster) {
        state = state.with(phase: .ended(decided))
        outcome = decided
      } else {
        var random = state.random
        rules.react(to: effect, in: state, queue: &queue, random: &random)
        state = state.with(random: random)
      }
    }

    state = state.with(scheduledEffects: queue.scheduled)
    return (applied, outcome)
  }

  /// Stores a roster changed by an effect, telling the turn system who
  /// joined or left.
  private mutating func update(_ roster: CombatRoster<Rules.Stats>, rules: Rules) {
    let before = Set(state.roster.stats.keys)
    let after = Set(roster.stats.keys)
    let added = after.subtracting(before)
    let removed = before.subtracting(after)
    guard !added.isEmpty || !removed.isEmpty else {
      state = state.with(roster: roster)
      return
    }

    var turns = state.turns
    turns.didChangeRoster(added: added, removed: removed, in: roster, rules: rules)
    let currentActor = state.currentActor.flatMap { removed.contains($0) ? nil : $0 }
    state = state.with(roster: roster, currentActor: .some(currentActor), turns: turns)
  }

  /// Submits the rules' automatic commands, one at a time in ID order, until
  /// no awaiting combatant gets one.
  mutating func submitAutomaticCommands(rules: Rules) {
    while state.isOngoing, let next = nextAutomaticCommand(rules: rules) {
      var random = next.random
      var turns = state.turns
      turns.record(next.command, by: next.actor, in: state.roster, rules: rules, random: &random)
      state = state.with(turns: turns, random: random)
      precondition(
        !state.awaitingCommand.contains(next.actor),
        "A turn system must stop awaiting a combatant once its command is recorded.")
      events.append(
        CombatEvent<Rules>.submittedAutomatically(actor: next.actor, command: next.command))
      reachBoundaries(rules: rules)
    }
  }

  /// Returns the first awaiting combatant, in ID order, that the rules choose
  /// a command for, with the generator advanced by that choice.
  private func nextAutomaticCommand(
    rules: Rules
  ) -> (actor: CombatantID, command: Rules.Command, random: Rules.Generator)? {
    for actor in state.awaitingCommand.sorted(by: { $0.value < $1.value }) {
      var random = state.random
      if let command = rules.automaticCommand(for: actor, in: state, random: &random) {
        return (actor, command, random)
      }
    }
    return nil
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
      var schedule = EffectQueue<Rules>([], scheduled: state.scheduledEffects)
      let due = schedule.reach(boundary)
      state = state.with(random: random, scheduledEffects: schedule.scheduled)

      // The rules' effects for the boundary run first, then scheduled ones.
      let result = run(effects + due, rules: rules)
      events.append(CombatEvent<Rules>.boundary(boundary, effects: result.applied))
      if let outcome = result.outcome {
        events.append(CombatEvent<Rules>.ended(outcome))
      }
    }
  }
}
