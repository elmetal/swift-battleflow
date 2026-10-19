# ``BattleFlow``

Build turn-based battle systems whose stats, formulas, and turn order your game
defines.

## Overview

> Warning: BattleFlow is experimental. Until 1.0, any release may change the
> API.

Battle systems differ in almost everything: which stats exist, how damage is
calculated, which commands a combatant has, and how turns work. BattleFlow
splits the work between your game and the library:

- **Your game defines the meaning.** A type conforming to ``CombatRules``
  describes the stats, commands, and effects, the whole calculation pipeline,
  reactions, the outcome, and which turn system to use.
- **BattleFlow runs the flow.** ``CombatReducer`` and ``CombatStore`` decide who
  may act and in which order, apply effects one at a time, handle turn
  boundaries and computer-controlled combatants, and emit ``CombatEvent``
  values for presentation.

Battles are deterministic: randomness comes from a ``BattleRandomGenerator``
value held in ``CombatState``, so the same state and action always give the same
result, and a battle can be replayed from its seed and the players' actions.

Release notes are published on
[GitHub Releases](https://github.com/elmetal/swift-battleflow/releases).

## Topics

### Essentials

- <doc:BuildingARuleSet>
- <doc:ChoosingARandomGenerator>

### Defining Rules

- ``CombatRules``
- ``CombatantStats``
- ``CombatRoster``
- ``EffectQueue``
- ``ScheduledEffect``

### Running a Battle

- ``CombatStore``
- ``CombatReducer``
- ``CombatState``
- ``CombatAction``
- ``CombatEvent``
- ``BattlePhase``

### Turn Systems

- ``TurnSystem``
- ``RoundBasedRules``
- ``RoundBasedTurns``
- ``ActiveTimeRules``
- ``ActiveTimeTurns``
- ``ActiveTimeMode``

### Randomness

- ``BattleRandomGenerator``
- ``SeededBattleRandomGenerator``
- ``ScriptedBattleRandomGenerator``

### Identifiers

- ``CombatantID``
- ``BattleGroupID``
- ``BattleOutcome``

### State Management

- ``Store``
- ``Reducer``
- ``Reduction``
- ``Command``
- ``BaseCommand``
- ``NoCommand``
- ``FollowUp``
