import Testing

@testable import BattleFlow

@Suite("Battle reducer")
struct BattleReducerTests {
  @Test("Reducer handles advance turn and phase change")
  func reducerAdvanceTurnAndPhase() {
    let reducer = BattleReducer()
    let state = BattleState(phase: .ongoing, turnCount: 3, currentActor: CombatantID("hero"))

    let turnReduction = reducer.reduce(state: state, action: .incrementTurn)
    #expect(turnReduction.state.turnCount == 4)
    #expect(turnReduction.state.currentActor == nil)
    #expect(turnReduction.commands.contains { ($0 as? BaseCommand)?.id == "turn_advance" })

    let phaseReduction = reducer.reduce(
      state: state, action: .transitionPhase(.ongoing))
    #expect(phaseReduction.state.phase == .ongoing)
    #expect(
      phaseReduction.commands.contains {
        ($0 as? BaseCommand)?.id == "phase_transition_ongoing"
      })
  }

  @Test("Reducer handles engine actions directly")
  func reducerBattleActionDirectly() {
    let reducer = BattleReducer()
    let state = BattleState(phase: .ongoing, turnCount: 1)

    let reduction = reducer.reduce(state: state, action: BattleAction.incrementTurn)

    #expect(reduction.state.turnCount == 2)
    #expect(reduction.commands.contains { ($0 as? BaseCommand)?.id == "turn_advance" })
  }
}
