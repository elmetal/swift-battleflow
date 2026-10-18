import Testing

@testable import swift_battleflow

// MARK: - BattleState Equality Tests

private struct CustomCommand: Command {
  let id: String
  let priority: Int
}

@Test("States with the same pending commands are equal")
func testEqualPendingCommands() async throws {
  let lhs = BattleState(pendingCommands: [BaseCommand(id: "a", priority: 1)])
  let rhs = BattleState(pendingCommands: [BaseCommand(id: "a", priority: 1)])

  #expect(lhs == rhs)
}

@Test(
  "States with different pending commands are not equal",
  arguments: [
    ([BaseCommand(id: "a")], [BaseCommand(id: "b")]),
    ([BaseCommand(id: "a", priority: 1)], [BaseCommand(id: "a", priority: 2)]),
    ([BaseCommand(id: "a"), BaseCommand(id: "b")], [BaseCommand(id: "b"), BaseCommand(id: "a")]),
    ([BaseCommand(id: "a")], [BaseCommand(id: "a"), BaseCommand(id: "a")]),
  ])
func testDifferentPendingCommands(lhs: [BaseCommand], rhs: [BaseCommand]) async throws {
  #expect(BattleState(pendingCommands: lhs) != BattleState(pendingCommands: rhs))
}

@Test("Commands of different types are not equal even with the same ID and priority")
func testDifferentCommandTypes() async throws {
  let lhs = BattleState(pendingCommands: [BaseCommand(id: "a", priority: 1)])
  let rhs = BattleState(pendingCommands: [CustomCommand(id: "a", priority: 1)])

  #expect(lhs != rhs)
}
