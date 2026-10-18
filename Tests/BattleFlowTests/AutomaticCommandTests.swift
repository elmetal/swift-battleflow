import Testing

@testable import BattleFlow

@Suite("Automatic commands for computer-controlled combatants")
struct AutomaticCommandTests {
  typealias RoundRules = RoundSampleRules<ScriptedBattleRandomGenerator>
  typealias GaugeRules = ActiveTimeSampleRules<ScriptedBattleRandomGenerator>

  @Suite("Round-based turns")
  struct RoundBased {
    let hero = CombatantID("hero")
    let cleric = CombatantID("cleric")
    let slime = CombatantID("slime")
    let golem = CombatantID("golem")

    func roster() -> CombatRoster<RoundSampleStats> {
      func stats(_ agility: Int) -> RoundSampleStats {
        RoundSampleStats(hp: 30, maxHP: 30, attack: 10, defense: 4, agility: agility)
      }
      return CombatRoster(sides: [
        .party: [hero: stats(20), cleric: stats(8)],
        .monsters: [slime: stats(5), golem: stats(1)],
      ])
    }

    func start(
      _ rules: RoundRules, rolls: [Double]
    ) -> Reduction<CombatState<RoundRules>, CombatAction<RoundRules>> {
      CombatReducer(rules: rules).reduce(
        state: CombatState(random: ScriptedBattleRandomGenerator(rolls)), action: .start(roster()))
    }

    @Test("Computer-controlled combatants submit as soon as they are awaited")
    func submitOnStart() {
      // Opponents in ID order: cleric, hero. Golem rolls 0.9 (hero), slime 0.1 (cleric).
      let reduction = start(RoundRules(automaticSides: [.monsters]), rolls: [0.9, 0.1])

      #expect(reduction.state.awaitingCommand == [hero, cleric])
      #expect(reduction.state.turns.commands == [golem: .attack(hero), slime: .attack(cleric)])
      #expect(
        Array(events(reduction).suffix(2)) == [
          .submittedAutomatically(actor: golem, command: .attack(hero)),
          .submittedAutomatically(actor: slime, command: .attack(cleric)),
        ])
    }

    @Test("Without automatic sides, everyone waits for a player")
    func noAutomaticSides() {
      let reduction = start(RoundRules(), rolls: [])

      #expect(reduction.state.awaitingCommand == [hero, cleric, slime, golem])
      #expect(reduction.state.random.remainingRolls.isEmpty)
    }

    @Test("Automatic commands are chosen again every round")
    func submitEachRound() {
      let rules = RoundRules(automaticSides: [.monsters])
      let reducer = CombatReducer(rules: rules)
      // Round 1: two AI picks, four initiative rolls, then four attacks (two rolls each).
      let rolls =
        [0.9, 0.9] + [0.5, 0.5, 0.5, 0.5] + Array(repeating: 0.9, count: 8) + [0.1, 0.1]
      let actions: [CombatAction<RoundRules>] =
        [.submit(.attack(slime), by: hero), .submit(.attack(slime), by: cleric)]
        + Array(repeating: .performNextAction, count: 4)
      let state = actions.reduce(start(rules, rolls: rolls).state) {
        reducer.reduce(state: $0, action: $1).state
      }
      #expect(state.turns.round == 1)

      let nextRound = reducer.reduce(state: state, action: .performNextAction)

      #expect(nextRound.state.turns.round == 2)
      #expect(nextRound.state.turns.commands == [golem: .attack(cleric), slime: .attack(cleric)])
      #expect(nextRound.state.awaitingCommand == [hero, cleric])
    }

    @Test("A battle of computer-controlled combatants schedules its rounds by itself")
    func autoBattle() {
      let reduction = start(
        RoundRules(automaticSides: [.party, .monsters]),
        rolls: [0.1, 0.1, 0.1, 0.1] + [0.5, 0.5, 0.5, 0.5])

      #expect(reduction.state.awaitingCommand.isEmpty)
      #expect(reduction.state.turns.isExecuting)
    }
  }

  @Suite("Active-time turns")
  struct ActiveTime {
    @Test("A computer-controlled combatant submits when its gauge fills")
    func submitOnFullGauge() {
      func stats(hp: Int, speed: Int) -> ActiveTimeSampleStats {
        ActiveTimeSampleStats(
          hp: hp, maxHP: 50, mp: 0, strength: 10, magic: 0, defense: 5, magicDefense: 0,
          speed: speed)
      }
      let knight = CombatantID("knight")
      let mage = CombatantID("mage")
      let wolf = CombatantID("wolf")
      let reducer = CombatReducer(rules: GaugeRules(automaticSides: [.foes]))
      let started = reducer.reduce(
        state: CombatState(random: ScriptedBattleRandomGenerator([])),
        action: .start(
          CombatRoster(sides: [
            .allies: [knight: stats(hp: 50, speed: 50), mage: stats(hp: 20, speed: 50)],
            .foes: [wolf: stats(hp: 50, speed: 100)],
          ]))
      ).state

      let reduction = reducer.reduce(state: started, action: .advanceTime(by: 1))

      // The wolf picks the ally with the lowest HP.
      #expect(reduction.state.turns.pending == [.init(actor: wolf, command: .attack(mage))])
      #expect(reduction.state.awaitingCommand.isEmpty)
      #expect(events(reduction) == [.submittedAutomatically(actor: wolf, command: .attack(mage))])
    }
  }

  @Suite("Contract")
  struct Contract {
    @Test("A turn system must stop awaiting a combatant once its command is recorded")
    func turnSystemMustStopAwaiting() async {
      await #expect(processExitsWith: .failure) {
        let reducer = CombatReducer(rules: StuckRules())
        _ = reducer.reduce(
          state: CombatState(random: ScriptedBattleRandomGenerator([])),
          action: .start(CombatRoster(sides: [.party: [CombatantID("a"): StuckStats()]])))
      }
    }
  }
}

private func events<R>(_ reduction: Reduction<CombatState<R>, CombatAction<R>>) -> [CombatEvent<R>]
{
  reduction.commands.compactMap { $0 as? CombatEvent<R> }
}

// MARK: - A Turn System That Breaks the Contract

private struct StuckStats: CombatantStats {
  var canAct: Bool { true }
}

/// Keeps awaiting every combatant, even after recording its command.
private struct StuckTurns: TurnSystem {
  typealias Rules = StuckRules

  func awaitingCommand(in roster: CombatRoster<StuckStats>) -> Set<CombatantID> {
    roster.actors
  }

  mutating func record(
    _ command: Int, by actor: CombatantID, in roster: CombatRoster<StuckStats>, rules: StuckRules,
    random: inout ScriptedBattleRandomGenerator
  ) {}

  mutating func takeNextAction(
    in roster: CombatRoster<StuckStats>, rules: StuckRules,
    random: inout ScriptedBattleRandomGenerator
  ) -> (actor: CombatantID, command: Int)? {
    nil
  }
}

private struct StuckRules: CombatRules {
  typealias Stats = StuckStats
  typealias Command = Int
  typealias Effect = Int
  typealias Generator = ScriptedBattleRandomGenerator
  typealias Turns = StuckTurns

  func automaticCommand(
    for actor: CombatantID, in state: CombatState<Self>, random: inout Generator
  ) -> Int? {
    0
  }

  func resolve(
    _ command: Int, by actor: CombatantID, in state: CombatState<Self>, random: inout Generator
  ) -> [Int] {
    []
  }

  func apply(_ effect: Int, to roster: inout CombatRoster<StuckStats>) {}

  func outcome(of roster: CombatRoster<StuckStats>) -> BattleOutcome? { nil }
}
