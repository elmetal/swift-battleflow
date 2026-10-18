import Testing

@testable import BattleFlow

@Suite("Changing combatants during a battle")
struct RosterChangeTests {
  typealias Rules = RosterChangeSampleRules<ScriptedBattleRandomGenerator>
  typealias Stats = RosterChangeSampleStats

  static let hero = CombatantID("hero")
  static let thief = CombatantID("thief")
  static let goblin = CombatantID("goblin")
  static let shaman = CombatantID("shaman")
  static let newcomer = CombatantID("newcomer")

  @Suite("Roster")
  struct Roster {
    func roster() -> CombatRoster<Stats> {
      CombatRoster(sides: [
        .party: [hero: Stats(hp: 30, attack: 5, agility: 10)],
        .monsters: [goblin: Stats(hp: 20, attack: 3, agility: 5)],
      ])
    }

    @Test("Combatants can be added to a side and removed")
    func addAndRemove() {
      var roster = roster()

      roster.add(newcomer, stats: Stats(hp: 10, attack: 2, agility: 3), to: .monsters)
      #expect(roster.members(of: .monsters) == [goblin, newcomer])
      #expect(roster[newcomer]?.hp == 10)

      roster.remove(goblin)
      #expect(roster.members(of: .monsters) == [newcomer])
      #expect(roster[goblin] == nil)
      #expect(roster.side(of: goblin) == nil)
    }

    @Test("Adding an ID that is already in the battle is rejected")
    func addDuplicate() async {
      await #expect(processExitsWith: .failure) {
        var roster = CombatRoster(sides: [
          .party: [CombatantID("hero"): RosterChangeSampleStats(hp: 1, attack: 1, agility: 1)]
        ])
        roster.add(
          CombatantID("hero"), stats: RosterChangeSampleStats(hp: 1, attack: 1, agility: 1),
          to: .monsters)
      }
    }

    @Test("Removing an ID that is not in the battle is rejected")
    func removeUnknown() async {
      await #expect(processExitsWith: .failure) {
        var roster = CombatRoster<RosterChangeSampleStats>(sides: [:])
        roster.remove(CombatantID("ghost"))
      }
    }
  }

  @Suite("Round-based battle")
  struct RoundBased {
    func reduce(_ state: CombatState<Rules>, _ actions: [CombatAction<Rules>]) -> CombatState<Rules>
    {
      actions.reduce(state) { CombatReducer(rules: Rules()).reduce(state: $0, action: $1).state }
    }

    /// Order by agility: hero (10), thief (8), goblin (5), shaman (4).
    func round(
      hero heroCommand: RosterChangeSampleCommand = .attack(goblin),
      thief thiefCommand: RosterChangeSampleCommand = .attack(goblin),
      goblin goblinCommand: RosterChangeSampleCommand = .attack(hero),
      shaman shamanCommand: RosterChangeSampleCommand = .attack(hero)
    ) -> CombatState<Rules> {
      let roster = CombatRoster(sides: [
        .party: [
          hero: Stats(hp: 30, attack: 5, agility: 10), thief: Stats(hp: 20, attack: 4, agility: 8),
        ],
        .monsters: [
          goblin: Stats(hp: 20, attack: 3, agility: 5),
          shaman: Stats(hp: 20, attack: 1, agility: 4),
        ],
      ])
      return reduce(
        CombatState(random: ScriptedBattleRandomGenerator([])),
        [
          .start(roster),
          .submit(heroCommand, by: hero), .submit(thiefCommand, by: thief),
          .submit(goblinCommand, by: goblin), .submit(shamanCommand, by: shaman),
        ])
    }

    @Test("A newcomer joins the engine state and acts from the next round")
    func newcomerJoinsNextRound() {
      let afterShaman = reduce(
        round(shaman: .callForHelp(newcomer)), Array(repeating: .performNextAction, count: 4))

      #expect(afterShaman.roster.side(of: newcomer) == .monsters)
      #expect(afterShaman.roster.members(of: .monsters).contains(newcomer))
      #expect(!afterShaman.turns.order.contains(newcomer))

      let nextRound = reduce(afterShaman, [.performNextAction])

      #expect(nextRound.awaitingCommand == [hero, thief, goblin, shaman, newcomer])
    }

    @Test("A combatant that leaves loses its place in the round without being skipped")
    func leavingDropsTurn() {
      // The hero banishes the goblin before the goblin's turn.
      let state = reduce(round(hero: .banish(goblin)), [.performNextAction])

      #expect(state.roster[goblin] == nil)
      #expect(!state.roster.members(of: .monsters).contains(goblin))
      #expect(state.turns.order == [thief, shaman])
      #expect(state.turns.commands[goblin] == nil)
    }

    @Test("A combatant that flees is no longer awaited")
    func fleeing() {
      let state = reduce(round(thief: .flee), Array(repeating: .performNextAction, count: 5))

      #expect(state.turns.round == 2)
      #expect(state.awaitingCommand == [hero, goblin, shaman])
    }

    @Test("When every party member flees, the game's outcome rule ends the battle")
    func everyoneFlees() {
      let state = reduce(
        round(hero: .flee, thief: .flee), [.performNextAction, .performNextAction])

      #expect(state.outcome == .partyEscaped)
    }
  }

  @Suite("Active-time battle")
  struct ActiveTime {
    typealias GaugeRules = ActiveTimeSampleRules<ScriptedBattleRandomGenerator>

    @Test("Newcomers get a gauge and removed combatants lose theirs")
    func gauges() {
      func stats(speed: Int) -> ActiveTimeSampleStats {
        ActiveTimeSampleStats(
          hp: 50, maxHP: 50, mp: 0, strength: 10, magic: 0, defense: 5, magicDefense: 0,
          speed: speed)
      }
      let knight = CombatantID("knight")
      let wolf = CombatantID("wolf")
      let spirit = CombatantID("spirit")
      var turns = ActiveTimeTurns<GaugeRules>()
      var roster = CombatRoster(sides: [
        .allies: [knight: stats(speed: 50)], .foes: [wolf: stats(speed: 100)],
      ])
      turns.begin(with: roster, rules: GaugeRules())
      turns.advanceTime(by: 1, in: roster, rules: GaugeRules())
      #expect(turns.ready == [wolf])

      roster.add(spirit, stats: stats(speed: 100), to: .allies)
      roster.remove(wolf)
      turns.didChangeRoster(added: [spirit], removed: [wolf], in: roster, rules: GaugeRules())

      #expect(turns.gauges[spirit] == 0)
      #expect(turns.gauges[wolf] == nil)
      #expect(turns.ready.isEmpty)

      turns.advanceTime(by: 1, in: roster, rules: GaugeRules())
      #expect(turns.ready == [knight, spirit])
    }
  }
}
