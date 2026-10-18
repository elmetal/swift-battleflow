@testable import swift_battleflow

// MARK: - Status Ailment Sample Rule Set
//
// Poison hurts at the end of the poisoned combatant's turn, and sleep wears
// off at the end of each round. Neither happens while resolving a command, so
// the sample reacts to turn boundaries. Everything here is game-defined.

struct StatusSampleStats: CombatantStats {
  var hp: Int
  var attack: Int
  var agility: Int
  /// Damage taken at the end of each of the combatant's turns.
  var poison = 0
  /// Rounds left asleep.
  var sleep = 0

  var canAct: Bool { hp > 0 && sleep == 0 }
}

enum StatusSampleCommand: Sendable, Equatable {
  case attack(CombatantID)
  case poison(CombatantID, perTurn: Int)
  case lullaby(CombatantID, rounds: Int)
}

enum StatusSampleEffect: Sendable, Equatable {
  case damage(CombatantID, amount: Int)
  case poisoned(CombatantID, perTurn: Int)
  case fellAsleep(CombatantID, rounds: Int)
  case sleepWoreOff(CombatantID)
}

struct StatusSampleRules<Generator: BattleRandomGenerator>: RoundBasedRules {
  typealias Stats = StatusSampleStats
  typealias Command = StatusSampleCommand
  typealias Effect = StatusSampleEffect
  typealias Turns = RoundBasedTurns<Self>

  func resolve(
    _ command: Command, by actor: CombatantID, in state: CombatState<Self>,
    random: inout Generator
  ) -> [Effect] {
    switch command {
    case .attack(let target):
      return [.damage(target, amount: state.roster[actor]!.attack)]
    case .poison(let target, let perTurn):
      return [.poisoned(target, perTurn: perTurn)]
    case .lullaby(let target, let rounds):
      return [.fellAsleep(target, rounds: rounds)]
    }
  }

  func effects(
    at boundary: Turns.Boundary, in state: CombatState<Self>, random: inout Generator
  ) -> [Effect] {
    let roster = state.roster
    switch boundary {
    case .turnEnded(let id):
      let poison = roster[id]!.poison
      return poison > 0 ? [.damage(id, amount: poison)] : []
    case .roundEnded:
      return roster.stats.keys.sorted { $0.value < $1.value }
        .filter { roster[$0]!.hp > 0 && roster[$0]!.sleep > 0 }
        .map { .sleepWoreOff($0) }
    case .roundStarted, .turnStarted:
      return []
    }
  }

  func apply(_ effect: Effect, to roster: inout CombatRoster<Stats>) {
    switch effect {
    case .damage(let id, let amount):
      roster.update(id) { $0.hp = max(0, $0.hp - amount) }
    case .poisoned(let id, let perTurn):
      roster.update(id) { $0.poison = perTurn }
    case .fellAsleep(let id, let rounds):
      roster.update(id) { $0.sleep = rounds }
    case .sleepWoreOff(let id):
      roster.update(id) { $0.sleep -= 1 }
    }
  }

  func outcome(of roster: CombatRoster<Stats>) -> BattleOutcome? {
    if roster.members(of: .monsters).allSatisfy({ roster[$0]!.hp == 0 }) { return .partyWins }
    if roster.members(of: .party).allSatisfy({ roster[$0]!.hp == 0 }) { return .partyLoses }
    return nil
  }

  func priority(of command: Command) -> Int { 0 }

  func initiative(
    of actor: CombatantID, in roster: CombatRoster<Stats>, random: inout Generator
  ) -> Double {
    Double(roster[actor]!.agility)
  }
}
