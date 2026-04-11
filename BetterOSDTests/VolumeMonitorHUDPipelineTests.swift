//
//  VolumeMonitorHUDPipelineTests.swift
//  BetterOSDTests
//
//  Created by yu on 2026/4/11.
//

import CoreAudio
import Testing
@testable import BetterOSD

@Suite(.serialized)
@MainActor
struct VolumeMonitorHUDPipelineTests {
    @Test
    func refreshStateUpdatesStore() {
        let fakeController = FakeSystemAudioController()
        let monitor = VolumeMonitor(
            audioController: fakeController,
            autoStart: false,
            initialOutputDeviceID: 7,
            initialVolumePropertyAddress: makeVolumeAddress(),
            initialMutePropertyAddress: makeMuteAddress()
        )

        HUDDisplayStateStore.shared.bootstrap(with: .defaultVolumePlaceholder)

        fakeController.volume = 0.625
        fakeController.isMuted = false

        monitor.refreshStateForTesting()

        #expect(HUDDisplayStateStore.shared.current == HUDDisplayState(iconName: "speaker.wave.2.fill", level: 0.625, isMuted: false))
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
