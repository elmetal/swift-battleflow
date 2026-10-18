import Testing

@testable import swift_battleflow

@Suite("Random generators")
struct BattleRandomGeneratorTests {
  @Suite("Seeded generator")
  struct Seeded {
    @Test("The seeded generator implements SplitMix64 exactly")
    func seededGeneratorReferenceValues() {
      var generator = SeededBattleRandomGenerator(seed: 0)

      // SplitMix64 outputs for seed 0, converted with (x >> 11) * 2^-53.
      #expect(generator.nextRoll() == 0.8833108082136426)
      #expect(generator.nextRoll() == 0.43152799704850997)
      #expect(generator.nextRoll() == 0.026433771592597743)
    }

    @Test("Generators with the same seed are equal and produce the same rolls")
    func seededGeneratorIsAValue() {
      var lhs = SeededBattleRandomGenerator(seed: 42)
      var rhs = SeededBattleRandomGenerator(seed: 42)
      #expect(lhs == rhs)

      let lhsRolls = (0..<5).map { _ in lhs.nextRoll() }
      let rhsRolls = (0..<5).map { _ in rhs.nextRoll() }
      #expect(lhsRolls == rhsRolls)
      #expect(lhs == rhs)

      _ = lhs.nextRoll()
      #expect(lhs != rhs)
      #expect(SeededBattleRandomGenerator(seed: 1) != SeededBattleRandomGenerator(seed: 2))
    }

    @Test("Seeded rolls are in 0..<1")
    func seededRollRange() {
      var generator = SeededBattleRandomGenerator(seed: 7)
      for _ in 0..<10_000 {
        let roll = generator.nextRoll()
        #expect((0..<1).contains(roll))
      }
    }
  }

  @Suite("Scripted generator")
  struct Scripted {
    @Test("The scripted generator returns its rolls in order")
    func scriptedGenerator() {
      var generator = ScriptedBattleRandomGenerator([0.25, 0.99])

      #expect(generator.nextRoll() == 0.25)
      #expect(generator.remainingRolls == [0.99])
      #expect(generator.nextRoll() == 0.99)
      #expect(generator.remainingRolls.isEmpty)
      #expect(generator == ScriptedBattleRandomGenerator([]))
    }

    @Test("The scripted generator rejects rolls outside 0..<1")
    func scriptedGeneratorRejectsInvalidRolls() async {
      await #expect(processExitsWith: .failure) {
        _ = ScriptedBattleRandomGenerator([1.0])
      }
      await #expect(processExitsWith: .failure) {
        _ = ScriptedBattleRandomGenerator([-0.1])
      }
    }

    @Test("The scripted generator stops when it runs out of rolls")
    func scriptedGeneratorExhaustion() async {
      await #expect(processExitsWith: .failure) {
        var generator = ScriptedBattleRandomGenerator([])
        _ = generator.nextRoll()
      }
    }
  }
}
