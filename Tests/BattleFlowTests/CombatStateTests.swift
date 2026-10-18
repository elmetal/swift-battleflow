import Testing

@testable import BattleFlow

@Suite("Combat state")
struct CombatStateTests {
  typealias Rules = RoundSampleRules<ScriptedBattleRandomGenerator>

  @Test("A battle goes from preparation to ongoing to ended")
  func phases() {
    let reducer = CombatReducer(rules: Rules())
    let initial = CombatState<Rules>(random: ScriptedBattleRandomGenerator([]))
    #expect(initial.phase == .preparation)
    #expect(initial.roster.stats.isEmpty)
    #expect(!initial.isOngoing && !initial.isEnded && initial.outcome == nil)

    let roster = CombatRoster(sides: [
      .party: [
        CombatantID("hero"): RoundSampleStats(hp: 1, maxHP: 1, attack: 1, defense: 1, agility: 1)
      ]
    ])
    let started = reducer.reduce(state: initial, action: .start(roster)).state
    #expect(started.phase == .ongoing)
    #expect(started.roster == roster)
    #expect(started.isOngoing && started.outcome == nil)

    let ended = reducer.reduce(state: started, action: .end(.partyLoses)).state
    #expect(ended.phase == .ended(.partyLoses))
    #expect(ended.isEnded && !ended.isOngoing && ended.outcome == .partyLoses)
  }
}
