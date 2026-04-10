//
//  MediaKeyMonitorRoutingTests.swift
//  BetterOSDTests
//
//  Created by yu on 2026/4/11.
//

import AppKit
import CoreAudio
import Testing
@testable import BetterOSD

@Suite(.serialized)
@MainActor
struct MediaKeyMonitorRoutingTests {
    @Test
    func brightnessConsumedUpdatesStoreFromBrightnessControllerState() {
        let brightnessController = FakeBrightnessKeyHandler(
            result: .consumed(didChange: true),
            currentState: BrightnessState(brightness: 0.75)
        )
        let volumeController = FakeVolumeKeyHandler(result: .passThrough)
        let monitor = MediaKeyMonitor(
            volumeKeyController: volumeController,
            brightnessKeyController: brightnessController
        )

        HUDDisplayStateStore.shared.bootstrap(with: .defaultVolumePlaceholder)

        let result = monitor.handleMediaKeyForTesting(.brightnessUp, modifiers: [])

        #expect(result == .consumed(didChange: true))
        #expect(HUDDisplayStateStore.shared.current == BrightnessState(brightness: 0.75).displayState)
    }

    @Test
    func volumeNoOpStillUpdatesStoreFromCurrentVolumeState() {
        let fakeAudio = FakeSystemAudioController()
        let volumeMonitor = VolumeMonitor(audioController: fakeAudio, autoStart: false)
        volumeMonitor.seedStateForTesting(VolumeState(volume: 0.25, isMuted: false, outputDeviceID: 11))

        let brightnessController = FakeBrightnessKeyHandler(
            result: .passThrough,
            currentState: BrightnessState(brightness: 0)
        )
        let volumeController = FakeVolumeKeyHandler(result: .consumed(didChange: false))
        let monitor = MediaKeyMonitor(
            volumeKeyController: volumeController,
            brightnessKeyController: brightnessController,
            volumeMonitor: volumeMonitor
        )

        HUDDisplayStateStore.shared.bootstrap(with: .defaultVolumePlaceholder)

        let result = monitor.handleMediaKeyForTesting(.soundUp, modifiers: [])

        #expect(result == .consumed(didChange: false))
        #expect(HUDDisplayStateStore.shared.current == VolumeState(volume: 0.25, isMuted: false, outputDeviceID: 11).displayState)
    }
}

@MainActor
private final class FakeVolumeKeyHandler: VolumeKeyHandling {
    let result: MediaKeyHandlingResult

    init(result: MediaKeyHandlingResult) {
        self.result = result
    }

    func handle(_ key: MediaKeyMonitor.MediaKey, fineStep: Bool) -> MediaKeyHandlingResult {
        result
    }
}

@MainActor
private final class FakeBrightnessKeyHandler: BrightnessKeyHandling {
    let result: MediaKeyHandlingResult
    var currentState: BrightnessState

    init(result: MediaKeyHandlingResult, currentState: BrightnessState) {
        self.result = result
        self.currentState = currentState
    }

    func handle(_ key: MediaKeyMonitor.MediaKey, fineStep: Bool) -> MediaKeyHandlingResult {
        result
    }
}
