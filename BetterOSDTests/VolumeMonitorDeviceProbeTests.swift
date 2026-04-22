//
//  VolumeMonitorDeviceProbeTests.swift
//  BetterOSDTests
//
//  Created by yu on 2026/4/20.
//

@testable import BetterOSD
import CoreAudio
import Testing

@Suite(.serialized)
@MainActor
struct VolumeMonitorDeviceProbeTests {
    @Test
    func appliesPendingDeviceAfterProbeRetriesAreExhausted() async {
        let fakeController = FakeSystemAudioController()
        fakeController.defaultDeviceID = 84
        fakeController.deviceAlive = false
        fakeController.volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        fakeController.muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        fakeController.volume = 0.5
        fakeController.isMuted = false

        let placeholder = HUDDisplayState(iconName: "placeholder", level: 0, isMuted: false)
        let store = HUDDisplayStateStore(initialState: placeholder)

        let monitor = VolumeMonitor(
            audioController: fakeController,
            hudStore: store,
            initialOutputDeviceID: 42
        )

        monitor.seedOutputDeviceIDForTesting(42)

        monitor.updateOutputDevice()
        await waitUntil {
            store.current != placeholder
        }

        #expect(store.current == VolumeState.read(deviceID: 84, from: fakeController).displayState)
    }

    private func waitUntil(
        timeout: Duration = .seconds(3),
        pollingInterval: Duration = .milliseconds(50),
        condition: @escaping () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout

        while condition() == false, clock.now < deadline {
            try? await Task.sleep(for: pollingInterval)
        }
    }
}
