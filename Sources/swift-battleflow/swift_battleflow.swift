/// Swift BattleFlow - A pure Swift battle engine for rule sets that games define.
///
/// This module is written in pure Swift and embraces a state-store pattern that
/// separates state transitions, one-way commands, and asynchronous effects.

// MARK: - Module Exports

@_exported import Foundation
@_exported import Observation

// MARK: - Engine Factory

/// The primary entry point for the rule-agnostic BattleFlow engine.
public struct BattleFlow {

  /// Creates a rule-agnostic engine battle store.
  ///
  /// - Parameter initialState: The starting engine state.
  /// - Returns: A fully initialized ``BattleStore`` ready to process battle actions.
  @MainActor
  public static func makeStore(initialState: BattleState = BattleState()) -> BattleStore {
    return BattleStore(initialState: initialState)
  }
}
