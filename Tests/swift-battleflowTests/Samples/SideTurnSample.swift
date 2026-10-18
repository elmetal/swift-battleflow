@testable import swift_battleflow

// MARK: - A Custom Turn System Defined Outside the Library
//
// Sides alternate. The active side gets two half-turns per living member, and
// any of its members may act, even more than once. Each action costs half-turns
// decided by the rules after seeing its effects, so hitting a weakness can be
// cheaper than a normal action.

/// What the side-turn system needs from the rules.
protocol SideTurnRules: CombatRules {
  /// The sides in the order they take turns.
  var sideOrder: [BattleGroupID] { get }

  /// How many half-turns an action with these effects costs.
  func halfTurnCost(of effects: [Effect]) -> Int
}

struct SideTurns<Rules: SideTurnRules>: TurnSystem {
  private(set) var activeSide: BattleGroupID?
  private(set) var halfTurnsLeft = 0
  private(set) var pending: (actor: CombatantID, command: Rules.Command)?

  init() {}

  mutating func begin(with roster: CombatRoster<Rules.Stats>, rules: Rules) {
    startTurn(of: rules.sideOrder[0], in: roster)
  }

  func awaitingCommand(in roster: CombatRoster<Rules.Stats>) -> Set<CombatantID> {
    guard pending == nil, let activeSide else { return [] }
    return roster.members(of: activeSide).intersection(roster.actors)
  }

  mutating func record(
    _ command: Rules.Command, by actor: CombatantID, in roster: CombatRoster<Rules.Stats>,
    rules: Rules, random: inout Rules.Generator
  ) {
    pending = (actor, command)
  }

  mutating func takeNextAction(
    in roster: CombatRoster<Rules.Stats>, rules: Rules, random: inout Rules.Generator
  ) -> (actor: CombatantID, command: Rules.Command)? {
    defer { pending = nil }
    return pending
  }

  mutating func didPerform(
    _ effects: [Rules.Effect], by actor: CombatantID, in roster: CombatRoster<Rules.Stats>,
    rules: Rules
  ) {
    halfTurnsLeft -= rules.halfTurnCost(of: effects)
    guard halfTurnsLeft <= 0, let activeSide else { return }
    let index = rules.sideOrder.firstIndex(of: activeSide)!
    startTurn(of: rules.sideOrder[(index + 1) % rules.sideOrder.count], in: roster)
  }

  private mutating func startTurn(of side: BattleGroupID, in roster: CombatRoster<Rules.Stats>) {
    activeSide = side
    halfTurnsLeft = 2 * roster.members(of: side).intersection(roster.actors).count
  }

  static func == (lhs: SideTurns, rhs: SideTurns) -> Bool {
    lhs.activeSide == rhs.activeSide && lhs.halfTurnsLeft == rhs.halfTurnsLeft
      && lhs.pending?.actor == rhs.pending?.actor && lhs.pending?.command == rhs.pending?.command
  }
}

/// The spell sample's stats, commands, and formulas on the side-turn system.
struct SideTurnSampleRules<Generator: BattleRandomGenerator>: SideTurnRules {
  typealias Stats = ActiveTimeSampleStats
  typealias Command = ActiveTimeSampleCommand
  typealias Effect = ActiveTimeSampleEffect
  typealias Turns = SideTurns<Self>

  var sideOrder: [BattleGroupID] { [.allies, .foes] }

  func halfTurnCost(of effects: [Effect]) -> Int {
    let hitsWeakness = effects.contains {
      if case .damage(_, _, true) = $0 { return true }
      return false
    }
    return hitsWeakness ? 1 : 2
  }

  func resolve(
    _ command: Command, by actor: CombatantID, in state: CombatState<Self>,
    random: inout Generator
  ) -> [Effect] {
    SpellSampleMechanics.resolve(command, by: actor, in: state.roster, random: &random)
  }

  func apply(_ effect: Effect, to roster: inout CombatRoster<Stats>) {
    SpellSampleMechanics.apply(effect, to: &roster)
  }

  func outcome(of roster: CombatRoster<Stats>) -> BattleOutcome? {
    SpellSampleMechanics.outcome(of: roster)
  }
}
