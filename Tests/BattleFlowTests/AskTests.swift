import Testing

@testable import BattleFlow

@Suite("Asks")
struct AskTests {
  enum Action: Sendable, Equatable {
    case start
    case increment
  }

  struct Counter: Reducer {
    func reduce(state: Int, action: Action) -> Reduction<Int, Action, Never> {
      switch action {
      case .start:
        Reduction(state: state, asks: [.answer(.increment)])
      case .increment:
        Reduction(state: state + 1)
      }
    }
  }

  @Test("An ask can answer with an action")
  func answer() async {
    #expect(await Ask<Action>.answer(.increment).run() == .increment)
    #expect(await Ask<Action>.none.run() == nil)
  }

  @Test("Ask.map transforms the answer")
  func map() async {
    #expect(await Ask<Action>.answer(.increment).map { "\($0)" }.run() == "increment")
    #expect(await Ask<Action>.none.map { "\($0)" }.run() == nil)
  }

  @Test("A store dispatches the answers to its reducer's asks", .timeLimit(.minutes(1)))
  @MainActor
  func storeDispatchesAnswers() async {
    let store = Store(initialState: 0, reducer: Counter())

    store.dispatch(.start)
    // Asks run asynchronously; wait for the answer instead of a fixed delay.
    while store.state == 0 {
      await Task.yield()
    }

    #expect(store.state == 1)
  }
}
