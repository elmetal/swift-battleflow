@testable import BattleFlow

// MARK: - Roster Change Sample Rule Set
//
// Combatants join and leave mid-battle: monsters call for help, the party
// summons a spirit, anyone can flee, and a banishment removes its target.
// Leaving differs from being defeated: a defeated combatant stays in the
// roster, while one that left is gone.

extension BattleOutcome {
  static let partyEscaped = BattleOutcome("sample.party_escaped")
}

struct RosterChangeSampleStats: CombatantStats {
  var hp: Int
  var attack: Int
  var agility: Int

  var canAct: Bool { hp > 0 }
}

enum RosterChangeSampleCommand: Sendable, Equatable {
  case attack(CombatantID)
  /// Brings in a new combatant on the actor's side.
  case callForHelp(CombatantID)
  case flee
  case banish(CombatantID)
}

enum RosterChangeSampleEffect: Sendable, Equatable {
  case damage(CombatantID, amount: Int)
  case joined(CombatantID, RosterChangeSampleStats, side: BattleGroupID)
  case left(CombatantID)
}

struct RosterChangeSampleRules<Generator: BattleRandomGenerator>: RoundBasedRules {
  typealias Stats = RosterChangeSampleStats
  typealias Command = RosterChangeSampleCommand
  typealias Effect = RosterChangeSampleEffect
  typealias Turns = RoundBasedTurns<Self>

  func resolve(
    _ command: Command, by actor: CombatantID, in state: CombatState<Self>,
    random: inout Generator
  ) -> [Effect] {
    let roster = state.roster
    switch command {
    case .attack(let target):
      guard roster[target]?.canAct == true else { return [] }
      return [.damage(target, amount: roster[actor]!.attack)]
    case .callForHelp(let newcomer):
      guard roster[newcomer] == nil else { return [] }
      return [
        .joined(
          newcomer, RosterChangeSampleStats(hp: 10, attack: 2, agility: 3),
          side: roster.side(of: actor)!)
      ]
    case .flee:
      return [.left(actor)]
    case .banish(let target):
      return roster[target] == nil ? [] : [.left(target)]
    }
  }

  func apply(_ effect: Effect, to roster: inout CombatRoster<Stats>) {
    switch effect {
    case .damage(let id, let amount):
      roster.update(id) { $0.hp = max(0, $0.hp - amount) }
    case .joined(let id, let stats, let side):
      roster.add(id, stats: stats, to: side)
    case .left(let id):
      roster.remove(id)
    }
  }

  func outcome(of roster: CombatRoster<Stats>) -> BattleOutcome? {
    if roster.members(of: .party).isEmpty { return .partyEscaped }
    if roster.members(of: .monsters).allSatisfy({ !roster[$0]!.canAct }) { return .partyWins }
    if roster.members(of: .party).allSatisfy({ !roster[$0]!.canAct }) { return .partyLoses }
    return nil
  }

  func priority(of command: Command) -> Int { 0 }

  func initiative(
    of actor: CombatantID, in roster: CombatRoster<Stats>, random: inout Generator
  ) -> Double {
    Double(roster[actor]!.agility)
  }
}
