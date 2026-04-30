//
//  KeyboardBacklightKeyControllerTests.swift
//  BetterOSDTests
//

@testable import BetterOSD
import Testing

@MainActor
struct KeyboardBacklightKeyControllerTests {

    @Test
    func doesNotProbeBrightnessInInitializer() {
        let client = FakeKeyboardBrightnessClient()

        _ = KeyboardBacklightKeyController(brightnessClient: client)

        #expect(client.getCallCount == 0)
        #expect(client.setCallCount == 0)
    }

    @Test
    func passesThroughWhenClientReturnsNil() {
        let client = FakeKeyboardBrightnessClient(getBrightness: nil)
        let controller = KeyboardBacklightKeyController(brightnessClient: client)

        let result = controller.handle(.keyboardBrightnessUp, fineStep: false)

        #expect(result == .passThrough)
        #expect(controller.currentState == KeyboardBacklightState(brightness: 0))
    }

    @Test
    func passesThroughWhenSetFails() {
        let client = FakeKeyboardBrightnessClient(getBrightness: 0.5, setBrightnessResult: false)
        let controller = KeyboardBacklightKeyController(brightnessClient: client)

        let result = controller.handle(.keyboardBrightnessUp, fineStep: false)

        #expect(result == .passThrough)
    }

    @Test
    func consumesAndIncreasesForBrightnessUp() {
        let client = FakeKeyboardBrightnessClient(getValues: [0.5, 0.5625], setBrightnessResult: true)
        let controller = KeyboardBacklightKeyController(brightnessClient: client)

        let result = controller.handle(.keyboardBrightnessUp, fineStep: false)

        #expect(result == .consumed(didChange: true))
        #expect(controller.currentState == KeyboardBacklightState(brightness: 0.5625))
        #expect(client.setArguments == [0.5625])
    }

    @Test
    func consumesAndDecreasesForBrightnessDown() {
        let client = FakeKeyboardBrightnessClient(getValues: [0.5, 0.4375], setBrightnessResult: true)
        let controller = KeyboardBacklightKeyController(brightnessClient: client)

        let result = controller.handle(.keyboardBrightnessDown, fineStep: false)

        #expect(result == .consumed(didChange: true))
        #expect(controller.currentState == KeyboardBacklightState(brightness: 0.4375))
    }

    @Test
    func usesFineStepWhenRequested() {
        let client = FakeKeyboardBrightnessClient(getValues: [0.5, 0.515625], setBrightnessResult: true)
        let controller = KeyboardBacklightKeyController(brightnessClient: client)

        let result = controller.handle(.keyboardBrightnessUp, fineStep: true)

        #expect(result == .consumed(didChange: true))
        #expect(client.setArguments == [0.515625])
    }

    @Test
    func consumesWithoutDidChangeAtUpperBound() {
        let client = FakeKeyboardBrightnessClient(getValues: [1.0])
        let controller = KeyboardBacklightKeyController(brightnessClient: client)

        let result = controller.handle(.keyboardBrightnessUp, fineStep: false)

        #expect(result == .consumed(didChange: false))
        #expect(client.setCallCount == 0)
    }

    @Test
    func consumesWithoutDidChangeAtLowerBound() {
        let client = FakeKeyboardBrightnessClient(getValues: [0.0])
        let controller = KeyboardBacklightKeyController(brightnessClient: client)

        let result = controller.handle(.keyboardBrightnessDown, fineStep: false)

        #expect(result == .consumed(didChange: false))
        #expect(client.setCallCount == 0)
    }

    @Test
    func passesThroughForIrrelevantKey() {
        let client = FakeKeyboardBrightnessClient()
        let controller = KeyboardBacklightKeyController(brightnessClient: client)

        let result = controller.handle(.soundUp, fineStep: false)

        #expect(result == .passThrough)
        #expect(client.getCallCount == 0)
    }

    @Test
    func usesTargetBrightnessWhenReadbackFailsAfterSet() {
        let client = FakeKeyboardBrightnessClient(getValues: [0.5], setBrightnessResult: true)
        let controller = KeyboardBacklightKeyController(brightnessClient: client)

        let result = controller.handle(.keyboardBrightnessUp, fineStep: false)

        #expect(result == .consumed(didChange: true))
        #expect(controller.currentState == KeyboardBacklightState(brightness: 0.5625))
    }
}

// MARK: - Fake

@MainActor
private final class FakeKeyboardBrightnessClient: KeyboardBrightnessControlling {
    private(set) var getCallCount = 0
    private(set) var setCallCount = 0
    private(set) var setArguments: [Float] = []

    private var getValues: [Float]
    private let fixed: Float?
    private let setBrightnessResult: Bool

    init(getBrightness: Float? = 0.5, setBrightnessResult: Bool = true) {
        self.fixed = getBrightness
        self.getValues = []
        self.setBrightnessResult = setBrightnessResult
    }

    init(getValues: [Float], setBrightnessResult: Bool = true) {
        self.fixed = nil
        self.getValues = getValues
        self.setBrightnessResult = setBrightnessResult
    }

    func currentBrightness() -> Float? {
        getCallCount += 1
        if !getValues.isEmpty { return getValues.removeFirst() }
        return fixed
    }

    func setBrightness(_ brightness: Float, fadeSpeed _: Int32) -> Bool {
        setCallCount += 1
        setArguments.append(brightness)
        return setBrightnessResult
    }
}
