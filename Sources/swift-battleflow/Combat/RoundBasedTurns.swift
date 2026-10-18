/// Rules for battles in which everyone selects a command each round before
/// the round's commands run in order.
public protocol RoundBasedRules: CombatRules {
  /// The priority of a command; commands with a higher priority run first.
  func priority(of command: Command) -> Int

  /// The initiative of a combatant for this round; among commands with the
  /// same priority, a higher initiative runs first.
  ///
  /// Draw from `random` for initiative that varies from round to round.
  func initiative(
    of actor: CombatantID, in roster: CombatRoster<Stats>, random: inout Generator
  ) -> Double
}

/// A turn system in which every combatant that can act submits a command,
/// then the round's commands run by priority and initiative.
///
/// After the last command of a round, the next ``CombatAction/performNextAction``
/// starts the next round.
public struct RoundBasedTurns<Rules: RoundBasedRules>: TurnSystem {
  /// The boundaries of rounds and of each combatant's turn.
  public enum Boundary: Sendable, Equatable {
    /// A round started; reached when the battle starts and after each round.
    case roundStarted(Int)

    /// Every command of the round has run.
    case roundEnded(Int)

    /// A combatant's turn came, before its command runs, even if it can no
    /// longer act.
    case turnStarted(CombatantID)

    /// A combatant performed its command.
    case turnEnded(CombatantID)
  }

  /// The current round, starting at 1.
  public private(set) var round = 0

  /// The commands submitted for the current round.
  public private(set) var commands: [CombatantID: Rules.Command] = [:]

  /// The combatants that still have to act this round, in order.
  public private(set) var order: [CombatantID] = []

  /// Whether every command of the round has been submitted.
  public private(set) var isExecuting = false

  private var boundaries: [Boundary] = []

  public init() {}

  public mutating func begin(with roster: CombatRoster<Rules.Stats>, rules: Rules) {
    round = 1
    boundaries.append(.roundStarted(round))
  }

  public func awaitingCommand(in roster: CombatRoster<Rules.Stats>) -> Set<CombatantID> {
    isExecuting ? [] : roster.actors.subtracting(commands.keys)
  }

  public mutating func record(
    _ command: Rules.Command, by actor: CombatantID, in roster: CombatRoster<Rules.Stats>,
    rules: Rules, random: inout Rules.Generator
  ) {
    commands[actor] = command
    guard roster.actors.isSubset(of: commands.keys) else {
      return
    }

    // Draw initiative in ID order, so the roll each actor receives does not
    // depend on dictionary order.
    let actors = commands.keys.sorted { $0.value < $1.value }.map { id in
      (
        id: id, priority: rules.priority(of: commands[id]!),
        initiative: rules.initiative(of: id, in: roster, random: &random)
      )
    }
    // Higher priority first, then higher initiative, then ascending ID. The
    // ID is compared in swapped order so that it sorts ascending.
    order = actors.sorted { lhs, rhs in
      (lhs.priority, lhs.initiative, rhs.id.value) > (rhs.priority, rhs.initiative, lhs.id.value)
    }.map(\.id)
    isExecuting = true
  }

  public mutating func takeNextAction(
    in roster: CombatRoster<Rules.Stats>, rules: Rules, random: inout Rules.Generator
  ) -> (actor: CombatantID, command: Rules.Command)? {
    guard isExecuting else {
      return nil
    }
    guard !order.isEmpty else {
      boundaries.append(.roundEnded(round))
      round += 1
      commands = [:]
      isExecuting = false
      boundaries.append(.roundStarted(round))
      return nil
    }
    let actor = order.removeFirst()
    boundaries.append(.turnStarted(actor))
    return (actor, commands[actor]!)
  }

  public mutating func didPerform(
    _ effects: [Rules.Effect], by actor: CombatantID, in roster: CombatRoster<Rules.Stats>,
    rules: Rules
  ) {
    boundaries.append(.turnEnded(actor))
  }

  public mutating func takeBoundaries() -> [Boundary] {
    defer { boundaries = [] }
    return boundaries
  }
}
