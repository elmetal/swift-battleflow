import Testing

@testable import BattleFlow

@Suite("Effect queue")
struct EffectQueueTests {
  typealias Rules = ReactionSampleRules<ScriptedBattleRandomGenerator>
  typealias Effect = ReactionSampleEffect

  static let hero = CombatantID("hero")
  static let cleric = CombatantID("cleric")
  static let orc = CombatantID("orc")
  static let slime = CombatantID("slime")

  @Suite("Insertion order")
  struct InsertionOrder {
    @Test("Effects come out in the order they were appended")
    func append() {
      var queue = EffectQueue<Rules>([.enrage(hero)])
      queue.append(.enrage(orc))
      queue.append(contentsOf: [.enrage(slime), .enrage(cleric)])

      #expect(queue.pending == [.enrage(hero), .enrage(orc), .enrage(slime), .enrage(cleric)])
    }

    @Test("Prepended effects come out next, keeping their own order")
    func prepend() {
      var queue = EffectQueue<Rules>([.enrage(hero)])
      queue.prepend(.enrage(orc))
      queue.prepend(contentsOf: [.enrage(slime), .enrage(cleric)])

      #expect(queue.pending == [.enrage(slime), .enrage(cleric), .enrage(orc), .enrage(hero)])
    }

    @Test("Scheduling needs a positive occurrence")
    func scheduleNeedsPositiveOccurrence() async {
      await #expect(processExitsWith: .failure) {
        var queue = EffectQueue<ReactionSampleRules<ScriptedBattleRandomGenerator>>([])
        queue.schedule(
          .collapse(CombatantID("orc")), at: .turnEnded(CombatantID("orc")), occurrence: 0)
      }
    }
  }

  @Suite("Reactions in battle")
  struct Reactions {
    func roster(orcHP: Int = 18, slimeHP: Int = 20) -> CombatRoster<ReactionSampleStats> {
      CombatRoster(sides: [
        .party: [
          hero: ReactionSampleStats(hp: 30, maxHP: 30, attack: 10, agility: 20),
          cleric: ReactionSampleStats(hp: 30, maxHP: 30, attack: 2, agility: 10),
        ],
        .monsters: [
          orc: ReactionSampleStats(hp: orcHP, maxHP: 30, attack: 4, agility: 5, counter: 3),
          slime: ReactionSampleStats(hp: slimeHP, maxHP: 20, attack: 1, agility: 1),
        ],
      ])
    }

    func reduce(_ state: CombatState<Rules>, _ action: CombatAction<Rules>)
      -> CombatReduction<Rules>
    {
      CombatReducer(rules: Rules()).reduce(state: state, action: action)
    }

    func reduce(_ state: CombatState<Rules>, _ actions: [CombatAction<Rules>]) -> CombatState<Rules>
    {
      actions.reduce(state) { reduce($0, $1).state }
    }

    /// Starts the battle and submits a round; order: hero, cleric, orc, slime.
    func round(
      _ roster: CombatRoster<ReactionSampleStats>? = nil,
      hero heroCommand: ReactionSampleCommand,
      cleric clericCommand: ReactionSampleCommand = .bless(hero),
      orc orcCommand: ReactionSampleCommand = .attack(cleric),
      slime slimeCommand: ReactionSampleCommand = .attack(cleric)
    ) -> CombatState<Rules> {
      let started = reduce(
        CombatState(random: ScriptedBattleRandomGenerator([])), .start(roster ?? self.roster())
      ).state
      return reduce(
        started,
        [
          .submit(heroCommand, by: hero), .submit(clericCommand, by: cleric),
          .submit(orcCommand, by: orc), .submit(slimeCommand, by: slime),
        ])
    }

    func performed(_ reduction: CombatReduction<Rules>) -> [Effect]? {
      for case .performed(_, _, let effects) in reduction.outputs {
        return effects
      }
      return nil
    }

    @Test("Prepended reactions run at once; appended ones wait for the queue")
    func reactionOrder() {
      let reduction = reduce(round(hero: .sweep([orc, slime])), .performNextAction)

      #expect(
        performed(reduction) == [
          .damage(orc, amount: 10, source: hero, isCounter: false),
          .enrage(orc),
          .damage(slime, amount: 10, source: hero, isCounter: false),
          .enrage(slime),
          // The orc's counterattack was queued first but waits for the rest.
          .damage(hero, amount: 3, source: orc, isCounter: true),
        ])
      #expect(reduction.state.roster[hero]?.hp == 27)
      #expect(reduction.state.roster[orc]?.isEnraged == true)
    }

    @Test("A scheduled effect happens at the requested occurrence of a boundary")
    func scheduledEffect() {
      // The hero curses the slime: it collapses at the end of its second turn.
      let afterRound1 = reduce(
        round(hero: .curse(slime)), Array(repeating: .performNextAction, count: 5))
      #expect(afterRound1.turns.round == 2)
      #expect(afterRound1.roster[slime]?.hp == 20)
      #expect(afterRound1.scheduledEffects.map(\.remainingOccurrences) == [1])

      let round2 = reduce(
        afterRound1,
        [
          .submit(.attack(orc), by: hero), .submit(.attack(orc), by: cleric),
          .submit(.attack(cleric), by: orc), .submit(.attack(cleric), by: slime),
          .performNextAction, .performNextAction, .performNextAction,
        ])
      let slimeTurn = reduce(round2, .performNextAction)

      #expect(slimeTurn.state.roster[slime]?.hp == 0)
      #expect(slimeTurn.state.scheduledEffects.isEmpty)
      #expect(
        slimeTurn.outputs.contains(
          .boundary(.turnEnded(slime), effects: [.collapse(slime)])))
    }

    @Test("Scheduled effects can be cancelled")
    func cancelScheduled() {
      let cursed = reduce(round(hero: .curse(slime), cleric: .bless(slime)), .performNextAction)
        .state
      #expect(cursed.scheduledEffects.count == 1)

      let blessed = reduce(cursed, .performNextAction).state

      #expect(blessed.scheduledEffects.isEmpty)
    }

    @Test("The queue stops once the battle is decided")
    func stopsAtOutcome() {
      // Only the slime is left; the sweep knocks it out before reaching the cleric.
      let reduction = reduce(
        round(roster(orcHP: 0, slimeHP: 5), hero: .sweep([slime, cleric])), .performNextAction)

      #expect(reduction.state.outcome == .partyWins)
      #expect(performed(reduction) == [.damage(slime, amount: 10, source: hero, isCounter: false)])
      #expect(reduction.state.roster[cleric]?.hp == 30)
    }
  }
}
