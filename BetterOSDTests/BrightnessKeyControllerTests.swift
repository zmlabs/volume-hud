//
//  BrightnessKeyControllerTests.swift
//  BetterOSDTests
//
//  Created by yu on 2026/4/11.
//

import AppKit
@testable import BetterOSD
import Testing

@MainActor
struct BrightnessKeyControllerTests {
    @Test
    func doesNotProbeBrightnessInInitializer() {
        let client = FakeDisplayServicesBrightnessClient()

        _ = BrightnessKeyController(displayController: client)

        #expect(client.currentBrightnessCallCount == 0)
        #expect(client.setBrightnessCallCount == 0)
    }

    @Test
    func passesThroughWhenNoBrightnessCanBeRead() {
        let client = FakeDisplayServicesBrightnessClient()
        client.currentBrightnessResult = nil
        let controller = BrightnessKeyController(displayController: client)

        let result = controller.handle(.brightnessUp, fineStep: false)

        #expect(result == .passThrough)
        #expect(controller.currentState == BrightnessState(brightness: 0))
    }

    @Test
    func consumesAndUpdatesStateForBrightnessUp() {
        let client = FakeDisplayServicesBrightnessClient()
        client.currentBrightnessValues = [0.5, 0.5625]
        client.setBrightnessResult = true
        let controller = BrightnessKeyController(displayController: client)

        let result = controller.handle(.brightnessUp, fineStep: false)

        #expect(result == .consumed(didChange: true))
        #expect(controller.currentState == BrightnessState(brightness: 0.5625))
        #expect(client.setBrightnessArguments == [0.5625])
    }

    @Test
    func consumesUsingTargetBrightnessWhenReadbackFailsAfterSuccessfulSet() {
        let client = FakeDisplayServicesBrightnessClient()
        client.currentBrightnessValues = [0.5]
        client.setBrightnessResult = true
        let controller = BrightnessKeyController(displayController: client)

        let result = controller.handle(.brightnessUp, fineStep: false)

        #expect(result == .consumed(didChange: true))
        #expect(controller.currentState == BrightnessState(brightness: 0.5625))
        #expect(client.setBrightnessArguments == [0.5625])
    }

    @Test
    func usesFineStepForBrightnessUp() {
        let client = FakeDisplayServicesBrightnessClient()
        client.currentBrightnessValues = [0.5, 0.515625]
        client.setBrightnessResult = true
        let controller = BrightnessKeyController(displayController: client)

        let result = controller.handle(.brightnessUp, fineStep: true)

        #expect(result == .consumed(didChange: true))
        #expect(controller.currentState == BrightnessState(brightness: 0.515625))
        #expect(client.setBrightnessArguments == [0.515625])
    }

    @Test
    func consumesWithoutDidChangeAtLowerBound() {
        let client = FakeDisplayServicesBrightnessClient()
        client.currentBrightnessValues = [0.0]
        let controller = BrightnessKeyController(displayController: client)

        let result = controller.handle(.brightnessDown, fineStep: false)

        #expect(result == .consumed(didChange: false))
        #expect(controller.currentState == BrightnessState(brightness: 0.0))
        #expect(client.setBrightnessCallCount == 0)
    }

    @Test
    func consumesWithoutDidChangeAtUpperBound() {
        let client = FakeDisplayServicesBrightnessClient()
        client.currentBrightnessValues = [1.0]
        let controller = BrightnessKeyController(displayController: client)

        let result = controller.handle(.brightnessUp, fineStep: false)

        #expect(result == .consumed(didChange: false))
        #expect(controller.currentState == BrightnessState(brightness: 1.0))
        #expect(client.setBrightnessCallCount == 0)
    }
}

@MainActor
private final class FakeDisplayServicesBrightnessClient: DisplayServicesBrightnessControlling {
    var currentBrightnessCallCount = 0
    var setBrightnessCallCount = 0
    var currentBrightnessResult: Float?
    var currentBrightnessValues: [Float] = []
    var setBrightnessResult = false
    var setBrightnessArguments: [Float] = []

    func currentBrightness() -> Float? {
        currentBrightnessCallCount += 1

        if currentBrightnessValues.isEmpty == false {
            return currentBrightnessValues.removeFirst()
        }

        return currentBrightnessResult
    }

    func setBrightness(_ brightness: Float) -> Bool {
        setBrightnessCallCount += 1
        setBrightnessArguments.append(brightness)
        return setBrightnessResult
    }
}
