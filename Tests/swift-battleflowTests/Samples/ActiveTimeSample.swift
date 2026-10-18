@testable import swift_battleflow

// MARK: - Active-Time Sample Rule Set
//
// A sample game in which gauges fill over time and combatants act when their
// gauge is full. Its stats, commands, and formulas differ from the
// round-based sample on purpose; the library knows none of them.

extension BattleGroupID {
  static let allies = BattleGroupID("sample.allies")
  static let foes = BattleGroupID("sample.foes")
}

extension BattleOutcome {
  static let alliesWin = BattleOutcome("sample.allies_win")
  static let alliesLose = BattleOutcome("sample.allies_lose")
}

enum SampleElement: Sendable, Hashable {
  case fire
  case ice
}

struct ActiveTimeSampleStats: CombatantStats {
  var hp: Int
  var maxHP: Int
  var mp: Int
  var strength: Int
  var magic: Int
  var defense: Int
  var magicDefense: Int
  var speed: Int
  var weaknesses: Set<SampleElement> = []

  var canAct: Bool { hp > 0 }
}

enum SampleSpell: Sendable, Equatable {
  case flame
  case frost
  case cure

  var cost: Int {
    switch self {
    case .flame, .frost: 4
    case .cure: 5
    }
  }

  var element: SampleElement? {
    switch self {
    case .flame: .fire
    case .frost: .ice
    case .cure: nil
    }
  }
}

enum SampleTarget: Sendable, Equatable {
  case single(CombatantID)
  case allFoes
}

enum ActiveTimeSampleCommand: Sendable, Equatable {
  case attack(CombatantID)
  case cast(SampleSpell, on: SampleTarget)
}

enum ActiveTimeSampleEffect: Sendable, Equatable {
  case damage(CombatantID, amount: Int, isWeakness: Bool)
  case heal(CombatantID, amount: Int)
  case spendMP(CombatantID, amount: Int)
  case notEnoughMP
}

/// The sample's calculations, shared by every rule set that uses its stats,
/// commands, and effects.
enum SpellSampleMechanics {
  typealias Stats = ActiveTimeSampleStats
  typealias Command = ActiveTimeSampleCommand
  typealias Effect = ActiveTimeSampleEffect

  static func resolve<Generator: BattleRandomGenerator>(
    _ command: Command, by actor: CombatantID, in roster: CombatRoster<Stats>,
    random: inout Generator
  ) -> [Effect] {
    let caster = roster[actor]!
    switch command {
    case .attack(let target):
      guard let defender = roster[target], defender.canAct else { return [] }
      // Physical: strength * 2 - defense, varied by 0.9 ..< 1.1.
      let base = max(1, caster.strength * 2 - defender.defense)
      let amount = Int((Double(base) * (0.9 + random.nextRoll() / 5)).rounded())
      return [.damage(target, amount: amount, isWeakness: false)]

    case .cast(let spell, let target):
      guard caster.mp >= spell.cost else { return [.notEnoughMP] }
      let targets = targets(of: target, by: actor, in: roster)
      // Spreading a spell over several targets halves its power.
      let spread = targets.count > 1 ? 0.5 : 1.0
      var effects: [Effect] = [.spendMP(actor, amount: spell.cost)]
      for id in targets {
        let defender = roster[id]!
        if let element = spell.element {
          let isWeakness = defender.weaknesses.contains(element)
          let base = max(1, caster.magic * 3 - defender.magicDefense)
          let amount = Int(Double(base) * spread * (isWeakness ? 2 : 1))
          effects.append(.damage(id, amount: amount, isWeakness: isWeakness))
        } else {
          effects.append(.heal(id, amount: Int(Double(caster.magic * 2) * spread)))
        }
      }
      return effects
    }
  }

  private static func targets(
    of target: SampleTarget, by actor: CombatantID, in roster: CombatRoster<Stats>
  ) -> [CombatantID] {
    switch target {
    case .single(let id):
      return roster[id]?.canAct == true ? [id] : []
    case .allFoes:
      let foes: BattleGroupID = roster.side(of: actor) == .allies ? .foes : .allies
      return roster.members(of: foes).filter { roster[$0]!.canAct }.sorted { $0.value < $1.value }
    }
  }

  static func apply(_ effect: Effect, to roster: inout CombatRoster<Stats>) {
    switch effect {
    case .damage(let id, let amount, _):
      roster.update(id) { $0.hp = max(0, $0.hp - amount) }
    case .heal(let id, let amount):
      roster.update(id) { $0.hp = min($0.maxHP, $0.hp + amount) }
    case .spendMP(let id, let amount):
      roster.update(id) { $0.mp -= amount }
    case .notEnoughMP:
      break
    }
  }

  static func outcome(of roster: CombatRoster<Stats>) -> BattleOutcome? {
    if roster.members(of: .foes).allSatisfy({ !roster[$0]!.canAct }) { return .alliesWin }
    if roster.members(of: .allies).allSatisfy({ !roster[$0]!.canAct }) { return .alliesLose }
    return nil
  }
}

struct ActiveTimeSampleRules<Generator: BattleRandomGenerator>: ActiveTimeRules {
  typealias Stats = ActiveTimeSampleStats
  typealias Command = ActiveTimeSampleCommand
  typealias Effect = ActiveTimeSampleEffect
  typealias Turns = ActiveTimeTurns<Self>

  var mode: ActiveTimeMode = .active

  /// The sides whose combatants the game controls.
  var automaticSides: Set<BattleGroupID> = []

  /// Computer-controlled combatants attack the living opponent with the
  /// lowest HP.
  func automaticCommand(
    for actor: CombatantID, in state: CombatState<Self>, random: inout Generator
  ) -> Command? {
    let roster = state.roster
    guard let side = roster.side(of: actor), automaticSides.contains(side) else { return nil }
    let opponents: BattleGroupID = side == .allies ? .foes : .allies
    let target = roster.members(of: opponents).filter { roster[$0]!.canAct }
      .min { (roster[$0]!.hp, $0.value) < (roster[$1]!.hp, $1.value) }
    return target.map { .attack($0) }
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

  /// A speed of 50 fills the gauge in two seconds.
  func gaugeRate(of actor: CombatantID, in roster: CombatRoster<Stats>) -> Double {
    Double(roster[actor]!.speed) / 100
  }
}
