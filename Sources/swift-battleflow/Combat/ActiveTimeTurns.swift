/// Whether time keeps passing while a combatant chooses a command.
public enum ActiveTimeMode: Sendable, Equatable {
  /// Time keeps passing; others can act while a combatant chooses.
  case active

  /// Time stops while any combatant with a full gauge chooses a command.
  case wait
}

/// Rules for battles in which every combatant fills a gauge over time and
/// acts when it is full.
public protocol ActiveTimeRules: CombatRules {
  /// How much of the gauge a combatant fills per second; the gauge is full
  /// at `1`.
  ///
  /// - Postcondition: The rate is not negative.
  func gaugeRate(of actor: CombatantID, in roster: CombatRoster<Stats>) -> Double

  /// The gauge a combatant starts the battle with, in `0...1`.
  ///
  /// The default is `0`.
  func initialGauge(of actor: CombatantID, in roster: CombatRoster<Stats>) -> Double

  /// Whether time keeps passing while a combatant chooses a command.
  ///
  /// The default is ``ActiveTimeMode/active``.
  var mode: ActiveTimeMode { get }
}

extension ActiveTimeRules {
  public func initialGauge(of actor: CombatantID, in roster: CombatRoster<Stats>) -> Double {
    0
  }

  public var mode: ActiveTimeMode { .active }
}

/// A turn system in which gauges fill as time passes, a combatant with a full
/// gauge submits a command, and submitted commands run first come, first
/// served.
///
/// Time passes only through ``CombatAction/advanceTime(by:)``, so the battle
/// stays deterministic; drive it from a timer or a game loop.
public struct ActiveTimeTurns<Rules: ActiveTimeRules>: TurnSystem {
  /// The boundaries of each combatant's turn.
  public enum Boundary: Sendable, Equatable {
    /// A combatant's turn came, before its command runs, even if it can no
    /// longer act.
    case turnStarted(CombatantID)

    /// A combatant performed its command.
    case turnEnded(CombatantID)
  }

  /// A submitted command waiting to run.
  public struct Pending: Sendable, Equatable {
    public let actor: CombatantID
    public let command: Rules.Command
  }

  /// Every combatant's gauge, in `0...1`.
  public private(set) var gauges: [CombatantID: Double] = [:]

  /// Combatants with a full gauge that have not submitted, in the order their
  /// gauges filled.
  public private(set) var ready: [CombatantID] = []

  /// Submitted commands, in the order they will run.
  public private(set) var pending: [Pending] = []

  private var boundaries: [Boundary] = []

  public init() {}

  public mutating func begin(with roster: CombatRoster<Rules.Stats>, rules: Rules) {
    for id in roster.stats.keys {
      let gauge = rules.initialGauge(of: id, in: roster)
      precondition((0...1).contains(gauge), "The initial gauge must be in 0...1.")
      gauges[id] = gauge
    }
    fillGauges(by: 0, in: roster, rules: rules)
  }

  public func awaitingCommand(in roster: CombatRoster<Rules.Stats>) -> Set<CombatantID> {
    Set(ready)
  }

  public mutating func record(
    _ command: Rules.Command, by actor: CombatantID, in roster: CombatRoster<Rules.Stats>,
    rules: Rules, random: inout Rules.Generator
  ) {
    ready.removeAll { $0 == actor }
    pending.append(Pending(actor: actor, command: command))
  }

  public mutating func takeNextAction(
    in roster: CombatRoster<Rules.Stats>, rules: Rules, random: inout Rules.Generator
  ) -> (actor: CombatantID, command: Rules.Command)? {
    guard !pending.isEmpty else {
      return nil
    }
    let next = pending.removeFirst()
    gauges[next.actor] = 0
    boundaries.append(.turnStarted(next.actor))
    return (next.actor, next.command)
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

  public mutating func advanceTime(
    by seconds: Double, in roster: CombatRoster<Rules.Stats>, rules: Rules
  ) {
    // Combatants that can no longer act drop out and start over if they can
    // act again later.
    for id in ready where roster[id]?.canAct != true {
      gauges[id] = 0
    }
    ready.removeAll { roster[$0]?.canAct != true }

    if rules.mode == .wait && !ready.isEmpty {
      return
    }
    fillGauges(by: seconds, in: roster, rules: rules)
  }

  private mutating func fillGauges(
    by seconds: Double, in roster: CombatRoster<Rules.Stats>, rules: Rules
  ) {
    let waiting = Set(ready).union(pending.map(\.actor))
    var filled: [(id: CombatantID, timeToFill: Double)] = []

    for id in roster.stats.keys.sorted(by: { $0.value < $1.value }) {
      guard roster[id]?.canAct == true, !waiting.contains(id), let gauge = gauges[id] else {
        continue
      }
      let rate = rules.gaugeRate(of: id, in: roster)
      precondition(rate >= 0, "The gauge rate must not be negative.")

      let newGauge = gauge + rate * seconds
      if newGauge >= 1 {
        gauges[id] = 1
        filled.append((id, rate > 0 ? (1 - gauge) / rate : 0))
      } else {
        gauges[id] = newGauge
      }
    }

    // Gauges that filled during the same step queue up by when they filled.
    ready += filled.sorted { ($0.timeToFill, $0.id.value) < ($1.timeToFill, $1.id.value) }.map(\.id)
  }
}
