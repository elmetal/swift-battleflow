/// The state of a battle that follows a game's ``CombatRules``.
///
/// The engine state holds the phase, participants, sides, and current actor;
/// this state adds the game's stats, the turn system's state, and the random
/// generator. Everything is a value, so reducing the same state with the same
/// action always gives the same result.
public struct CombatState<Rules: CombatRules>: Sendable, Equatable {
  /// The rule-agnostic engine state.
  public let engineState: BattleState

  /// The stats of every combatant.
  public let stats: [CombatantID: Rules.Stats]

  /// The turn system's state.
  public let turns: Rules.Turns

  /// The random generator, advanced each time a roll is drawn.
  public let random: Rules.Generator

  /// Creates the state of a battle that has not started.
  public init(random: Rules.Generator) {
    self.init(
      engineState: BattleState(), stats: [:], turns: Rules.Turns(), random: random)
  }

  init(
    engineState: BattleState, stats: [CombatantID: Rules.Stats], turns: Rules.Turns,
    random: Rules.Generator
  ) {
    precondition(
      Set(stats.keys) == engineState.participants,
      "Every combatant must be an engine participant, and vice versa.")
    self.engineState = engineState
    self.stats = stats
    self.turns = turns
    self.random = random
  }

  /// The combatants grouped by side, derived from the engine groups.
  public var roster: CombatRoster<Rules.Stats> {
    CombatRoster(stats: stats, sides: engineState.groups)
  }

  /// Whether the battle has started and not yet ended.
  public var isOngoing: Bool {
    engineState.phase == .ongoing
  }

  /// Whether the battle has ended.
  public var isEnded: Bool {
    engineState.isBattleEnded
  }

  /// The outcome of the battle, or `nil` while it is not decided.
  public var outcome: BattleOutcome? {
    engineState.outcome
  }

  /// The combatant that acted most recently.
  public var currentActor: CombatantID? {
    engineState.currentActor
  }

  /// The combatants that may submit a command now.
  public var awaitingCommand: Set<CombatantID> {
    guard isOngoing else {
      return []
    }
    let roster = roster
    return turns.awaitingCommand(in: roster).intersection(roster.actors)
  }

  func with(
    engineState: BattleState? = nil, stats: [CombatantID: Rules.Stats]? = nil,
    turns: Rules.Turns? = nil, random: Rules.Generator? = nil
  ) -> CombatState {
    CombatState(
      engineState: engineState ?? self.engineState, stats: stats ?? self.stats,
      turns: turns ?? self.turns, random: random ?? self.random)
  }
}
