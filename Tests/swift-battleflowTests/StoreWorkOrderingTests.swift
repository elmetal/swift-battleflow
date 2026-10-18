import Testing

@testable import swift_battleflow

@MainActor
private final class CommandRecorder {
  var ids: [String] = []
}

@Suite("Store work ordering")
struct StoreWorkOrderingTests {
  @Test("Commands run in dispatch order even when the handler suspends")
  @MainActor
  func commandsRunInDispatchOrder() async throws {
    let store = BattleStore()
    let recorder = CommandRecorder()
    store.commandHandler = { command in
      if command.id.hasPrefix("phase_transition") {
        try? await Task.sleep(for: .milliseconds(50))
      }
      recorder.ids.append(command.id)
    }

    store.dispatch([.transitionPhase(.ongoing), .incrementTurn])
    await store.waitForPendingCommands()

    #expect(recorder.ids == ["phase_transition_ongoing", "turn_advance"])
  }

  @Test("Waiting for pending commands includes commands dispatched while waiting")
  @MainActor
  func waitIncludesLaterDispatches() async throws {
    let store = BattleStore()
    let recorder = CommandRecorder()
    store.commandHandler = { command in
      try? await Task.sleep(for: .milliseconds(10))
      recorder.ids.append(command.id)
      if command.id.hasPrefix("phase_transition") {
        store.dispatch(.incrementTurn)
      }
    }

    store.dispatch(.transitionPhase(.ongoing))
    await store.waitForPendingCommands()

    #expect(recorder.ids == ["phase_transition_ongoing", "turn_advance"])
  }

  @Test(
    "Effects start after their reduction's commands and feed actions back", .timeLimit(.minutes(1)))
  @MainActor
  func effectsFeedActionsBack() async throws {
    struct Counter: Reducer {
      enum Action: Sendable, Equatable {
        case start
        case finish
      }
      func reduce(state: [String], action: Action) -> Reduction<[String], Action> {
        switch action {
        case .start:
          return Reduction(
            state: state + ["start"], commands: [BaseCommand(id: "c")], effects: [.send(.finish)])
        case .finish:
          return Reduction(state: state + ["finish"])
        }
      }
    }

    let store = Store(initialState: [], reducer: Counter())
    let recorder = CommandRecorder()
    store.commandHandler = { command in recorder.ids.append(command.id) }

    store.dispatch(.start)
    await store.waitForPendingCommands()
    while store.state.count < 2 { await Task.yield() }

    #expect(recorder.ids == ["c"])
    #expect(store.state == ["start", "finish"])
  }

  @Test("Commands with the same priority run in the order they were emitted")
  @MainActor
  func equalPriorityCommandsKeepOrder() async throws {
    struct Emitter: Reducer {
      func reduce(state: Int, action: Int) -> Reduction<Int, Int> {
        let ids = (0..<50).map { "c\($0)" }
        return Reduction(
          state: state,
          commands: [BaseCommand(id: "first", priority: 2)]
            + ids.map { BaseCommand(id: $0, priority: 1) })
      }
    }
    let store = Store(initialState: 0, reducer: Emitter())
    let recorder = CommandRecorder()
    store.commandHandler = { recorder.ids.append($0.id) }

    store.dispatch(0)
    await store.waitForPendingCommands()

    #expect(recorder.ids == ["first"] + (0..<50).map { "c\($0)" })
  }
}
