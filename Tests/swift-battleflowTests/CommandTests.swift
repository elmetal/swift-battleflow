import Testing

@testable import swift_battleflow

// MARK: - Command Tests

@Test("Command creation and properties")
func testCommandCreation() async throws {
  let command = BaseCommand(id: "test_effect", priority: 5)

  #expect(command.id == "test_effect")
  #expect(command.priority == 5)
}

@Test("NoCommand implementation")
func testNoCommand() async throws {
  let noCommand = NoCommand()

  #expect(noCommand.id == "no_command")
  #expect(noCommand.priority == 0)
}

@Test("Effect can produce a follow-up action")
func testEffectProducesAction() async throws {
  let effect = Effect<TestAction>.send(.increment)

  let action = await effect.run()

  #expect(action == .increment)
}

@Test("Effect.map transforms the produced action")
func testEffectMap() async throws {
  let effect = Effect<TestAction>.send(.increment).map { String(describing: $0) }
  #expect(await effect.run() == "increment")

  let none = Effect<TestAction>.none.map { String(describing: $0) }
  #expect(await none.run() == nil)
}

@Test("Store dispatches actions produced by effects", .timeLimit(.minutes(1)))
@MainActor
func testStoreDispatchesEffectActions() async throws {
  let store = Store(initialState: TestState(), reducer: TestReducer())

  store.dispatch(.start)
  // Effects run asynchronously; wait for the follow-up action instead of a
  // fixed delay, which is flaky on loaded machines.
  while store.state.count == 0 {
    await Task.yield()
  }

  #expect(store.state.count == 1)
}

private struct TestState: Sendable, Equatable {
  var count = 0
}

private enum TestAction: Sendable, Equatable {
  case start
  case increment
}

private struct TestReducer: Reducer {
  func reduce(state: TestState, action: TestAction) -> Reduction<TestState, TestAction> {
    switch action {
    case .start:
      return Reduction(state: state, effects: [.send(.increment)])
    case .increment:
      var newState = state
      newState.count += 1
      return Reduction(state: newState)
    }
  }
}
