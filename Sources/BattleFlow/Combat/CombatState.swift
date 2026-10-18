/// Represents the current phase of a battle.
///
/// Phases within an ongoing battle, such as selecting commands or waiting for
/// gauges, depend on the turn system, so turn systems track them themselves.
public enum BattlePhase: Sendable, Equatable {
  case preparation  // The battle has not started.
  case ongoing  // The battle is in progress.
  case ended(BattleOutcome)  // The battle is over with a rule-defined outcome.
}

/// The state of a battle that follows a game's ``CombatRules``.
///
/// Everything is a value, so reducing the same state with the same action
/// always gives the same result.
public struct CombatState<Rules: CombatRules>: Sendable, Equatable {
  /// The phase of the battle.
  public let phase: BattlePhase

  /// The combatants grouped by side, with their stats.
  public let roster: CombatRoster<Rules.Stats>

  /// The combatant that acted most recently.
  public let currentActor: CombatantID?

  /// The turn system's state.
  public let turns: Rules.Turns

  /// The random generator, advanced each time a roll is drawn.
  public let random: Rules.Generator

  /// The effects waiting for a turn boundary, in the order they were
  /// scheduled.
  public let scheduledEffects: [ScheduledEffect<Rules>]

  /// Creates the state of a battle that has not started.
  public init(random: Rules.Generator) {
    self.init(
      phase: .preparation, roster: CombatRoster(sides: [:]), currentActor: nil,
      turns: Rules.Turns(), random: random, scheduledEffects: [])
  }

  init(
    phase: BattlePhase, roster: CombatRoster<Rules.Stats>, currentActor: CombatantID?,
    turns: Rules.Turns, random: Rules.Generator, scheduledEffects: [ScheduledEffect<Rules>]
  ) {
    self.phase = phase
    self.roster = roster
    self.currentActor = currentActor
    self.turns = turns
    self.random = random
    self.scheduledEffects = scheduledEffects
  }

  /// Whether the battle has started and not yet ended.
  public var isOngoing: Bool {
    phase == .ongoing
  }

  /// Whether the battle has ended.
  public var isEnded: Bool {
    outcome != nil
  }

  /// The outcome of the battle, or `nil` while it is not decided.
  public var outcome: BattleOutcome? {
    guard case .ended(let outcome) = phase else {
      return nil
    }
    return outcome
  }

  /// The combatants that may submit a command now.
  public var awaitingCommand: Set<CombatantID> {
    guard isOngoing else {
      return []
    }
    return turns.awaitingCommand(in: roster).intersection(roster.actors)
  }

  func with(
    phase: BattlePhase? = nil, roster: CombatRoster<Rules.Stats>? = nil,
    currentActor: CombatantID?? = nil, turns: Rules.Turns? = nil, random: Rules.Generator? = nil,
    scheduledEffects: [ScheduledEffect<Rules>]? = nil
  ) -> CombatState {
    CombatState(
      phase: phase ?? self.phase, roster: roster ?? self.roster,
      currentActor: currentActor ?? self.currentActor, turns: turns ?? self.turns,
      random: random ?? self.random, scheduledEffects: scheduledEffects ?? self.scheduledEffects)
  }
}
