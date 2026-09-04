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
    func optionAloneOpensSoundSettingsInsteadOfAdjusting() {
        let volumeController = FakeVolumeKeyHandler(result: .consumed(didChange: true))
        var openedPanes: [URL] = []
        let monitor = MediaKeyMonitor(
            volumeKeyController: volumeController,
            brightnessKeyController: FakeBrightnessKeyHandler(
                result: .passThrough,
                currentState: BrightnessState(brightness: 0)
            ),
            openSettingsPane: { openedPanes.append($0) }
        )

        let result = monitor.handleMediaKeyForTesting(.soundUp, modifiers: [.option])

        #expect(result == .consumed(didChange: false))
        #expect(openedPanes.map(\.absoluteString) == [
            "x-apple.systempreferences:com.apple.Sound-Settings.extension"
        ])
        #expect(volumeController.callCount == 0)
    }

    @Test
    func optionAloneOpensDisplaysSettingsForBrightness() {
        var openedPanes: [URL] = []
        let monitor = MediaKeyMonitor(
            volumeKeyController: FakeVolumeKeyHandler(result: .consumed(didChange: true)),
            brightnessKeyController: FakeBrightnessKeyHandler(
                result: .passThrough,
                currentState: BrightnessState(brightness: 0)
            ),
            openSettingsPane: { openedPanes.append($0) }
        )

        let result = monitor.handleMediaKeyForTesting(.brightnessUp, modifiers: [.option])

        #expect(result == .consumed(didChange: false))
        #expect(openedPanes.map(\.absoluteString) == [
            "x-apple.systempreferences:com.apple.Displays-Settings.extension"
        ])
    }

    @Test
    func shiftOptionStillRoutesToControllers() {
        let volumeController = FakeVolumeKeyHandler(result: .consumed(didChange: true))
        var openedPanes: [URL] = []
        let monitor = MediaKeyMonitor(
            volumeKeyController: volumeController,
            brightnessKeyController: FakeBrightnessKeyHandler(
                result: .passThrough,
                currentState: BrightnessState(brightness: 0)
            ),
            openSettingsPane: { openedPanes.append($0) }
        )

        let result = monitor.handleMediaKeyForTesting(.soundUp, modifiers: [.shift, .option])

        #expect(result == .consumed(didChange: true))
        #expect(volumeController.callCount == 1)
        #expect(openedPanes.isEmpty)
    }

    @Test
    func shiftBrightnessTargetsDisplayUnderCursor() {
        let brightnessController = FakeBrightnessKeyHandler(
            result: .consumed(didChange: true),
            currentState: BrightnessState(brightness: 0.75)
        )
        let store = HUDDisplayStateStore(initialState: .defaultVolumePlaceholder)
        let monitor = MediaKeyMonitor(
            volumeKeyController: FakeVolumeKeyHandler(result: .passThrough),
            brightnessKeyController: brightnessController,
            hudStore: store,
            displayUnderCursor: { 99 }
        )

        let result = monitor.handleMediaKeyForTesting(.brightnessUp, modifiers: [.shift])

        #expect(result == .consumed(didChange: true))
        #expect(brightnessController.targetedDisplayIDs == [99])
        #expect(brightnessController.callCount == 0)
        #expect(store.current == BrightnessState(brightness: 0.75).displayState)
        // The HUD follows the adjusted display, not just the main screen.
        #expect(store.displayIDForHUD == 99)
    }

    @Test
    func shiftOptionBrightnessStillSweepsAllDisplays() {
        let brightnessController = FakeBrightnessKeyHandler(
            result: .consumed(didChange: true),
            currentState: BrightnessState(brightness: 0)
        )
        let monitor = MediaKeyMonitor(
            volumeKeyController: FakeVolumeKeyHandler(result: .passThrough),
            brightnessKeyController: brightnessController,
            displayUnderCursor: { 99 }
        )

        let result = monitor.handleMediaKeyForTesting(.brightnessUp, modifiers: [.shift, .option])

        #expect(result == .consumed(didChange: true))
        #expect(brightnessController.callCount == 1)
        #expect(brightnessController.targetedDisplayIDs.isEmpty)
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
    private(set) var callCount = 0

    init(result: MediaKeyHandlingResult) {
        self.result = result
    }

    func handle(
        _: MediaKeyMonitor.MediaKey,
        fineStep _: Bool,
        invertFeedback _: Bool
    ) -> MediaKeyHandlingResult {
        callCount += 1
        return result
    }
}

@MainActor
private final class FakeBrightnessKeyHandler: BrightnessKeyHandling {
    let result: MediaKeyHandlingResult
    var currentState: BrightnessState
    private(set) var callCount = 0
    private(set) var targetedDisplayIDs: [CGDirectDisplayID] = []

    init(result: MediaKeyHandlingResult, currentState: BrightnessState) {
        self.result = result
        self.currentState = currentState
    }

    func handle(_: MediaKeyMonitor.MediaKey, fineStep _: Bool) -> MediaKeyHandlingResult {
        callCount += 1
        return result
    }

    func handle(
        _: MediaKeyMonitor.MediaKey,
        fineStep _: Bool,
        targetDisplayID: CGDirectDisplayID
    ) -> MediaKeyHandlingResult {
        targetedDisplayIDs.append(targetDisplayID)
        return result
    }
}
