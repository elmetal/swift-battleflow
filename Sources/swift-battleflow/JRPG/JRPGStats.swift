/// Captures the JRPG stats used for battle calculations.
public struct Stats: Sendable, Equatable {
  public let hp: Int
  public let maxHP: Int
  public let mp: Int
  public let maxMP: Int
  public let attack: Int
  public let defense: Int
  public let speed: Int

  public init(
    hp: Int,
    maxHP: Int,
    mp: Int,
    maxMP: Int,
    attack: Int,
    defense: Int,
    speed: Int
  ) {
    self.hp = hp
    self.maxHP = maxHP
    self.mp = mp
    self.maxMP = maxMP
    self.attack = attack
    self.defense = defense
    self.speed = speed
  }

  /// Indicates whether the combatant has been defeated.
  public var isDefeated: Bool {
    return hp <= 0
  }

  /// Returns a copy of the stats with updated hit points.
  public func withHP(_ newHP: Int) -> Stats {
    Stats(
      hp: max(0, min(newHP, maxHP)),
      maxHP: maxHP,
      mp: mp,
      maxMP: maxMP,
      attack: attack,
      defense: defense,
      speed: speed
    )
  }

  /// Returns a copy of the stats with updated magic points.
  public func withMP(_ newMP: Int) -> Stats {
    Stats(
      hp: hp,
      maxHP: maxHP,
      mp: max(0, min(newMP, maxMP)),
      maxMP: maxMP,
      attack: attack,
      defense: defense,
      speed: speed
    )
  }
}
