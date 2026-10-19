import Testing

@testable import BattleFlow

private let actor = CombatantID("a")

@Suite("Withdrawing commands")
struct WithdrawContractTests {
  @Test("A turn system must await a combatant again once its command is withdrawn")
  func turnSystemMustAwaitAgain() async {
    await #expect(processExitsWith: .failure) {
      let reducer = CombatReducer(rules: HoldingRules())
      let state = reducer.reduce(
        state: CombatState(random: ScriptedBattleRandomGenerator([])),
        action: .start(CombatRoster(sides: [.party: [actor: HoldingStats()]]))
      ).state
      _ = reducer.reduce(state: state, action: .withdraw(by: actor))
    }
  }

  @Test("Round-based turns reject withdrawing a command that was not submitted")
  func roundBasedRejectsUnsubmitted() async {
    await #expect(processExitsWith: .failure) {
      typealias Rules = RoundSampleRules<ScriptedBattleRandomGenerator>
      let stats = RoundSampleStats(hp: 1, maxHP: 1, attack: 1, defense: 1, agility: 1)
      let roster = CombatRoster(sides: [.party: [actor: stats]])
      var turns = RoundBasedTurns<Rules>()
      turns.begin(with: roster, rules: Rules())
      turns.withdrawCommand(of: actor, in: roster, rules: Rules())
    }
  }

  @Test("By default a turn system rejects withdrawing a command")
  func defaultRejectsWithdrawing() async {
    await #expect(processExitsWith: .failure) {
      let roster = CombatRoster(sides: [.party: [actor: HoldingStats()]])
      var turns = DefaultTurns()
      turns.withdrawCommand(of: actor, in: roster, rules: HoldingRules())
    }
  }
}

// MARK: - Turn Systems for the Contract

private struct HoldingStats: CombatantStats {
  var canAct: Bool { true }
}

/// Lets every combatant withdraw, but never awaits a command.
private struct HoldingTurns: TurnSystem {
  typealias Rules = HoldingRules

  func awaitingCommand(in roster: CombatRoster<HoldingStats>) -> Set<CombatantID> {
    []
  }

  mutating func record(
    _ command: Int, by actor: CombatantID, in roster: CombatRoster<HoldingStats>,
    rules: HoldingRules, random: inout ScriptedBattleRandomGenerator
  ) {}

  func withdrawableCommands(in roster: CombatRoster<HoldingStats>) -> Set<CombatantID> {
    roster.actors
  }

  mutating func withdrawCommand(
    of actor: CombatantID, in roster: CombatRoster<HoldingStats>, rules: HoldingRules
  ) {}

  mutating func takeNextAction(
    in roster: CombatRoster<HoldingStats>, rules: HoldingRules,
    random: inout ScriptedBattleRandomGenerator
  ) -> (actor: CombatantID, command: Int)? {
    nil
  }
}

/// Relies on the default withdrawing behavior.
private struct DefaultTurns: TurnSystem {
  typealias Rules = HoldingRules

  func awaitingCommand(in roster: CombatRoster<HoldingStats>) -> Set<CombatantID> {
    []
  }

  mutating func record(
    _ command: Int, by actor: CombatantID, in roster: CombatRoster<HoldingStats>,
    rules: HoldingRules, random: inout ScriptedBattleRandomGenerator
  ) {}

  mutating func takeNextAction(
    in roster: CombatRoster<HoldingStats>, rules: HoldingRules,
    random: inout ScriptedBattleRandomGenerator
  ) -> (actor: CombatantID, command: Int)? {
    nil
  }
}

private struct HoldingRules: CombatRules {
  typealias Stats = HoldingStats
  typealias Command = Int
  typealias Effect = Int
  typealias Generator = ScriptedBattleRandomGenerator
  typealias Turns = HoldingTurns

  func resolve(
    _ command: Int, by actor: CombatantID, in state: CombatState<Self>, random: inout Generator
  ) -> [Int] {
    []
  }

  func apply(_ effect: Int, to roster: inout CombatRoster<HoldingStats>) {}

  func outcome(of roster: CombatRoster<HoldingStats>) -> BattleOutcome? { nil }
}
