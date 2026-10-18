# swift-battleflow
BattleFlow is a pure Swift battle engine built around State -> Action -> State.

Games define their own battle systems on top of it. A type conforming to
`CombatRules` describes the game's stats, commands, effects, calculation
pipeline, outcome, and turn system; `CombatReducer` and `CombatStore` run the
battle. Round-based (`RoundBasedTurns`) and active-time (`ActiveTimeTurns`)
turn systems are included, and you can write your own `TurnSystem`.

Battles are deterministic: randomness comes from a `BattleRandomGenerator`
value held in the state, so the same state and action always give the same
result.

Reducers return a `Reduction` that separates one-way `Command` values from
asynchronous `Effect<Action>` work that can feed actions back into a store.

See the DocC articles "Building a Rule Set" and "Choosing a Random Generator".
