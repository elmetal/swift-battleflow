@testable import swift_battleflow

// MARK: - Reaction Sample Rule Set
//
// Effects trigger further effects: a counterattack runs after everything
// already queued, enraging below half HP runs immediately, and a curse makes
// its target collapse at the end of its second turn unless it is lifted.

struct ReactionSampleStats: CombatantStats {
  var hp: Int
  var maxHP: Int
  var attack: Int
  var agility: Int
  /// Damage dealt back to an attacker; zero for none.
  var counter = 0
  var isEnraged = false

  var canAct: Bool { hp > 0 }
}

enum ReactionSampleCommand: Sendable, Equatable {
  case attack(CombatantID)
  /// Hits each target in order.
  case sweep([CombatantID])
  case curse(CombatantID)
  case bless(CombatantID)
}

enum ReactionSampleEffect: Sendable, Equatable {
  case damage(CombatantID, amount: Int, source: CombatantID, isCounter: Bool)
  case enrage(CombatantID)
  case cursed(CombatantID)
  case lifted(CombatantID)
  case collapse(CombatantID)
}

struct ReactionSampleRules<Generator: BattleRandomGenerator>: RoundBasedRules {
  typealias Stats = ReactionSampleStats
  typealias Command = ReactionSampleCommand
  typealias Effect = ReactionSampleEffect
  typealias Turns = RoundBasedTurns<Self>

  func resolve(
    _ command: Command, by actor: CombatantID, in state: CombatState<Self>,
    random: inout Generator
  ) -> [Effect] {
    let attacker = state.roster[actor]!
    let power = attacker.isEnraged ? attacker.attack * 2 : attacker.attack
    switch command {
    case .attack(let target):
      return [.damage(target, amount: power, source: actor, isCounter: false)]
    case .sweep(let targets):
      return targets.map { .damage($0, amount: power, source: actor, isCounter: false) }
    case .curse(let target):
      return [.cursed(target)]
    case .bless(let target):
      return [.lifted(target)]
    }
  }

  func react(
    to effect: Effect, in state: CombatState<Self>, queue: inout EffectQueue<Self>,
    random: inout Generator
  ) {
    let roster = state.roster
    switch effect {
    case .damage(let target, _, let source, let isCounter):
      guard let defender = roster[target], defender.canAct else { return }
      // Enraging happens at once, before anything else in the queue.
      if !defender.isEnraged && defender.hp * 2 <= defender.maxHP {
        queue.prepend(.enrage(target))
      }
      // A counterattack waits until everything already queued has happened.
      if defender.counter > 0 && !isCounter && roster[source]?.canAct == true {
        queue.append(.damage(source, amount: defender.counter, source: target, isCounter: true))
      }
    case .cursed(let target):
      queue.schedule(.collapse(target), at: .turnEnded(target), occurrence: 2)
    case .lifted(let target):
      queue.cancelScheduled { $0.effect == .collapse(target) }
    case .enrage, .collapse:
      break
    }
  }

  func apply(_ effect: Effect, to roster: inout CombatRoster<Stats>) {
    switch effect {
    case .damage(let id, let amount, _, _):
      roster.update(id) { $0.hp = max(0, $0.hp - amount) }
    case .enrage(let id):
      roster.update(id) { $0.isEnraged = true }
    case .collapse(let id):
      roster.update(id) { $0.hp = 0 }
    case .cursed, .lifted:
      break
    }
  }

  func outcome(of roster: CombatRoster<Stats>) -> BattleOutcome? {
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
