# Building a Rule Set

Define your game's stats, commands, formulas, and turn system, and let the
combat layer run the battle.

## Overview

Battle systems differ in almost everything: which stats exist, how damage is
calculated, which commands a combatant has, and how turns work. The combat
layer therefore splits the work:

- **Your game defines the meaning:** stats, commands, the whole calculation
  pipeline, what each effect does, when the battle is decided, and which turn
  system to use. You describe all of this in a type that conforms to
  ``CombatRules``.
- **The library runs the flow:** who may submit a command, who acts next,
  applying effects, ending the battle, emitting events for presentation, and
  keeping everything deterministic.

The library contains no stats, formulas, or command kinds of its own.

## Define Stats

Stats are a value type that conforms to ``CombatantStats``. The only thing the
library reads is ``CombatantStats/canAct``, so you decide what keeps a
combatant from acting: running out of hit points, sleeping, having fled, and so
on.

```swift
struct Stats: CombatantStats {
  var hp: Int
  var maxHP: Int
  var attack: Int
  var defense: Int
  var agility: Int
  var isAsleep = false

  var canAct: Bool { hp > 0 && !isAsleep }
}
```

Group combatants by side in a ``CombatRoster``. Sides are
``BattleGroupID`` values that you define.

```swift
extension BattleGroupID {
  static let party = BattleGroupID("party")
  static let monsters = BattleGroupID("monsters")
}

let roster = CombatRoster(sides: [
  .party: [CombatantID("hero"): heroStats],
  .monsters: [CombatantID("slime"): slimeStats],
])
```

## Define Commands and Effects

A command is what a combatant chooses to do; an effect is a result of
resolving it. Both are your own `Equatable` types, so they can carry exactly
what your game needs: spells, items, elements, a single target or a whole
group.

```swift
enum Command: Sendable, Equatable {
  case attack(CombatantID)
  case attackGroup(BattleGroupID)
  case heal(CombatantID, amount: Int)
}

enum Effect: Sendable, Equatable {
  case damage(CombatantID, amount: Int, isCritical: Bool)
  case heal(CombatantID, amount: Int)
  case missed
}
```

## Resolve Commands

``CombatRules/resolve(_:by:in:random:)`` is your calculation pipeline. It
receives the command, its actor, the current state, and the battle's random
generator, and returns the effects to apply. Weapon and spell formulas, target
selection, multi-target commands, damage variance, and critical hits all
belong here.

```swift
func resolve(
  _ command: Command, by actor: CombatantID, in state: CombatState<Self>,
  random: inout Generator
) -> [Effect] {
  guard case .attack(let target) = command,
    let attacker = state.roster[actor], let defender = state.roster[target], defender.canAct
  else { return [.missed] }

  let isCritical = random.nextRoll() < 1.0 / 32
  let base = isCritical
    ? Double(attacker.attack)  // A critical hit ignores defense.
    : max(0, Double(attacker.attack) / 2 - Double(defender.defense) / 4)
  let variance = 0.875 + random.nextRoll() / 4
  return [.damage(target, amount: max(1, Int((base * variance).rounded())), isCritical: isCritical)]
}
```

Draw randomness only from `random`. The generator is stored in the state, so
the same state and command always resolve the same way. See
<doc:ChoosingARandomGenerator>.

## Apply Effects and Decide the Outcome

``CombatRules/apply(_:to:)`` changes the roster for one effect, and
``CombatRules/outcome(of:)`` returns a ``BattleOutcome`` once the battle is
decided. The library calls `outcome(of:)` after every performed command.

```swift
func apply(_ effect: Effect, to roster: inout CombatRoster<Stats>) {
  switch effect {
  case .damage(let id, let amount, _):
    roster.update(id) { $0.hp = max(0, $0.hp - amount) }
  case .heal(let id, let amount):
    roster.update(id) { $0.hp = min($0.maxHP, $0.hp + amount) }
  case .missed:
    break
  }
}

func outcome(of roster: CombatRoster<Stats>) -> BattleOutcome? {
  let monstersDown = roster.members(of: .monsters).allSatisfy { !roster[$0]!.canAct }
  return monstersDown ? BattleOutcome("party_wins") : nil
}
```

## Choose a Turn System

A turn system decides who may submit a command and who acts next. Pick one by
setting the rules' `Turns` type, and provide what that turn system asks for.

### Round-Based Turns

With ``RoundBasedTurns``, every combatant that can act submits a command, then
the round's commands run by priority and initiative. Conform to
``RoundBasedRules``:

```swift
struct MyRules<Generator: BattleRandomGenerator>: RoundBasedRules {
  typealias Turns = RoundBasedTurns<Self>
  // Stats, Command, Effect, resolve, apply, outcome...

  func priority(of command: Command) -> Int {
    if case .heal = command { return 1 }  // Healing goes first.
    return 0
  }

  func initiative(
    of actor: CombatantID, in roster: CombatRoster<Stats>, random: inout Generator
  ) -> Double {
    Double(roster[actor]!.agility) * (0.5 + random.nextRoll() / 2)
  }
}
```

### Active-Time Turns

With ``ActiveTimeTurns``, every combatant fills a gauge over time and submits a
command when it is full; submitted commands run first come, first served.
Conform to ``ActiveTimeRules`` and provide a gauge rate. Optionally set a
starting gauge or ``ActiveTimeMode/wait`` mode, which stops time while a
combatant chooses.

```swift
struct MyRules<Generator: BattleRandomGenerator>: ActiveTimeRules {
  typealias Turns = ActiveTimeTurns<Self>
  var mode: ActiveTimeMode = .wait

  func gaugeRate(of actor: CombatantID, in roster: CombatRoster<Stats>) -> Double {
    Double(roster[actor]!.speed) / 100  // A speed of 50 fills the gauge in two seconds.
  }
}
```

Time passes only when you dispatch ``CombatAction/advanceTime(by:)``, for
example from a game loop, so the battle stays deterministic.

### Your Own Turn System

If neither fits, conform a value type to ``TurnSystem``. Declare what you need
from the rules in a protocol that refines ``CombatRules``, and implement:

- ``TurnSystem/awaitingCommand(in:)``: who may submit now.
- ``TurnSystem/record(_:by:in:rules:random:)``: store a submitted command.
- ``TurnSystem/takeNextAction(in:rules:random:)``: hand out the next command to
  perform.
- Optionally ``TurnSystem/begin(with:rules:)``,
  ``TurnSystem/didPerform(_:by:in:rules:)``, and
  ``TurnSystem/advanceTime(by:in:rules:)``.

For example, a system in which sides alternate and hitting a weakness costs
only half a turn reads the effects in `didPerform`:

```swift
protocol SideTurnRules: CombatRules {
  var sideOrder: [BattleGroupID] { get }
  func halfTurnCost(of effects: [Effect]) -> Int
}

struct SideTurns<Rules: SideTurnRules>: TurnSystem {
  // awaitingCommand: the living members of the active side.
  // didPerform: subtract rules.halfTurnCost(of: effects); switch sides at zero.
}
```

The library's tests define exactly this turn system without any change to the
library.

## Run the Battle

Create a ``CombatStore`` with an initial state and your rules, then start the
battle, submit commands, and perform them:

```swift
let store = CombatStore(
  initialState: CombatState(random: SeededBattleRandomGenerator(seed: seed)),
  rules: MyRules())

store.start(roster)
store.submit(.attack(slime), by: hero)
store.performNextAction()
```

The combat layer ignores actions that don't fit the current state, such as a
command from a combatant that isn't awaiting one. It emits ``CombatEvent``
values as commands, in order, so your presentation layer can animate exactly
what happened, including the game-defined effects of each command.

To test your rules, use ``ScriptedBattleRandomGenerator`` to choose the rolls,
for example to force a critical hit.
