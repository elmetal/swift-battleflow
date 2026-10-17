import Testing

@testable import swift_battleflow

// MARK: - Engine Action Order Tests

private let a = CombatantID("a")
private let b = CombatantID("b")

private func battle() -> BattleState {
  BattleState(phase: .actionExecution)
    .withParticipant(BattleParticipant(id: a))
    .withParticipant(BattleParticipant(id: b))
}

@Test("scheduleActions sets the action order")
func testScheduleActions() async throws {
  let state = BattleReducer().reduce(state: battle(), action: .scheduleActions([b, a])).state

  #expect(state.actionOrder == [b, a])
  #expect(state.currentActor == nil)
}

@Test("advanceActor moves through the action order")
func testAdvanceActor() async throws {
  let reducer = BattleReducer()
  let scheduled = reducer.reduce(state: battle(), action: .scheduleActions([b, a])).state

  let first = reducer.reduce(state: scheduled, action: .advanceActor).state
  #expect(first.currentActor == b)
  #expect(first.actionOrder == [a])

  let second = reducer.reduce(state: first, action: .advanceActor).state
  #expect(second.currentActor == a)
  #expect(second.actionOrder.isEmpty)

  let done = reducer.reduce(state: second, action: .advanceActor).state
  #expect(done.currentActor == nil)
  #expect(done.actionOrder.isEmpty)
}

@Test("incrementTurn clears the remaining action order")
func testIncrementTurnClearsActionOrder() async throws {
  let reducer = BattleReducer()
  let scheduled = reducer.reduce(state: battle(), action: .scheduleActions([a, b])).state

  #expect(reducer.reduce(state: scheduled, action: .incrementTurn).state.actionOrder.isEmpty)
}

@Test("scheduleActions rejects unknown participants")
func testScheduleUnknownParticipant() async {
  await #expect(processExitsWith: .failure) {
    _ = BattleReducer().reduce(
      state: BattleState(), action: .scheduleActions([CombatantID("ghost")]))
  }
}

@Test("scheduleActions rejects duplicate participants")
func testScheduleDuplicateParticipants() async {
  await #expect(processExitsWith: .failure) {
    let id = CombatantID("a")
    let state = BattleState().withParticipant(BattleParticipant(id: id))
    _ = BattleReducer().reduce(state: state, action: .scheduleActions([id, id]))
  }
}
