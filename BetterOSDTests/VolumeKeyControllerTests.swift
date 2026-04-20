//
//  VolumeKeyControllerTests.swift
//  BetterOSDTests
//
//  Created by yu on 2026/4/20.
//

@testable import BetterOSD
import CoreAudio
import Testing

@Suite(.serialized)
@MainActor
struct VolumeKeyControllerTests {
    @Test
    func soundUpPushesNewVolumeState() {
        let fakeController = makeFake(volume: 0.5, isMuted: false)
        let store = HUDDisplayStateStore(initialState: placeholder)
        let controller = VolumeKeyController(audioController: fakeController, hudStore: store)

        let result = controller.handle(.soundUp, fineStep: false)

        #expect(result == .consumed(didChange: true))
        #expect(store.current.level > 0.5)
        #expect(store.current != placeholder)
    }

    @Test
    func soundUpAtCeilingStillPushesHUDOnNoOp() {
        let fakeController = makeFake(volume: 1.0, isMuted: false)
        let store = HUDDisplayStateStore(initialState: placeholder)
        let controller = VolumeKeyController(audioController: fakeController, hudStore: store)

        let result = controller.handle(.soundUp, fineStep: false)

        #expect(result == .consumed(didChange: false))
        #expect(store.current != placeholder)
        #expect(store.current.level == 1.0)
        #expect(store.current.isMuted == false)
    }

    @Test
    func muteTogglePushesMutedState() {
        let fakeController = makeFake(volume: 0.5, isMuted: false)
        let store = HUDDisplayStateStore(initialState: placeholder)
        let controller = VolumeKeyController(audioController: fakeController, hudStore: store)

        let result = controller.handle(.mute, fineStep: false)

        #expect(result == .consumed(didChange: true))
        #expect(store.current.isMuted == true)
    }

    @Test
    func brightnessKeysDoNotPushHUD() {
        let fakeController = makeFake(volume: 0.5, isMuted: false)
        let store = HUDDisplayStateStore(initialState: placeholder)
        let controller = VolumeKeyController(audioController: fakeController, hudStore: store)

        let resultUp = controller.handle(.brightnessUp, fineStep: false)
        let resultDown = controller.handle(.brightnessDown, fineStep: false)

        #expect(resultUp == .passThrough)
        #expect(resultDown == .passThrough)
        #expect(store.current == placeholder)
    }

    @Test
    func passThroughWhenNoDefaultDevice() {
        let fakeController = FakeSystemAudioController()
        fakeController.defaultDeviceID = nil
        let store = HUDDisplayStateStore(initialState: placeholder)
        let controller = VolumeKeyController(audioController: fakeController, hudStore: store)

        let result = controller.handle(.soundUp, fineStep: false)

        #expect(result == .passThrough)
        #expect(store.current == placeholder)
    }

    @Test
    func muteToggleRestoresVolumeWhenCurrentIsZero() {
        let fakeController = makeFake(volume: 0.0, isMuted: true)
        let store = HUDDisplayStateStore(initialState: placeholder)
        let controller = VolumeKeyController(audioController: fakeController, hudStore: store)

        let result = controller.handle(.mute, fineStep: false)

        #expect(result == .consumed(didChange: true))
        #expect(store.current.isMuted == false)
        #expect(store.current.level > 0)
    }

    @Test
    func soundUpFromMutedUnmutesAndSteps() {
        let fakeController = makeFake(volume: 0.5, isMuted: true)
        let store = HUDDisplayStateStore(initialState: placeholder)
        let controller = VolumeKeyController(audioController: fakeController, hudStore: store)

        let result = controller.handle(.soundUp, fineStep: false)

        #expect(result == .consumed(didChange: true))
        #expect(store.current.isMuted == false)
        #expect(store.current.level > 0.5)
    }

    @Test
    func soundUpFallsBackToCapturedVolumeWhenPostSetReadFails() {
        let fakeController = makeFake(volume: 0.5, isMuted: false)
        fakeController.getVolumeFailsOnCall = 2
        let store = HUDDisplayStateStore(initialState: placeholder)
        let controller = VolumeKeyController(audioController: fakeController, hudStore: store)

        let result = controller.handle(.soundUp, fineStep: false)

        #expect(result == .consumed(didChange: true))
        #expect(store.current.level == 0.5)
        #expect(store.current != placeholder)
    }

    @Test
    func soundDownToZeroAutoMutes() {
        let stepsPerUnit = Float(HUDCalculation.standardSteps)
        let oneStep = 1.0 / stepsPerUnit
        let fakeController = makeFake(volume: oneStep, isMuted: false)
        let store = HUDDisplayStateStore(initialState: placeholder)
        let controller = VolumeKeyController(audioController: fakeController, hudStore: store)

        let result = controller.handle(.soundDown, fineStep: false)

        #expect(result == .consumed(didChange: true))
        #expect(store.current.isMuted == true)
        #expect(store.current.level == 0)
    }

    private let placeholder = HUDDisplayState(iconName: "placeholder", level: -1, isMuted: false)

    private func makeFake(volume: Float, isMuted: Bool) -> FakeSystemAudioController {
        let fake = FakeSystemAudioController()
        fake.defaultDeviceID = 42
        fake.volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        fake.muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        fake.volume = volume
        fake.isMuted = isMuted
        return fake
    }
}
