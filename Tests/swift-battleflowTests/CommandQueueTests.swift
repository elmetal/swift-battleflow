import Testing

@testable import swift_battleflow

// MARK: - Command Queue Tests

private func pendingIDs(_ state: BattleState) -> [String] {
  state.pendingCommands.map(\.id)
}

@Test("markCommandExecuted removes the executed command from the queue")
func testMarkCommandExecutedRemovesCommand() async throws {
  let reducer = BattleReducer()
  let queued = reducer.reduce(state: BattleState(), action: .enqueueCommands(["a", "b"])).state

  let reduction = reducer.reduce(state: queued, action: .markCommandExecuted("a"))

  #expect(pendingIDs(reduction.state) == ["b"])
}

@Test("markCommandExecuted removes only the first command with a duplicated ID")
func testMarkCommandExecutedRemovesFirstDuplicate() async throws {
  let reducer = BattleReducer()
  let queued = reducer.reduce(state: BattleState(), action: .enqueueCommands(["a", "b", "a"])).state

  let reduction = reducer.reduce(state: queued, action: .markCommandExecuted("a"))

  #expect(pendingIDs(reduction.state) == ["b", "a"])
}

@Test("markCommandExecuted ignores IDs that are not pending")
func testMarkCommandExecutedIgnoresUnknownID() async throws {
  let reducer = BattleReducer()
  let queued = reducer.reduce(state: BattleState(), action: .enqueueCommands(["a"])).state

  let reduction = reducer.reduce(state: queued, action: .markCommandExecuted("missing"))

  #expect(pendingIDs(reduction.state) == ["a"])
  #expect(reduction.commands.isEmpty)
}

@Test("JRPG state drains the queue through engine actions")
func testJRPGMarkCommandExecuted() async throws {
  let reducer = JRPGReducer()
  let queued = reducer.reduce(state: JRPGBattleState(), action: .engine(.enqueueCommands(["a"])))
    .state

  let drained = reducer.reduce(state: queued, action: .engine(.markCommandExecuted("a"))).state

  #expect(drained.pendingCommands.isEmpty)
}
