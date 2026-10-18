import BattleFlow
import Testing

// Mirrors the quick start in README.md; keep them in sync.

@Suite("README quick start")
struct QuickStartTests {
  struct Stats: CombatantStats {
    var hp: Int
    var attack: Int

    var canAct: Bool { hp > 0 }
  }

  enum Command: Sendable, Equatable {
    case attack(CombatantID)
  }

  enum Effect: Sendable, Equatable {
    case damage(CombatantID, amount: Int)
  }

  struct Rules<Generator: BattleRandomGenerator>: RoundBasedRules {
    typealias Stats = QuickStartTests.Stats
    typealias Command = QuickStartTests.Command
    typealias Effect = QuickStartTests.Effect
    typealias Turns = RoundBasedTurns<Self>

    func resolve(
      _ command: Command, by actor: CombatantID, in state: CombatState<Self>,
      random: inout Generator
    ) -> [Effect] {
      switch command {
      case .attack(let target):
        let variance = 0.9 + random.nextRoll() / 5  // 0.9 ..< 1.1
        let amount = Int(Double(state.roster[actor]!.attack) * variance)
        return [.damage(target, amount: amount)]
      }
    }

    func apply(_ effect: Effect, to roster: inout CombatRoster<Stats>) {
      switch effect {
      case .damage(let target, let amount):
        roster.update(target) { $0.hp = max(0, $0.hp - amount) }
      }
    }

    func outcome(of roster: CombatRoster<Stats>) -> BattleOutcome? {
      let enemiesDown = roster.members(of: .enemies).allSatisfy { !roster[$0]!.canAct }
      return enemiesDown ? BattleOutcome("victory") : nil
    }

    func priority(of command: Command) -> Int { 0 }

    func initiative(
      of actor: CombatantID, in roster: CombatRoster<Stats>, random: inout Generator
    ) -> Double {
      Double(roster[actor]!.attack)
    }
  }

  @Test("The quick start battle ends in victory")
  @MainActor
  func quickStart() async {
    let hero = CombatantID("hero")
    let slime = CombatantID("slime")

    let store = CombatStore(
      initialState: CombatState(random: SeededBattleRandomGenerator(seed: 42)),
      rules: Rules<SeededBattleRandomGenerator>())
    var log: [String] = []
    store.commandHandler = { event in log.append(event.id) }

    store.start(
      CombatRoster(sides: [
        .heroes: [hero: Stats(hp: 30, attack: 12)],
        .enemies: [slime: Stats(hp: 10, attack: 3)],
      ]))
    store.submit(.attack(slime), by: hero)
    store.submit(.attack(hero), by: slime)
    store.performNextAction()
    await store.waitForPendingCommands()

    #expect(store.state.outcome == BattleOutcome("victory"))
    #expect(log.contains("combat.ended.victory"))
  }
}

extension BattleGroupID {
  static let heroes = BattleGroupID("heroes")
  static let enemies = BattleGroupID("enemies")
}
