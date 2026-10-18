@testable import swift_battleflow

// MARK: - Round-Based Sample Rule Set
//
// A sample game built on the combat layer: everyone selects a command, then
// commands run by priority and a randomized initiative. Everything here is
// game-defined; the library knows none of these stats, commands, or formulas.

extension BattleGroupID {
  static let party = BattleGroupID("sample.party")
  static let monsters = BattleGroupID("sample.monsters")
}

extension BattleOutcome {
  static let partyWins = BattleOutcome("sample.party_wins")
  static let partyLoses = BattleOutcome("sample.party_loses")
}

struct RoundSampleStats: CombatantStats {
  var hp: Int
  var maxHP: Int
  var attack: Int
  var defense: Int
  var agility: Int

  var canAct: Bool { hp > 0 }
}

enum RoundSampleCommand: Sendable, Equatable {
  /// Attacks one combatant.
  case attack(CombatantID)
  /// Attacks a random living member of a group.
  case attackGroup(BattleGroupID)
  /// Restores HP; acts before attacks.
  case heal(CombatantID, amount: Int)
}

enum RoundSampleEffect: Sendable, Equatable {
  case damage(CombatantID, amount: Int, isCritical: Bool)
  case heal(CombatantID, amount: Int)
  case missed
}

struct RoundSampleRules<Generator: BattleRandomGenerator>: RoundBasedRules {
  typealias Stats = RoundSampleStats
  typealias Command = RoundSampleCommand
  typealias Effect = RoundSampleEffect
  typealias Turns = RoundBasedTurns<Self>

  /// The chance of a critical hit, which ignores defense.
  var criticalChance = 1.0 / 32

  /// The sides whose combatants the game controls.
  var automaticSides: Set<BattleGroupID> = []

  /// Computer-controlled combatants attack a random living opponent.
  func automaticCommand(
    for actor: CombatantID, in state: CombatState<Self>, random: inout Generator
  ) -> Command? {
    let roster = state.roster
    guard let side = roster.side(of: actor), automaticSides.contains(side) else { return nil }
    let opponents = roster.sides.keys.filter { $0 != side }
      .flatMap { roster.members(of: $0) }
      .filter { roster[$0]!.canAct }
      .sorted { $0.value < $1.value }
    guard !opponents.isEmpty else { return nil }
    return .attack(opponents[Int(random.nextRoll() * Double(opponents.count))])
  }

  func resolve(
    _ command: Command, by actor: CombatantID, in state: CombatState<Self>,
    random: inout Generator
  ) -> [Effect] {
    let roster = state.roster
    switch command {
    case .attack(let target):
      return attack(target, by: actor, in: roster, random: &random)
    case .attackGroup(let group):
      let living = roster.members(of: group).filter { roster[$0]!.canAct }.sorted {
        $0.value < $1.value
      }
      guard !living.isEmpty else { return [.missed] }
      let target = living[Int(random.nextRoll() * Double(living.count))]
      return attack(target, by: actor, in: roster, random: &random)
    case .heal(let target, let amount):
      guard roster[target]?.canAct == true else { return [.missed] }
      return [.heal(target, amount: amount)]
    }
  }

  /// Rolls are drawn in a fixed order: critical, then variance.
  private func attack(
    _ target: CombatantID, by actor: CombatantID, in roster: CombatRoster<Stats>,
    random: inout Generator
  ) -> [Effect] {
    guard let attacker = roster[actor], let defender = roster[target], defender.canAct else {
      return [.missed]
    }
    let isCritical = random.nextRoll() < criticalChance
    let base =
      isCritical
      ? Double(attacker.attack)
      : max(0, Double(attacker.attack) / 2 - Double(defender.defense) / 4)
    let variance = 0.875 + random.nextRoll() / 4  // 7/8 ..< 9/8
    let amount = max(1, Int((base * variance).rounded()))
    return [.damage(target, amount: amount, isCritical: isCritical)]
  }

  func apply(_ effect: Effect, to roster: inout CombatRoster<Stats>) {
    switch effect {
    case .damage(let target, let amount, _):
      roster.update(target) { $0.hp = max(0, $0.hp - amount) }
    case .heal(let target, let amount):
      roster.update(target) { $0.hp = min($0.maxHP, $0.hp + amount) }
    case .missed:
      break
    }
  }

  func outcome(of roster: CombatRoster<Stats>) -> BattleOutcome? {
    if roster.members(of: .monsters).allSatisfy({ !roster[$0]!.canAct }) { return .partyWins }
    if roster.members(of: .party).allSatisfy({ !roster[$0]!.canAct }) { return .partyLoses }
    return nil
  }

  func priority(of command: Command) -> Int {
    if case .heal = command { return 1 }
    return 0
  }

  /// Agility scaled by a roll in 0.5 ..< 1.
  func initiative(
    of actor: CombatantID, in roster: CombatRoster<Stats>, random: inout Generator
  ) -> Double {
    Double(roster[actor]!.agility) * (0.5 + random.nextRoll() / 2)
  }
}
