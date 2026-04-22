//
//  MediaKeyMonitorRoutingTests.swift
//  BetterOSDTests
//
//  Created by yu on 2026/4/11.
//

import AppKit
@testable import BetterOSD
import CoreAudio
import Testing

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
        let store = HUDDisplayStateStore(initialState: .defaultVolumePlaceholder)
        let monitor = MediaKeyMonitor(
            volumeKeyController: volumeController,
            brightnessKeyController: brightnessController,
            hudStore: store
        )

        let result = monitor.handleMediaKeyForTesting(.brightnessUp, modifiers: [])

        #expect(result == .consumed(didChange: true))
        #expect(store.current == BrightnessState(brightness: 0.75).displayState)
    }

    @Test
    func volumeKeyRoutesResultUnchanged() {
        let brightnessController = FakeBrightnessKeyHandler(
            result: .passThrough,
            currentState: BrightnessState(brightness: 0)
        )
        let volumeController = FakeVolumeKeyHandler(result: .consumed(didChange: true))
        let monitor = MediaKeyMonitor(
            volumeKeyController: volumeController,
            brightnessKeyController: brightnessController
        )

        let result = monitor.handleMediaKeyForTesting(.soundUp, modifiers: [])

        #expect(result == .consumed(didChange: true))
    }

    @Test
    func defaultVolumeControllerUsesInjectedHUDStore() {
        let audioController = FakeSystemAudioController()
        audioController.defaultDeviceID = 42
        audioController.volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        audioController.muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        audioController.volume = 0.5
        audioController.isMuted = false

        let brightnessController = FakeBrightnessKeyHandler(
            result: .passThrough,
            currentState: BrightnessState(brightness: 0)
        )
        let customStore = HUDDisplayStateStore(initialState: .defaultVolumePlaceholder)
        let sharedStore = HUDDisplayStateStore.shared
        let originalSharedState = sharedStore.current
        sharedStore.bootstrap(with: .defaultVolumePlaceholder)
        defer { sharedStore.bootstrap(with: originalSharedState) }

        let monitor = MediaKeyMonitor(
            audioController: audioController,
            brightnessKeyController: brightnessController,
            hudStore: customStore
        )

        let result = monitor.handleMediaKeyForTesting(.soundUp, modifiers: [])

        #expect(result == .consumed(didChange: true))
        #expect(customStore.current != .defaultVolumePlaceholder)
        #expect(sharedStore.current == .defaultVolumePlaceholder)
    }
}

@MainActor
private final class FakeVolumeKeyHandler: VolumeKeyHandling {
    let result: MediaKeyHandlingResult

    init(result: MediaKeyHandlingResult) {
        self.result = result
    }

    func handle(_: MediaKeyMonitor.MediaKey, fineStep _: Bool) -> MediaKeyHandlingResult {
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

    func handle(_: MediaKeyMonitor.MediaKey, fineStep _: Bool) -> MediaKeyHandlingResult {
        result
    }
}
