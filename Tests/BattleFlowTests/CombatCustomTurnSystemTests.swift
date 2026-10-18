import Testing

@testable import BattleFlow

// MARK: - A Turn System Defined Only in Tests
//
// Sides alternate, any living member of the active side may act (even more
// than once), and hitting a weakness costs only half a turn. The library is
// not changed to support it.

private typealias Rules = SideTurnSampleRules<ScriptedBattleRandomGenerator>

private let knight = CombatantID("knight")
private let mage = CombatantID("mage")
private let wolf = CombatantID("wolf")

private func stats(
  hp: Int = 200, magic: Int = 10, weaknesses: Set<SampleElement> = []
) -> ActiveTimeSampleStats {
  ActiveTimeSampleStats(
    hp: hp, maxHP: 200, mp: 99, strength: 10, magic: magic, defense: 5, magicDefense: 5,
    speed: 10, weaknesses: weaknesses)
}

private func started(rolls: [Double] = Array(repeating: 0.5, count: 8)) -> CombatState<Rules> {
  let roster = CombatRoster(sides: [
    .allies: [knight: stats(), mage: stats()],
    .foes: [wolf: stats(weaknesses: [.fire])],
  ])
  return CombatReducer(rules: Rules()).reduce(
    state: CombatState(random: ScriptedBattleRandomGenerator(rolls)), action: .start(roster)
  ).state
}

private func reduce(_ state: CombatState<Rules>, _ actions: CombatAction<Rules>...)
  -> CombatState<Rules>
{
  actions.reduce(state) { CombatReducer(rules: Rules()).reduce(state: $0, action: $1).state }
}

private func act(_ command: ActiveTimeSampleCommand, by actor: CombatantID)
  -> [CombatAction<Rules>]
{
  [.submit(command, by: actor), .performNextAction]
}

private func reduce(_ state: CombatState<Rules>, _ actions: [CombatAction<Rules>])
  -> CombatState<Rules>
{
  actions.reduce(state) { CombatReducer(rules: Rules()).reduce(state: $0, action: $1).state }
}

@Suite("A turn system defined only in tests")
struct CombatCustomTurnSystemTests {
  @Test("The first side starts with two half-turns per living member, and any member may act")
  func firstSide() {
    let state = started()

    #expect(state.turns.activeSide == .allies)
    #expect(state.turns.halfTurnsLeft == 4)
    #expect(state.awaitingCommand == [knight, mage])
  }

  @Test("The same combatant may act again while its side has turns left")
  func actAgain() {
    let state = reduce(started(), act(.attack(wolf), by: knight))

    #expect(state.turns.halfTurnsLeft == 2)
    #expect(state.awaitingCommand == [knight, mage])
  }

  @Test("When the side runs out of turns, the other side takes over")
  func sidesAlternate() {
    let state = reduce(started(), act(.attack(wolf), by: knight) + act(.attack(wolf), by: knight))

    #expect(state.turns.activeSide == .foes)
    #expect(state.turns.halfTurnsLeft == 2)
    #expect(state.awaitingCommand == [wolf])
  }

  @Test("Hitting a weakness costs only half a turn")
  func weaknessGrantsExtraAction() {
    let flame = ActiveTimeSampleCommand.cast(.flame, on: .single(wolf))
    let state = reduce(
      started(),
      act(flame, by: mage) + act(flame, by: mage) + act(.attack(wolf), by: knight))

    // 1 + 1 + 2 half-turns: three actions from a budget of two full turns.
    #expect(state.turns.activeSide == .foes)
    #expect(state.roster[wolf]!.hp < 200)
  }
}
