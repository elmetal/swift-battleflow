import Testing

@testable import swift_battleflow

// MARK: - Generic BattleAction Tests

private struct SoundCommand: Command {
  let id: String
  let priority: Int
  let volume: Double
}

@Test("enqueueCommands accepts any command type and keeps its priority")
func testEnqueueAnyCommands() async throws {
  let commands: [any Command] = [
    BaseCommand(id: "a", priority: 5),
    SoundCommand(id: "boom", priority: 2, volume: 0.5),
  ]

  let state = BattleReducer().reduce(state: BattleState(), action: .enqueueCommands(commands)).state

  #expect(state == BattleState(pendingCommands: commands))
}

@Test("BattleAction equality compares enqueued commands")
func testBattleActionCommandEquality() async throws {
  #expect(
    BattleAction.enqueueCommands([BaseCommand(id: "a")]) == .enqueueCommands([BaseCommand(id: "a")])
  )
  #expect(
    BattleAction.enqueueCommands([BaseCommand(id: "a")]) != .enqueueCommands([BaseCommand(id: "b")])
  )
  #expect(BattleAction.enqueueCommands([]) != .removeAllCommands)
}
