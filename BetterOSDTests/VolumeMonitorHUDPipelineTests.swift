//
//  VolumeMonitorHUDPipelineTests.swift
//  BetterOSDTests
//
//  Created by yu on 2026/4/11.
//

@testable import BetterOSD
import CoreAudio
import Testing

@Suite(.serialized)
@MainActor
struct VolumeMonitorHUDPipelineTests {
    @Test
    func deviceChangeUpdatesStore() {
        let fakeController = FakeSystemAudioController()
        fakeController.volumeAddress = makeVolumeAddress()
        fakeController.muteAddress = makeMuteAddress()
        let store = HUDDisplayStateStore(initialState: HUDDisplayState(iconName: "placeholder", level: 0, isMuted: false))

        let monitor = VolumeMonitor(
            audioController: fakeController,
            hudStore: store,
            initialOutputDeviceID: 7
        )
        monitor.seedOutputDeviceIDForTesting(7)

        fakeController.volume = 0.3
        fakeController.isMuted = false
        monitor.switchOutputDeviceForTesting(to: 13)
        monitor.refreshStateForTesting()

        #expect(store.current == HUDDisplayState(iconName: "speaker.wave.1.fill", level: 0.3, isMuted: false))
    }

    @Test
    func sameDeviceDoesNotUpdateStore() {
        let fakeController = FakeSystemAudioController()
        fakeController.volumeAddress = makeVolumeAddress()
        fakeController.muteAddress = makeMuteAddress()
        let placeholder = HUDDisplayState(iconName: "placeholder", level: 0, isMuted: false)
        let store = HUDDisplayStateStore(initialState: placeholder)

        let monitor = VolumeMonitor(
            audioController: fakeController,
            hudStore: store,
            initialOutputDeviceID: 7
        )
        monitor.seedOutputDeviceIDForTesting(7)

        fakeController.volume = 0.75
        fakeController.isMuted = true
        monitor.refreshStateForTesting()

        #expect(store.current == placeholder)
    }

    @Test
    func initialDeviceDiscoveryDoesNotUpdateStore() {
        let fakeController = FakeSystemAudioController()
        fakeController.volumeAddress = makeVolumeAddress()
        fakeController.muteAddress = makeMuteAddress()
        let placeholder = HUDDisplayState(iconName: "placeholder", level: 0, isMuted: false)
        let store = HUDDisplayStateStore(initialState: placeholder)

        let monitor = VolumeMonitor(
            audioController: fakeController,
            hudStore: store,
            initialOutputDeviceID: 9
        )

        fakeController.volume = 0.4
        fakeController.isMuted = false
        monitor.refreshStateForTesting()

        #expect(store.current == placeholder)
    }

    private func makeVolumeAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func makeMuteAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}
