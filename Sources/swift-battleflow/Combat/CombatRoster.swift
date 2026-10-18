/// The combatants of a battle, grouped by side, with their game-defined stats.
public struct CombatRoster<Stats: CombatantStats>: Sendable, Equatable {
  /// The stats of every combatant.
  public private(set) var stats: [CombatantID: Stats]

  /// The members of every side.
  public let sides: [BattleGroupID: Set<CombatantID>]

  /// Creates a roster from the members of each side.
  ///
  /// - Precondition: No combatant ID appears on more than one side.
  public init(sides: [BattleGroupID: [CombatantID: Stats]]) {
    var stats: [CombatantID: Stats] = [:]
    for members in sides.values {
      stats.merge(members) { _, _ in
        preconditionFailure("A combatant ID must not appear on more than one side.")
      }
    }
    self.stats = stats
    self.sides = sides.mapValues { Set($0.keys) }
  }

  init(stats: [CombatantID: Stats], sides: [BattleGroupID: Set<CombatantID>]) {
    self.stats = stats
    self.sides = sides
  }

  /// Returns the stats of a combatant, or `nil` if it is not in the battle.
  public subscript(id: CombatantID) -> Stats? {
    stats[id]
  }

  /// Returns the members of a side.
  public func members(of side: BattleGroupID) -> Set<CombatantID> {
    sides[side] ?? []
  }

  /// Returns the side of a combatant, or `nil` if it is not in the battle.
  public func side(of id: CombatantID) -> BattleGroupID? {
    sides.first { $0.value.contains(id) }?.key
  }

  /// The combatants that can act.
  public var actors: Set<CombatantID> {
    Set(stats.filter { $0.value.canAct }.keys)
  }

  /// Changes the stats of a combatant.
  ///
  /// - Precondition: The combatant is in the battle.
  public mutating func update(_ id: CombatantID, _ change: (inout Stats) -> Void) {
    guard var combatant = stats[id] else {
      preconditionFailure("Cannot update a combatant that is not in the battle.")
    }
    change(&combatant)
    stats[id] = combatant
  }
}
