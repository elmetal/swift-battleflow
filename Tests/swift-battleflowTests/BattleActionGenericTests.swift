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

// MARK: - Selection Tests

private let heroID = CombatantID("hero")

private func battle(phase: BattlePhase = .turnSelection) -> BattleState {
  BattleState(phase: phase).withParticipant(BattleParticipant(id: heroID), in: .players)
}

@Test("completeSelection records the selection")
func testCompleteSelectionRecordsSelection() async throws {
  let selection = BattleSelection(id: "attack")

  let state = BattleReducer().reduce(
    state: battle(), action: .completeSelection(selection, for: heroID)
  ).state

  #expect(state.selections == [heroID: selection])
}

@Test("beginSelection discards the previous selection")
func testBeginSelectionClearsPreviousSelection() async throws {
  let reducer = BattleReducer()
  let selected = reducer.reduce(
    state: battle(), action: .completeSelection(BattleSelection(id: "attack"), for: heroID)
  ).state

  let reselecting = reducer.reduce(state: selected, action: .beginSelection(for: heroID)).state

  #expect(reselecting.selections.isEmpty)
}

@Test("incrementTurn clears selections, other actions keep them")
func testSelectionsLifetime() async throws {
  let reducer = BattleReducer()
  let selected = reducer.reduce(
    state: battle(), action: .completeSelection(BattleSelection(id: "attack"), for: heroID)
  ).state

  let executing = reducer.reduce(state: selected, action: .transitionPhase(.actionExecution)).state
  #expect(executing.selections == selected.selections)

  let nextTurn = reducer.reduce(state: executing, action: .incrementTurn).state
  #expect(nextTurn.selections.isEmpty)
}

@Test(
  "Selections are ignored for unknown participants or ended battles",
  arguments: [
    (CombatantID("ghost"), BattlePhase.turnSelection),
    (heroID, BattlePhase.ended(BattleOutcome("test.over"))),
  ])
func testSelectionPreconditions(id: CombatantID, phase: BattlePhase) async throws {
  let state = battle(phase: phase)

  let reduction = BattleReducer().reduce(
    state: state, action: .completeSelection(BattleSelection(id: "attack"), for: id))

  #expect(reduction.state == state)
  #expect(reduction.commands.isEmpty)
}
