import Testing

@testable import BattleFlow

@Suite("Store")
struct StoreTests {
  struct Tally: Reducer {
    enum Action: Sendable, Equatable {
      case add(Int)
    }

    func reduce(state: Int, action: Action) -> Reduction<Int, Action> {
      switch action {
      case .add(let amount):
        Reduction(state: state + amount, commands: [BaseCommand(id: "added_\(amount)")])
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
}
