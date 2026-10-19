import Testing

@testable import BattleFlow

@Suite("Commands and effects")
struct CommandTests {
  @Test("Command creation and properties")
  func commandCreation() {
    let command = BaseCommand(id: "test_effect", priority: 5)

    #expect(command.id == "test_effect")
    #expect(command.priority == 5)
  }

  @Test("NoCommand implementation")
  func noCommand() {
    let noCommand = NoCommand()

    #expect(noCommand.id == "no_command")
    #expect(noCommand.priority == 0)
  }

  @Test("A follow-up can produce an action")
  func followUpProducesAction() async throws {
    let effect = FollowUp<TestAction>.send(.increment)

    let action = await effect.run()

    #expect(action == .increment)
  }

  @Test("FollowUp.map transforms the produced action")
  func followUpMap() async throws {
    let effect = FollowUp<TestAction>.send(.increment).map { String(describing: $0) }
    #expect(await effect.run() == "increment")

    let none = FollowUp<TestAction>.none.map { String(describing: $0) }
    #expect(await none.run() == nil)
  }

  @Test("Store dispatches actions produced by follow-ups", .timeLimit(.minutes(1)))
  @MainActor
  func storeDispatchesFollowUpActions() async throws {
    let store = Store(initialState: TestState(), reducer: TestReducer())

    store.dispatch(.start)
    // Follow-ups run asynchronously; wait for the produced action instead of a
    // fixed delay, which is flaky on loaded machines.
    while store.state.count == 0 {
      await Task.yield()
    }

    #expect(store.state.count == 1)
  }
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
      return Reduction(state: state, followUps: [.send(.increment)])
    case .increment:
      var newState = state
      newState.count += 1
      return Reduction(state: newState)
    }
  }
}
