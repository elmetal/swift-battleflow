import Testing
@testable import swift_battleflow

// MARK: - Effect Tests

@Test("Effect creation and properties")
func testEffectCreation() async throws {
    let effect = BaseEffect(id: "test_effect", priority: 5)

    #expect(effect.id == "test_effect")
    #expect(effect.priority == 5)
}

@Test("NoEffect implementation")
func testNoEffect() async throws {
    let noEffect = NoEffect()

    #expect(noEffect.id == "no_effect")
    #expect(noEffect.priority == 0)
}
