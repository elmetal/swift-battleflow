/// The stats a game defines for its combatants.
///
/// The combat layer knows nothing about hit points, attack power, or any other
/// stat. It only needs to know whether a combatant can act, which a game may
/// base on hit points, status ailments, having fled, or anything else.
public protocol CombatantStats: Sendable, Equatable {
  /// Whether the combatant can take a turn.
  var canAct: Bool { get }
}

/// The definition of a game's battle system.
///
/// A game provides its own stats, commands, and effects, the whole calculation
/// pipeline that turns a command into effects, how effects change stats, when
/// the battle is decided, and which turn system it uses. The combat layer
/// takes care of the flow: who may act, in which order, applying effects,
/// ending the battle, and keeping randomness deterministic.
public protocol CombatRules: Sendable {
  /// The game's combatant stats.
  associatedtype Stats: CombatantStats

  /// What a combatant can choose to do, such as attacking or casting a spell.
  associatedtype Command: Sendable, Equatable

  /// A result of resolving a command, such as damage or healing.
  associatedtype Effect: Sendable, Equatable

  /// The battle's random generator.
  associatedtype Generator: BattleRandomGenerator

  /// The turn system that decides who submits commands and who acts next.
  associatedtype Turns: TurnSystem where Turns.Rules == Self

  /// Resolves a command into effects.
  ///
  /// All game-specific calculation happens here: weapon and spell formulas,
  /// target selection, multi-target commands, randomness, and so on.
  ///
  /// - Parameters:
  ///   - command: The command to resolve.
  ///   - actor: The combatant performing the command. It can act.
  ///   - state: The state before the command is resolved.
  ///   - random: The battle's generator; draw rolls from it as needed.
  /// - Returns: The effects to apply, in order.
  func resolve(
    _ command: Command, by actor: CombatantID, in state: CombatState<Self>,
    random: inout Generator
  ) -> [Effect]

  /// Returns the effects that happen when the battle reaches a turn
  /// boundary, such as poison at the end of a turn.
  ///
  /// The turn system decides which boundaries exist. The default returns no
  /// effects.
  func effects(
    at boundary: Turns.Boundary, in state: CombatState<Self>, random: inout Generator
  ) -> [Effect]

  /// Applies an effect to the roster.
  func apply(_ effect: Effect, to roster: inout CombatRoster<Stats>)

  /// Returns the outcome when the battle is decided, or `nil` while it goes on.
  ///
  /// Called after each performed command and after each boundary's effects.
  func outcome(of roster: CombatRoster<Stats>) -> BattleOutcome?
}

extension CombatRules {
  public func effects(
    at boundary: Turns.Boundary, in state: CombatState<Self>, random: inout Generator
  ) -> [Effect] {
    []
  }
}

/// Decides who submits commands and who acts next.
///
/// A turn system is a value stored in the combat state. The library provides
/// ``RoundBasedTurns`` and you can write your own; each turn system declares
/// what it needs from the rules, typically through a protocol that refines
/// ``CombatRules``.
public protocol TurnSystem: Sendable, Equatable {
  /// The rules this turn system works with.
  associatedtype Rules: CombatRules

  /// The turn boundaries this turn system reaches, such as the end of a
  /// combatant's turn or of a round.
  associatedtype Boundary: Sendable, Equatable = Never

  /// Creates a turn system for a battle that has not started.
  init()

  /// Prepares for a battle with the given roster.
  mutating func begin(with roster: CombatRoster<Rules.Stats>, rules: Rules)

  /// Returns the combatants that may submit a command now.
  ///
  /// The combat layer only accepts commands from these combatants, and only
  /// while they can act.
  func awaitingCommand(in roster: CombatRoster<Rules.Stats>) -> Set<CombatantID>

  /// Records a command submitted by a combatant that was awaiting one.
  mutating func record(
    _ command: Rules.Command, by actor: CombatantID, in roster: CombatRoster<Rules.Stats>,
    rules: Rules, random: inout Rules.Generator)

  /// Removes and returns the next command to perform, or returns `nil` when
  /// none is ready.
  ///
  /// The combat layer skips the command if its actor can no longer act.
  mutating func takeNextAction(
    in roster: CombatRoster<Rules.Stats>, rules: Rules, random: inout Rules.Generator
  ) -> (actor: CombatantID, command: Rules.Command)?

  /// Observes the effects of a performed command, for example to grant an
  /// extra action.
  mutating func didPerform(
    _ effects: [Rules.Effect], by actor: CombatantID, in roster: CombatRoster<Rules.Stats>,
    rules: Rules)

  /// Lets time pass, for turn systems that depend on time.
  mutating func advanceTime(
    by seconds: Double, in roster: CombatRoster<Rules.Stats>, rules: Rules)

  /// Removes and returns the boundaries reached since the last call, in
  /// order.
  ///
  /// The combat layer calls this after every other turn system method and
  /// applies the rules' effects for each boundary. Within
  /// ``CombatAction/performNextAction``, boundaries recorded by
  /// ``takeNextAction(in:rules:random:)`` are handled before the command, and
  /// boundaries recorded by ``didPerform(_:by:in:rules:)`` after it.
  mutating func takeBoundaries() -> [Boundary]
}

extension TurnSystem where Boundary == Never {
  public mutating func takeBoundaries() -> [Never] {
    []
  }
}

extension TurnSystem {
  public mutating func begin(with roster: CombatRoster<Rules.Stats>, rules: Rules) {}

  public mutating func didPerform(
    _ effects: [Rules.Effect], by actor: CombatantID, in roster: CombatRoster<Rules.Stats>,
    rules: Rules
  ) {}

  public mutating func advanceTime(
    by seconds: Double, in roster: CombatRoster<Rules.Stats>, rules: Rules
  ) {}
}
