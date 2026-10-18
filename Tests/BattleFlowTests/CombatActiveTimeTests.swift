import Testing

@testable import BattleFlow

private typealias Rules = ActiveTimeSampleRules<ScriptedBattleRandomGenerator>

private let knight = CombatantID("knight")
private let mage = CombatantID("mage")
private let wolf = CombatantID("wolf")
private let bat = CombatantID("bat")

private func stats(
  hp: Int = 50, mp: Int = 20, strength: Int = 10, magic: Int = 10, defense: Int = 5,
  magicDefense: Int = 5, speed: Int = 50, weaknesses: Set<SampleElement> = []
) -> ActiveTimeSampleStats {
  ActiveTimeSampleStats(
    hp: hp, maxHP: 50, mp: mp, strength: strength, magic: magic, defense: defense,
    magicDefense: magicDefense, speed: speed, weaknesses: weaknesses)
}

private func roster(
  knight knightStats: ActiveTimeSampleStats = stats(speed: 50),
  mage mageStats: ActiveTimeSampleStats = stats(speed: 25),
  wolf wolfStats: ActiveTimeSampleStats = stats(speed: 40, weaknesses: [.fire]),
  bat batStats: ActiveTimeSampleStats = stats(hp: 10, speed: 100)
) -> CombatRoster<ActiveTimeSampleStats> {
  CombatRoster(sides: [
    .allies: [knight: knightStats, mage: mageStats],
    .foes: [wolf: wolfStats, bat: batStats],
  ])
}

private func started(
  _ roster: CombatRoster<ActiveTimeSampleStats> = roster(), rolls: [Double] = [],
  rules: Rules = Rules()
) -> CombatState<Rules> {
  CombatReducer(rules: rules).reduce(
    state: CombatState(random: ScriptedBattleRandomGenerator(rolls)), action: .start(roster)
  ).state
}

private func reduce(
  _ state: CombatState<Rules>, _ actions: CombatAction<Rules>..., rules: Rules = Rules()
) -> CombatState<Rules> {
  actions.reduce(state) { CombatReducer(rules: rules).reduce(state: $0, action: $1).state }
}

@Suite("Combat layer with active-time turns")
struct CombatActiveTimeTests {
  @Suite("Gauges")
  struct Gauges {
    @Test("Gauges start empty and fill over time at the rules' rate")
    func gaugesFill() {
      let state = started()
      #expect(state.awaitingCommand.isEmpty)
      #expect(state.turns.gauges[knight] == 0)

      let later = reduce(state, .advanceTime(by: 0.5))

      #expect(later.turns.gauges[knight] == 0.25)
      #expect(later.turns.gauges[mage] == 0.125)
      #expect(later.turns.gauges[bat] == 0.5)
    }

    @Test("A full gauge waits for a command; simultaneous fills are ordered by fill time")
    func readyOrder() {
      // After 2.5 s: bat filled at 1 s, knight at 2 s, wolf at 2.5 s; mage is halfway.
      let state = reduce(started(), .advanceTime(by: 2.5))

      #expect(state.turns.ready == [bat, knight, wolf])
      #expect(state.awaitingCommand == [bat, knight, wolf])
      #expect(state.turns.gauges[mage] == 0.625)
    }

    @Test("Commands are accepted only from combatants whose gauge is full")
    func submitRequiresFullGauge() {
      let state = reduce(started(), .advanceTime(by: 1))

      #expect(reduce(state, .submit(.attack(wolf), by: knight)) == state)

      let submitted = reduce(state, .submit(.attack(knight), by: bat))
      #expect(submitted.awaitingCommand.isEmpty)
      #expect(submitted.turns.pending == [.init(actor: bat, command: .attack(knight))])
    }

    @Test("Submitted commands run first come, first served, and reset the actor's gauge")
    func firstComeFirstServed() {
      // Knight and bat are ready; the knight submits first.
      let ready = reduce(started(rolls: [0.5, 0.5]), .advanceTime(by: 2))
      let state = reduce(
        ready, .submit(.attack(wolf), by: knight), .submit(.attack(mage), by: bat))

      let first = reduce(state, .performNextAction)
      #expect(first.currentActor == knight)
      // Physical: 10 * 2 - 5 = 15, variance roll 0.5 -> x1.0.
      #expect(first.roster[wolf]?.hp == 35)
      #expect(first.turns.gauges[knight] == 0)

      let second = reduce(first, .performNextAction)
      #expect(second.currentActor == bat)
      #expect(second.roster[mage]?.hp == 35)
    }

    @Test("Performing with nothing submitted changes nothing")
    func performWithoutPending() {
      let state = reduce(started(), .advanceTime(by: 2))
      #expect(reduce(state, .performNextAction) == state)
    }

    @Test("Gauges keep filling while combatants are ready in active mode, but stop in wait mode")
    func activeAndWaitModes() {
      let activeState = reduce(started(), .advanceTime(by: 1), .advanceTime(by: 1))
      #expect(activeState.turns.gauges[knight] == 1)

      let wait = Rules(mode: .wait)
      let waitState = reduce(
        started(rules: wait), .advanceTime(by: 1), .advanceTime(by: 1), rules: wait)
      // The bat filled at 1 s and has not submitted, so time stopped.
      #expect(waitState.turns.gauges[knight] == 0.5)

      let resumed = reduce(
        waitState, .submit(.attack(knight), by: .init("bat")), .advanceTime(by: 1), rules: wait)
      #expect(resumed.turns.gauges[knight] == 1)
    }

    @Test("A combatant that can no longer act stops filling and its pending command is skipped")
    func defeatedCombatant() {
      // The knight's command is first in line and knocks out the bat (10 HP)
      // before the bat's own command runs.
      let state = reduce(
        started(rolls: [0.5]),
        .advanceTime(by: 2), .submit(.attack(bat), by: knight), .submit(.attack(mage), by: bat))

      let afterKnight = reduce(state, .performNextAction)
      #expect(afterKnight.roster[bat]?.hp == 0)

      let batTurn = CombatReducer(rules: Rules()).reduce(
        state: afterKnight, action: .performNextAction)
      #expect(
        batTurn.commands.contains { ($0 as? CombatEvent<Rules>) == .skipped(actor: bat) })

      let later = reduce(batTurn.state, .advanceTime(by: 5))
      #expect(later.turns.gauges[bat] == 0)
      #expect(!later.awaitingCommand.contains(bat))
    }
  }

  @Suite("Sample formulas")
  struct SampleFormulas {
    @Test("Spells use magic, double on weaknesses, and halve when spread")
    func spellFormulas() {
      let ready = reduce(started(), .advanceTime(by: 4))  // everyone is ready

      let single = reduce(
        ready, .submit(.cast(.flame, on: .single(wolf)), by: mage), .performNextAction)
      // 10 * 3 - 5 = 25, doubled for the wolf's fire weakness.
      #expect(single.roster[wolf]?.hp == 0)
      #expect(single.roster[mage]?.mp == 16)

      let spread = reduce(ready, .submit(.cast(.frost, on: .allFoes), by: mage), .performNextAction)
      // 25 halved over two targets; no ice weakness.
      #expect(spread.roster[wolf]?.hp == 38)
      #expect(spread.roster[bat]?.hp == 0)
    }

    @Test("A spell without enough MP fails without changing anyone")
    func notEnoughMP() {
      let ready = reduce(started(roster(mage: stats(mp: 3, speed: 25))), .advanceTime(by: 4))

      let reduction = CombatReducer(rules: Rules()).reduce(
        state: reduce(ready, .submit(.cast(.flame, on: .single(wolf)), by: mage)),
        action: .performNextAction)

      #expect(reduction.state.roster[wolf] == ready.roster[wolf])
      #expect(
        reduction.commands.contains {
          ($0 as? CombatEvent<Rules>)
            == .performed(
              actor: mage, command: .cast(.flame, on: .single(wolf)), effects: [.notEnoughMP])
        })
    }

    @Test("Defeating every foe wins the battle")
    func activeTimeOutcome() {
      let ready = reduce(
        started(roster(wolf: stats(hp: 1, speed: 40, weaknesses: [.fire]))), .advanceTime(by: 4))

      let won = reduce(ready, .submit(.cast(.flame, on: .allFoes), by: mage), .performNextAction)

      #expect(won.outcome == .alliesWin)
      #expect(reduce(won, .advanceTime(by: 1)) == won)
    }

  }

  @Suite("Store")
  struct StoreUsage {
    @Test("A combat store lets time pass")
    @MainActor
    func storeAdvancesTime() {
      let store = CombatStore(
        initialState: CombatState(random: ScriptedBattleRandomGenerator([])), rules: Rules())

      store.start(roster())
      store.advanceTime(by: 1)

      #expect(store.state.awaitingCommand == [bat])
    }

    @Test("Time cannot go backwards")
    func negativeTime() async {
      await #expect(processExitsWith: .failure) {
        let state = CombatState<ActiveTimeSampleRules<ScriptedBattleRandomGenerator>>(
          random: ScriptedBattleRandomGenerator([]))
        _ = CombatReducer(rules: ActiveTimeSampleRules()).reduce(
          state: state, action: .advanceTime(by: -1))
      }
    }
  }
}
