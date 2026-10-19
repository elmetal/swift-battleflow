import Testing

@testable import BattleFlow

@Suite("Store")
struct StoreTests {
  struct Tally: Reducer {
    enum Action: Sendable, Equatable {
      case add(Int)
    }

    func reduce(state: Int, action: Action) -> Reduction<Int, Action, String> {
      switch action {
      case .add(let amount):
        Reduction(state: state + amount, outputs: ["added \(amount)"])
      }
    }
  }

  @Test("Dispatching reduces the state and records the action history")
  @MainActor
  func dispatch() {
    let store = Store(initialState: 0, reducer: Tally())

    store.dispatch(.add(2))
    store.dispatch([.add(3), .add(4)])

    #expect(store.state == 9)
    #expect(store.actionHistory == [.add(2), .add(3), .add(4)])
  }

  @Test("Resetting replaces the state and clears the history")
  @MainActor
  func reset() {
    let store = Store(initialState: 0, reducer: Tally())
    store.dispatch(.add(2))

    store.reset(to: 10)

    #expect(store.state == 10)
    #expect(store.actionHistory.isEmpty)
  }

  @Test("Outputs reach the handler with their own type")
  @MainActor
  func typedOutputs() async {
    let store = Store(initialState: 0, reducer: Tally())
    var received: [String] = []
    store.outputHandler = { output in received.append(output) }

    store.dispatch([.add(1), .add(2)])
    await store.waitForPendingOutputs()

    #expect(received == ["added 1", "added 2"])
  }

  @Test("Without a handler, outputs are dropped")
  @MainActor
  func noHandler() async {
    let store = Store(initialState: 0, reducer: Tally())

    store.dispatch(.add(1))
    await store.waitForPendingOutputs()

    #expect(store.outputHandler == nil)
    #expect(store.state == 1)
  }
}
