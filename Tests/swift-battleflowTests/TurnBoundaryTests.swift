import Testing

@testable import swift_battleflow

// MARK: - Turn Boundaries with a Status Ailment Sample

private typealias Rules = StatusSampleRules<ScriptedBattleRandomGenerator>
private typealias Event = CombatEvent<Rules>

private let hero = CombatantID("hero")
private let witch = CombatantID("witch")
private let slime = CombatantID("slime")

private func roster(slimeHP: Int = 30) -> CombatRoster<StatusSampleStats> {
  CombatRoster(sides: [
    .party: [
      hero: StatusSampleStats(hp: 30, attack: 5, agility: 20),
      witch: StatusSampleStats(hp: 30, attack: 1, agility: 10),
    ],
    .monsters: [slime: StatusSampleStats(hp: slimeHP, attack: 3, agility: 1)],
  ])
}

private func reduce(_ state: CombatState<Rules>, _ action: CombatAction<Rules>)
  -> Reduction<CombatState<Rules>, CombatAction<Rules>>
{
  CombatReducer(rules: Rules()).reduce(state: state, action: action)
}

private func reduce(_ state: CombatState<Rules>, _ actions: [CombatAction<Rules>])
  -> CombatState<Rules>
{
  actions.reduce(state) { reduce($0, $1).state }
}

private func started(_ roster: CombatRoster<StatusSampleStats> = roster()) -> CombatState<Rules> {
  reduce(CombatState(random: ScriptedBattleRandomGenerator([])), .start(roster)).state
}

private func round(
  hero heroCommand: StatusSampleCommand, witch witchCommand: StatusSampleCommand,
  slime slimeCommand: StatusSampleCommand = .attack(hero)
) -> [CombatAction<Rules>] {
  [
    .submit(heroCommand, by: hero), .submit(witchCommand, by: witch),
    .submit(slimeCommand, by: slime),
  ]
}

private func events(_ reduction: Reduction<CombatState<Rules>, CombatAction<Rules>>) -> [Event] {
  reduction.commands.compactMap { $0 as? Event }
}

// MARK: Order

@Test("Starting a round-based battle reaches the first round's start")
func testRoundStartsOnStart() async throws {
  let reduction = reduce(CombatState(random: ScriptedBattleRandomGenerator([])), .start(roster()))

  #expect(events(reduction) == [.started, .boundary(.roundStarted(1), effects: [])])
}

@Test("Each action is wrapped in its actor's turn start and turn end")
func testTurnBoundariesWrapActions() async throws {
  let state = reduce(started(), round(hero: .attack(slime), witch: .attack(slime)))

  #expect(
    events(reduce(state, .performNextAction)) == [
      .boundary(.turnStarted(hero), effects: []),
      .performed(actor: hero, command: .attack(slime), effects: [.damage(slime, amount: 5)]),
      .boundary(.turnEnded(hero), effects: []),
    ])
}

@Test("After the last action, the round ends and the next one starts")
func testRoundBoundaries() async throws {
  let state = reduce(
    started(),
    round(hero: .attack(slime), witch: .attack(slime))
      + Array(repeating: .performNextAction, count: 3))

  #expect(
    events(reduce(state, .performNextAction)) == [
      .boundary(.roundEnded(1), effects: []), .boundary(.roundStarted(2), effects: []),
    ])
}

// MARK: Status Ailments

@Test("Poison hurts at the end of the poisoned combatant's turn")
func testPoison() async throws {
  // The witch poisons the slime, which then attacks and takes poison damage.
  let state = reduce(
    started(),
    round(hero: .attack(slime), witch: .poison(slime, perTurn: 4))
      + [.performNextAction, .performNextAction])

  let slimeTurn = reduce(state, .performNextAction)

  #expect(slimeTurn.state.roster[slime]?.hp == 30 - 5 - 4)
  #expect(
    events(slimeTurn).last == .boundary(.turnEnded(slime), effects: [.damage(slime, amount: 4)]))
}

@Test("Poison can decide the battle")
func testPoisonDecidesBattle() async throws {
  let state = reduce(
    started(roster(slimeHP: 9)),
    round(hero: .attack(slime), witch: .poison(slime, perTurn: 4))
      + [.performNextAction, .performNextAction])

  let slimeTurn = reduce(state, .performNextAction)

  #expect(slimeTurn.state.outcome == .partyWins)
  #expect(events(slimeTurn).last == .ended(.partyWins))
}

@Test("Sleep keeps a combatant from acting until it wears off at round end")
func testSleep() async throws {
  // Round 1: the witch puts the slime to sleep for 2 rounds before it acts.
  let afterRound1 = reduce(
    started(),
    round(hero: .attack(slime), witch: .lullaby(slime, rounds: 2))
      + Array(repeating: .performNextAction, count: 4))
  #expect(afterRound1.turns.round == 2)
  #expect(afterRound1.roster[slime]?.sleep == 1)
  #expect(afterRound1.awaitingCommand == [hero, witch])

  let afterRound2 = reduce(
    afterRound1,
    [.submit(.attack(slime), by: hero), .submit(.attack(slime), by: witch)]
      + Array(repeating: .performNextAction, count: 3))

  #expect(afterRound2.turns.round == 3)
  #expect(afterRound2.awaitingCommand == [hero, witch, slime])
}

@Test("A combatant that cannot act reaches its turn start but not its turn end")
func testSkippedTurnBoundaries() async throws {
  // The slime falls asleep during round 1 before its turn comes.
  let state = reduce(
    started(),
    round(hero: .attack(slime), witch: .lullaby(slime, rounds: 1))
      + [.performNextAction, .performNextAction])

  #expect(
    events(reduce(state, .performNextAction)) == [
      .boundary(.turnStarted(slime), effects: []), .skipped(actor: slime),
    ])
}

// MARK: Active-Time Boundaries

@Test("Active-time actions are wrapped in turn start and turn end")
func testActiveTimeBoundaries() async throws {
  typealias GaugeRules = ActiveTimeSampleRules<ScriptedBattleRandomGenerator>
  let stats = ActiveTimeSampleStats(
    hp: 50, maxHP: 50, mp: 0, strength: 10, magic: 0, defense: 5, magicDefense: 0, speed: 100)
  let knight = CombatantID("knight")
  let wolf = CombatantID("wolf")
  let reducer = CombatReducer(rules: GaugeRules())
  let ready = [
    CombatAction<GaugeRules>.start(
      CombatRoster(sides: [.allies: [knight: stats], .foes: [wolf: stats]])),
    .advanceTime(by: 1), .submit(.attack(wolf), by: knight),
  ].reduce(CombatState<GaugeRules>(random: ScriptedBattleRandomGenerator([0.5]))) {
    reducer.reduce(state: $0, action: $1).state
  }

  let events = reducer.reduce(state: ready, action: .performNextAction).commands
    .compactMap { $0 as? CombatEvent<GaugeRules> }

  #expect(
    events == [
      .boundary(.turnStarted(knight), effects: []),
      .performed(
        actor: knight, command: .attack(wolf),
        effects: [.damage(wolf, amount: 15, isWeakness: false)]),
      .boundary(.turnEnded(knight), effects: []),
    ])
}
