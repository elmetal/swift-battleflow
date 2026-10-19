import Testing

@testable import BattleFlow

@MainActor
private final class OutputRecorder {
  var outputs: [String] = []
}

@Suite("Store work ordering")
struct StoreWorkOrderingTests {
  /// Outputs the name of each action.
  struct Echo: Reducer {
    enum Action: String, Sendable, Equatable {
      case first
      case second
    }

    func reduce(state: Int, action: Action) -> Reduction<Int, Action, String> {
      Reduction(state: state + 1, outputs: [action.rawValue])
    }
  }

  @Test("Outputs are delivered in dispatch order even when the handler suspends")
  @MainActor
  func outputsInDispatchOrder() async {
    let store = Store(initialState: 0, reducer: Echo())
    let recorder = OutputRecorder()
    store.outputHandler = { output in
      if output == "first" {
        try? await Task.sleep(for: .milliseconds(50))
      }
      recorder.outputs.append(output)
    }

    store.dispatch([.first, .second])
    await store.waitForPendingOutputs()

    #expect(recorder.outputs == ["first", "second"])
  }

  @Test("Waiting for pending outputs includes outputs of actions dispatched while waiting")
  @MainActor
  func waitIncludesLaterDispatches() async {
    let store = Store(initialState: 0, reducer: Echo())
    let recorder = OutputRecorder()
    store.outputHandler = { output in
      try? await Task.sleep(for: .milliseconds(10))
      recorder.outputs.append(output)
      if output == "first" {
        store.dispatch(.second)
      }
    }

    store.dispatch(.first)
    await store.waitForPendingOutputs()

    #expect(recorder.outputs == ["first", "second"])
  }

  @Test("Outputs of one reduction are delivered in the order they were emitted")
  @MainActor
  func outputsKeepEmissionOrder() async {
    struct Emitter: Reducer {
      func reduce(state: Int, action: Int) -> Reduction<Int, Int, String> {
        Reduction(state: state, outputs: (0..<50).map { "o\($0)" })
      }
    }
    let store = Store(initialState: 0, reducer: Emitter())
    let recorder = OutputRecorder()
    store.outputHandler = { recorder.outputs.append($0) }

    store.dispatch(0)
    await store.waitForPendingOutputs()

    #expect(recorder.outputs == (0..<50).map { "o\($0)" })
  }

  @Test(
    "Asks start after their reduction's outputs and their answers are dispatched",
    .timeLimit(.minutes(1)))
  @MainActor
  func asksFeedActionsBack() async {
    struct Counter: Reducer {
      enum Action: Sendable, Equatable {
        case start
        case finish
      }
      func reduce(state: [String], action: Action) -> Reduction<[String], Action, String> {
        switch action {
        case .start:
          Reduction(state: state + ["start"], outputs: ["started"], asks: [.answer(.finish)])
        case .finish:
          Reduction(state: state + ["finish"])
        }
      }
    }

    let store = Store(initialState: [], reducer: Counter())
    let recorder = OutputRecorder()
    store.outputHandler = { recorder.outputs.append($0) }

    store.dispatch(.start)
    await store.waitForPendingOutputs()
    while store.state.count < 2 { await Task.yield() }

    #expect(recorder.outputs == ["started"])
    #expect(store.state == ["start", "finish"])
  }
}
