# Choosing a Random Generator

Pick the source of randomness for a battle, and learn why it must be a value.

## Overview

Reducers are pure functions: reducing the same state with the same action
always gives the same result. That is what lets you replay a battle from its
action history and write tests that expect exact values.

Randomness keeps this property by living in the state. A battle state such as
``JRPGBattleState`` holds a ``BattleRandomGenerator`` *value*. When the reducer
needs a roll, it draws from a copy of the generator and returns the advanced
generator in the new state:

```swift
var random = state.random
let roll = random.nextRoll()  // A Double in 0..<1.
let newState = state.withRandom(random)
```

Because the generator is part of the state, the same state always yields the
same rolls.

## Use a Provided Generator

### Seeded Generator

``SeededBattleRandomGenerator`` implements SplitMix64. The algorithm is fixed,
so a seed reproduces the same battle on every platform and Swift version.

- `JRPGBattleState()` and `JRPGBattleStore()` use seed `0`, so every run plays
  out the same way. That suits tests and demos, not a shipping game.
- ``JRPGBattleFlow/makeStore()`` seeds the generator from the system, so every
  battle differs.

To replay, resume, or synchronize a battle, store the seed and pass it back:

```swift
let store = JRPGBattleFlow.makeStore(
  initialState: JRPGBattleState(random: SeededBattleRandomGenerator(seed: save.battleSeed)))
```

### Scripted Generator

``ScriptedBattleRandomGenerator`` returns predetermined rolls in order. Use it
in tests to make a specific outcome happen:

```swift
let state = JRPGBattleState(random: ScriptedBattleRandomGenerator([0.99, 0.01]))
```

Every roll must be in `0..<1`, and drawing more rolls than you provided stops
the program, so a test that needs more randomness than expected fails loudly.

## Write Your Own Generator

Any type can be a battle generator if it is a **value**:

- Its next rolls depend only on its stored properties.
- Two generators that compare equal produce the same rolls. This is what
  `Equatable` means for a generator.
- It is `Sendable`, and every roll is in `0..<1`.

For example, a game whose server deals the rolls can store them as a value:

```swift
struct ServerDealtRolls: BattleRandomGenerator {
  private var rolls: [Double]

  init(_ rolls: [Double]) {
    self.rolls = rolls
  }

  mutating func nextRoll() -> Double {
    rolls.removeFirst()
  }
}
```

The synthesized `Equatable` conformance compares the remaining rolls, so equal
generators produce equal rolls.

## Effects Are Not Generators

`SystemRandomNumberGenerator` asks the operating system for new random bits on
every call. It has no stored state, so the same battle state would produce
different rolls each time. That breaks the reducer's purity, replays, and
exact-value tests. It is an *effect*, not a value, which is why it isn't
`Equatable` and can't conform to ``BattleRandomGenerator``.

Making it conform anyway, for example with an `Equatable` conformance that
always returns `true`, would break the contract that equal generators produce
equal rolls.

Instead, call it **outside** the reducer and turn its output into a value.

### Seed a Generator from the System

Draw a seed once, when the battle starts, and keep the rest of the battle
deterministic. This is what ``JRPGBattleFlow/makeStore()`` does:

```swift
var system = SystemRandomNumberGenerator()
let seed = system.next()

let store = JRPGBattleFlow.makeStore(
  initialState: JRPGBattleState(random: SeededBattleRandomGenerator(seed: seed)))

// Save `seed` with the action history to replay the battle later.
```

### Draw Rolls from the System in Advance

If every roll must come from the system, draw them before the battle and store
them in a value-type generator:

```swift
struct SystemDrawnRolls: BattleRandomGenerator {
  private var rolls: [Double]

  /// Draws `count` rolls from the system. Call this outside the reducer.
  init(count: Int) {
    var system = SystemRandomNumberGenerator()
    rolls = (0..<count).map { _ in Double.random(in: 0..<1, using: &system) }
  }

  mutating func nextRoll() -> Double {
    precondition(!rolls.isEmpty, "Draw more rolls before the battle.")
    return rolls.removeFirst()
  }
}
```

The system is consulted only in `init(count:)`, before the battle starts, so
reducing the battle stays pure. You need to draw enough rolls for the whole
battle; prefer seeding unless your game requires system randomness for every
roll.
