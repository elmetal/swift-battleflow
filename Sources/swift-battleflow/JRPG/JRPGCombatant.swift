/// Describes a JRPG participant in the battle.
public struct Combatant: Sendable, Equatable {
  public let id: CombatantID
  public let name: String
  public let stats: Stats
  public let isPlayerControlled: Bool

  public init(
    id: CombatantID,
    name: String,
    stats: Stats,
    isPlayerControlled: Bool
  ) {
    self.id = id
    self.name = name
    self.stats = stats
    self.isPlayerControlled = isPlayerControlled
  }

  /// Returns a copy of the combatant using updated stats.
  public func withStats(_ newStats: Stats) -> Combatant {
    Combatant(
      id: id,
      name: name,
      stats: newStats,
      isPlayerControlled: isPlayerControlled
    )
  }
}
