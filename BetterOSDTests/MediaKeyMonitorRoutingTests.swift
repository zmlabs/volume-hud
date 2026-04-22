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
