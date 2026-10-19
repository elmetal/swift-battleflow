import Testing

@testable import BattleFlow

private typealias Rules = RoundSampleRules<ScriptedBattleRandomGenerator>

private let hero = CombatantID("hero")
private let cleric = CombatantID("cleric")
private let slime = CombatantID("slime")
private let golem = CombatantID("golem")

private func stats(hp: Int = 30, attack: Int = 20, defense: Int = 8, agility: Int = 10)
  -> RoundSampleStats
{
  RoundSampleStats(hp: hp, maxHP: 30, attack: attack, defense: defense, agility: agility)
}

private func roster(
  hero heroStats: RoundSampleStats = stats(agility: 20),
  slime slimeStats: RoundSampleStats = stats(hp: 12, agility: 5),
  golem golemStats: RoundSampleStats = stats(hp: 40, defense: 40, agility: 1)
) -> CombatRoster<RoundSampleStats> {
  CombatRoster(sides: [
    .party: [hero: heroStats, cleric: stats(agility: 8)],
    .monsters: [slime: slimeStats, golem: golemStats],
  ])
}

private func started(
  _ roster: CombatRoster<RoundSampleStats> = roster(), rolls: [Double] = [], rules: Rules = Rules()
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

// Initiative rolls are drawn per actor in ID order: cleric, golem, hero, slime.
private let evenInitiative: [Double] = [0.5, 0.5, 0.5, 0.5]

/// Everyone submits; returns the state with the round scheduled.
private func scheduled(
  hero heroCommand: RoundSampleCommand = .attack(slime),
  cleric clericCommand: RoundSampleCommand = .attack(golem),
  slime slimeCommand: RoundSampleCommand = .attack(hero),
  golem golemCommand: RoundSampleCommand = .attack(cleric),
  roster: CombatRoster<RoundSampleStats> = roster(),
  rolls: [Double]
) -> CombatState<Rules> {
  reduce(
    started(roster, rolls: rolls),
    .submit(heroCommand, by: hero),
    .submit(clericCommand, by: cleric),
    .submit(slimeCommand, by: slime),
    .submit(golemCommand, by: golem))
}

@Suite("Combat layer with round-based turns")
struct CombatRoundBasedTests {
  @Suite("Roster")
  struct Roster {
    @Test("A roster groups game-defined stats by side")
    func groupsStatsBySide() {
      let roster = roster()

      #expect(roster.members(of: .party) == [hero, cleric])
      #expect(roster.side(of: slime) == .monsters)
      #expect(roster[golem]?.defense == 40)
      #expect(roster.actors == [hero, cleric, slime, golem])
    }

    @Test("A roster rejects IDs that appear on more than one side")
    func rosterRejectsSharedIDs() async {
      await #expect(processExitsWith: .failure) {
        let stats = RoundSampleStats(hp: 1, maxHP: 1, attack: 1, defense: 1, agility: 1)
        let id = CombatantID("twin")
        _ = CombatRoster(sides: [.party: [id: stats], .monsters: [id: stats]])
      }
    }
  }

  @Suite("Starting and selecting")
  struct StartingAndSelecting {
    @Test("Starting a battle awaits a command from everyone who can act")
    func startAwaitsEveryoneWhoCanAct() {
      let downed = roster(slime: stats(hp: 0))
      let reduction = CombatReducer(rules: Rules()).reduce(
        state: CombatState(random: ScriptedBattleRandomGenerator([])), action: .start(downed))

      #expect(reduction.state.isEnded == false)
      #expect(reduction.state.phase == .ongoing)
      #expect(reduction.state.awaitingCommand == [hero, cleric, golem])
      #expect(reduction.state.turns.round == 1)
      #expect(reduction.outputs.contains(.started))
    }

    @Test(
      "Commands are ignored unless the combatant is awaiting one",
      arguments: ["unknown", "cannot act", "already scheduled"])
    func submitPreconditions(scenario: String) {
      var state = started(roster(slime: stats(hp: 0)), rolls: evenInitiative)
      var actor = hero
      switch scenario {
      case "unknown":
        actor = CombatantID("ghost")
      case "cannot act":
        actor = slime
      default:
        state = reduce(
          state, .submit(.attack(slime), by: hero), .submit(.attack(golem), by: cleric),
          .submit(.attack(hero), by: golem))
      }

      let reduction = CombatReducer(rules: Rules()).reduce(
        state: state, action: .submit(.attack(golem), by: actor))

      #expect(reduction.state == state)
    }

    @Test("Once everyone has submitted, the round is ordered by priority, then initiative")
    func roundOrder() {
      // Initiative = agility * (0.5 + roll / 2), rolls in ID order: cleric, golem, hero, slime.
      let state = scheduled(
        cleric: .heal(hero, amount: 5), rolls: [0.0, 0.5, 0.0, 1.0 - 1e-9])

      #expect(state.awaitingCommand.isEmpty)
      // The heal goes first; then hero (agility 20 * 0.5 = 10) and slime (5 * ~1 = 5)
      // and golem (1 * 0.75).
      #expect(state.turns.order == [cleric, hero, slime, golem])
    }

    @Test("Ties in priority and initiative are broken by ID")
    func roundOrderTie() {
      let tied = roster(hero: stats(agility: 5), slime: stats(hp: 12, agility: 5))
      let state = scheduled(roster: tied, rolls: [0.5, 0.5, 0.5, 0.5])

      // Cleric 8 * 0.75 = 6, hero and slime 5 * 0.75 = 3.75 (tie), golem 1 * 0.75.
      #expect(state.turns.order == [cleric, hero, slime, golem])
    }

  }

  @Suite("Withdrawing")
  struct Withdrawing {
    @Test("A submitted command can be withdrawn while others are still choosing")
    func withdrawAwaitsAgain() {
      let submitted = reduce(started(rolls: evenInitiative), .submit(.attack(slime), by: hero))
      #expect(submitted.withdrawableCommands == [hero])

      let withdrawn = reduce(submitted, .withdraw(by: hero))

      #expect(withdrawn.turns.commands[hero] == nil)
      #expect(withdrawn.awaitingCommand == [hero, cleric, slime, golem])
      #expect(withdrawn.withdrawableCommands.isEmpty)
    }

    @Test("A withdrawn command is replaced by the next submission")
    func resubmitReplaces() {
      let state = reduce(
        started(rolls: evenInitiative),
        .submit(.attack(slime), by: hero),
        .withdraw(by: hero),
        .submit(.attack(golem), by: hero),
        .submit(.attack(golem), by: cleric),
        .submit(.attack(hero), by: slime),
        .submit(.attack(cleric), by: golem))

      #expect(state.turns.isExecuting)
      #expect(state.turns.commands[hero] == .attack(golem))
    }

    @Test(
      "Withdrawing is ignored unless the combatant has a command to withdraw",
      arguments: ["not submitted", "unknown", "executing"])
    func withdrawPreconditions(scenario: String) {
      var state = reduce(started(rolls: evenInitiative), .submit(.attack(slime), by: hero))
      var actor = cleric
      switch scenario {
      case "unknown":
        actor = CombatantID("ghost")
      case "executing":
        state = scheduled(rolls: evenInitiative)
        actor = hero
      default:
        break
      }

      #expect(reduce(state, .withdraw(by: actor)) == state)
    }

    @Test("Withdrawing is ignored before the battle starts and after it ends")
    func withdrawRequiresOngoingBattle() {
      let preparation = CombatState<Rules>(random: ScriptedBattleRandomGenerator([]))
      let ended = reduce(
        started(rolls: evenInitiative), .submit(.attack(slime), by: hero), .end(.partyLoses))

      #expect(preparation.withdrawableCommands.isEmpty)
      #expect(ended.withdrawableCommands.isEmpty)
      #expect(reduce(ended, .withdraw(by: hero)) == ended)
    }

    @Test("A computer-controlled combatant whose command is withdrawn chooses again")
    func automaticCombatantChoosesAgain() {
      // Opponents of the slime in ID order: cleric, hero.
      let rules = Rules(automaticSides: [.monsters])
      let state = reduce(
        started(rolls: [0.9, 0.9, 0.1], rules: rules), .withdraw(by: slime), rules: rules)

      #expect(state.turns.commands[slime] == .attack(cleric))
      #expect(state.awaitingCommand == [hero, cleric])
    }
  }

  @Suite("Performing")
  struct Performing {
    @Test("Performing resolves the command through the game's rules")
    func performAppliesGameFormula() {
      // Hero: no critical (0.9), variance roll 0.5 -> x1.0; 20 / 2 - 8 / 4 = 8 damage.
      let state = scheduled(rolls: evenInitiative + [0.9, 0.5])

      let reduction = CombatReducer(rules: Rules()).reduce(state: state, action: .performNextAction)

      #expect(reduction.state.currentActor == hero)
      #expect(reduction.state.roster[slime]?.hp == 4)
      #expect(
        reduction.outputs.contains(
          .performed(
            actor: hero, command: .attack(slime),
            effects: [.damage(slime, amount: 8, isCritical: false)])))
    }

    @Test("Damage varies with the variance roll")
    func damageVariance() {
      let low = reduce(scheduled(rolls: evenInitiative + [0.9, 0.0]), .performNextAction)
      let high = reduce(scheduled(rolls: evenInitiative + [0.9, 1.0 - 1e-9]), .performNextAction)

      #expect(low.roster[slime]?.hp == 12 - 7)  // 8 * 7/8 = 7
      #expect(high.roster[slime]?.hp == 12 - 9)  // 8 * ~9/8 = 9
    }

    @Test("A critical hit ignores defense")
    func criticalIgnoresDefense() {
      // Cleric hits the golem (defense 40): normally 20 / 2 - 40 / 4 = 0 -> 1.
      // The cleric acts first (cleric initiative roll 0.99, hero agility 1), and
      // its rolls are critical, then variance.
      let initiative = [0.99, 0.5, 0.5, 0.5]
      let weakHero = roster(hero: stats(agility: 1))
      let normal = reduce(
        scheduled(cleric: .attack(golem), roster: weakHero, rolls: initiative + [0.9, 0.5]),
        .performNextAction)
      let critical = reduce(
        scheduled(cleric: .attack(golem), roster: weakHero, rolls: initiative + [0.01, 0.5]),
        .performNextAction)

      #expect(normal.currentActor == cleric)
      #expect(normal.roster[golem]?.hp == 39)
      #expect(critical.roster[golem]?.hp == 20)
    }

    @Test("Group attacks pick a living member with a roll")
    func groupTargeting() {
      // Living monsters in ID order: golem, slime. A roll of 0.75 picks slime.
      let state = reduce(
        scheduled(hero: .attackGroup(.monsters), rolls: evenInitiative + [0.75, 0.9, 0.5]),
        .performNextAction)

      #expect(state.roster[slime]?.hp == 4)
      #expect(state.roster[golem]?.hp == 40)
    }

    @Test("A combatant that can no longer act is skipped without drawing rolls")
    func skipDefeatedActor() {
      // Order: hero, cleric, slime, golem. The hero knocks out the slime with a
      // critical hit (0.01), the cleric attacks the golem, then the slime's turn
      // is skipped.
      let state = reduce(
        scheduled(rolls: evenInitiative + [0.01, 0.5, 0.9, 0.5, 0.42]),
        .performNextAction, .performNextAction)
      #expect(state.roster[slime]?.hp == 0)

      let reduction = CombatReducer(rules: Rules()).reduce(state: state, action: .performNextAction)

      #expect(reduction.state.currentActor == slime)
      #expect(reduction.state.random.remainingRolls == [0.42])
      #expect(reduction.outputs.contains(.skipped(actor: slime)))
    }

    @Test("After the last action the next round awaits commands again")
    func nextRound() {
      let weak = roster(golem: stats(hp: 40, attack: 1, defense: 40, agility: 1))
      var state = scheduled(
        hero: .attack(golem), slime: .heal(slime, amount: 1), roster: weak,
        rolls: evenInitiative + Array(repeating: 0.9, count: 6))
      for _ in 0..<4 { state = reduce(state, .performNextAction) }
      #expect(state.awaitingCommand.isEmpty)

      let next = reduce(state, .performNextAction)

      #expect(next.turns.round == 2)
      #expect(next.awaitingCommand == [hero, cleric, slime, golem])
    }

  }

  @Suite("Outcome")
  struct Outcome {
    @Test("The battle ends when the game's outcome rule decides it")
    func outcomeEndsBattle() {
      // The golem is already down; the hero's critical hit (0.01) knocks out the slime.
      // Initiative rolls in ID order of those who can act: cleric, hero, slime.
      let ready = reduce(
        started(roster(golem: stats(hp: 0)), rolls: [0.5, 0.5, 0.5, 0.01, 0.5]),
        .submit(.attack(slime), by: hero),
        .submit(.attack(slime), by: cleric),
        .submit(.attack(hero), by: slime))

      let reduction = CombatReducer(rules: Rules()).reduce(state: ready, action: .performNextAction)

      #expect(reduction.state.outcome == .partyWins)
      #expect(reduction.outputs.contains(.ended(.partyWins)))
      #expect(reduce(reduction.state, .performNextAction) == reduction.state)
    }

    @Test("A battle can be ended explicitly, and time does not affect round-based turns")
    func endAndAdvanceTime() {
      let state = started(rolls: [])

      #expect(reduce(state, .advanceTime(by: 10)) == state)
      #expect(reduce(state, .end(.partyLoses)).outcome == .partyLoses)
    }

  }

  @Suite("Store")
  struct StoreUsage {
    @Test("A combat store drives a round")
    @MainActor
    func combatStore() {
      let store = CombatStore(
        initialState: CombatState(
          random: ScriptedBattleRandomGenerator(evenInitiative + [0.9, 0.5])),
        rules: Rules())

      store.start(roster())
      store.submit(.attack(slime), by: hero)
      store.submit(.attack(golem), by: cleric)
      store.submit(.attack(cleric), by: slime)
      store.withdraw(by: slime)
      store.submit(.attack(hero), by: slime)
      store.submit(.attack(cleric), by: golem)
      store.performNextAction()

      #expect(store.state.roster[slime]?.hp == 4)
      #expect(store.state.turns.commands[slime] == .attack(hero))
      #expect(store.actionHistory.count == 8)
    }
  }
}
