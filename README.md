# swift-battleflow

> [!WARNING]
> BattleFlow is **experimental**. Until 1.0, any release may change the API.

BattleFlow is a pure Swift library for building turn-based battle systems.
Your game defines what a battle means — stats, commands, formulas, effects, and
which turn system to use — and BattleFlow runs the flow: who may act, in which
order, applying effects, reactions, and deciding the outcome.

- **Game-defined rules.** A type conforming to `CombatRules` describes your
  stats, commands, effects, calculation pipeline, and outcome. The library
  contains no stats or formulas of its own.
- **Turn systems.** Round-based (`RoundBasedTurns`) and active-time
  (`ActiveTimeTurns`) turns are included, and you can write your own
  `TurnSystem`.
- **Deterministic.** Randomness comes from a `BattleRandomGenerator` value held
  in the state, so the same state and action always give the same result.
- **Reactions and turn boundaries.** Counterattacks, poison at the end of a
  turn, delayed effects, and computer-controlled combatants are part of the
  rules.

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/elmetal/swift-battleflow.git", exact: "0.0.1")
],
targets: [
  .target(name: "MyGame", dependencies: [.product(name: "BattleFlow", package: "swift-battleflow")])
]
```

BattleFlow requires Swift 6.1 or later, and iOS 17, macOS 14, tvOS 17, or
watchOS 10.

## Quick Start

Define your game's stats, commands, and effects:

```swift
import BattleFlow

struct Stats: CombatantStats {
  var hp: Int
  var attack: Int

  var canAct: Bool { hp > 0 }
}

enum Command: Sendable, Equatable {
  case attack(CombatantID)
}

enum Effect: Sendable, Equatable {
  case damage(CombatantID, amount: Int)
}

extension BattleGroupID {
  static let heroes = BattleGroupID("heroes")
  static let enemies = BattleGroupID("enemies")
}
```

Describe how commands resolve, how effects apply, when the battle is decided,
and how round-based turns are ordered:

```swift
struct Rules<Generator: BattleRandomGenerator>: RoundBasedRules {
  typealias Turns = RoundBasedTurns<Self>

  func resolve(
    _ command: Command, by actor: CombatantID, in state: CombatState<Self>,
    random: inout Generator
  ) -> [Effect] {
    switch command {
    case .attack(let target):
      let variance = 0.9 + random.nextRoll() / 5  // 0.9 ..< 1.1
      let amount = Int(Double(state.roster[actor]!.attack) * variance)
      return [.damage(target, amount: amount)]
    }
  }

  func apply(_ effect: Effect, to roster: inout CombatRoster<Stats>) {
    switch effect {
    case .damage(let target, let amount):
      roster.update(target) { $0.hp = max(0, $0.hp - amount) }
    }
  }

  func outcome(of roster: CombatRoster<Stats>) -> BattleOutcome? {
    let enemiesDown = roster.members(of: .enemies).allSatisfy { !roster[$0]!.canAct }
    return enemiesDown ? BattleOutcome("victory") : nil
  }

  func priority(of command: Command) -> Int { 0 }

  func initiative(
    of actor: CombatantID, in roster: CombatRoster<Stats>, random: inout Generator
  ) -> Double {
    Double(roster[actor]!.attack)
  }
}
```

Run a battle:

```swift
let hero = CombatantID("hero")
let slime = CombatantID("slime")

let store = CombatStore(
  initialState: CombatState(random: SeededBattleRandomGenerator(seed: 42)),
  rules: Rules<SeededBattleRandomGenerator>())
store.commandHandler = { event in print(event.id) }  // Present events here.

store.start(
  CombatRoster(sides: [
    .heroes: [hero: Stats(hp: 30, attack: 12)],
    .enemies: [slime: Stats(hp: 10, attack: 3)],
  ]))
store.submit(.attack(slime), by: hero)
store.submit(.attack(hero), by: slime)
store.performNextAction()
await store.waitForPendingCommands()  // Events are delivered asynchronously.

print(store.state.outcome == BattleOutcome("victory"))  // true
```

`CombatStore` is `@MainActor` and `@Observable`, so SwiftUI views can read
`store.state` directly.

## Learn More

The DocC articles go further:

- **Building a Rule Set** — stats, commands and effects, the resolve pipeline,
  reactions and scheduled effects, turn boundaries, computer-controlled
  combatants, and choosing or writing a turn system.
- **Choosing a Random Generator** — seeded and scripted generators, writing
  your own, and why `SystemRandomNumberGenerator` is used through a seed.

The tests include complete sample rule sets: round-based, active-time, status
ailments, reactions, and a custom turn system.

## License

See [LICENSE](LICENSE).
