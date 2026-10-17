import Testing

@testable import swift_battleflow

// MARK: - Stats Contract Tests

@Test("Stats accepts values within bounds")
func testStatsAcceptsValidValues() async throws {
  let stats = Stats(hp: 0, maxHP: 100, mp: 50, maxMP: 50, attack: 0, defense: 0, speed: 0)
  #expect(stats.hp == 0)
  #expect(stats.mp == 50)
}

@Test("Stats rejects HP above max HP")
func testStatsRejectsHPAboveMax() async {
  await #expect(processExitsWith: .failure) {
    _ = Stats(hp: 150, maxHP: 100, mp: 0, maxMP: 0, attack: 0, defense: 0, speed: 0)
  }
}

@Test("Stats rejects negative HP")
func testStatsRejectsNegativeHP() async {
  await #expect(processExitsWith: .failure) {
    _ = Stats(hp: -1, maxHP: 100, mp: 0, maxMP: 0, attack: 0, defense: 0, speed: 0)
  }
}

@Test("Stats rejects MP above max MP")
func testStatsRejectsMPAboveMax() async {
  await #expect(processExitsWith: .failure) {
    _ = Stats(hp: 1, maxHP: 1, mp: 60, maxMP: 50, attack: 0, defense: 0, speed: 0)
  }
}

@Test("Stats rejects negative MP")
func testStatsRejectsNegativeMP() async {
  await #expect(processExitsWith: .failure) {
    _ = Stats(hp: 1, maxHP: 1, mp: -1, maxMP: 50, attack: 0, defense: 0, speed: 0)
  }
}

@Test("Stats rejects negative attack, defense, or speed")
func testStatsRejectsNegativeCombatValues() async {
  await #expect(processExitsWith: .failure) {
    _ = Stats(hp: 1, maxHP: 1, mp: 0, maxMP: 0, attack: -1, defense: 0, speed: 0)
  }
  await #expect(processExitsWith: .failure) {
    _ = Stats(hp: 1, maxHP: 1, mp: 0, maxMP: 0, attack: 0, defense: -1, speed: 0)
  }
  await #expect(processExitsWith: .failure) {
    _ = Stats(hp: 1, maxHP: 1, mp: 0, maxMP: 0, attack: 0, defense: 0, speed: -1)
  }
}
