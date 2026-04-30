//
//  KeyboardBacklightKeyController.swift
//  BetterOSD
//

import Foundation
import os

protocol KeyboardBacklightKeyHandling: AnyObject {
    var currentState: KeyboardBacklightState { get }
    func handle(_ key: MediaKeyMonitor.MediaKey, fineStep: Bool) -> MediaKeyHandlingResult
}

// Handles keyboard-backlight keys using the same consume-and-set pattern as BrightnessKeyController.
//
// Debounce / fade-conflict strategy
// ----------------------------------
// CoreBrightness applies brightness changes with a 350 ms animated fade. Rapid key presses
// (faster than the fade) would cause two problems without mitigation:
//
//   1. Step calculation reads a mid-fade value from `currentBrightness()`, producing a
//      wrong base and therefore a wrong target.
//   2. The OSD would flicker: it fires on every press before the display settles.
//
// Fix: we track `pendingTarget` — the brightness we most recently *commanded*.  While a
// fade is in flight, new presses base their step calculation on `pendingTarget` rather than
// the hardware readback. After `fadeSpeed + clearanceMs` the pending state is cleared so
// the next press reads a fresh value from hardware.
//
// Falls back to passThrough when the brightness client is unavailable (no keyboard backlight
// on this Mac, or CoreBrightness private API changed).
final class KeyboardBacklightKeyController: KeyboardBacklightKeyHandling {

    private let brightnessClient: KeyboardBrightnessControlling
    private let fadeSpeedMs: Int32
    private(set) var currentState = KeyboardBacklightState(brightness: 0)

    // Brightness we last commanded; non-nil while a fade is in progress.
    private var pendingTarget: Float?
    // Clears pendingTarget after the fade animation completes.
    // Task<Void, Never> is Sendable, so it is safe to cancel from nonisolated deinit.
    private var fadeClearTask: Task<Void, Never>?

    /// Extra margin after fadeSpeed before we trust the hardware readback again.
    private static let clearanceMs = 30
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "dev.zhangyu.volume-hud",
        category: "KeyboardBacklight"
    )

    init(
        brightnessClient: KeyboardBrightnessControlling = KeyboardBrightnessClient() ?? NoKeyboardBacklight(),
        fadeSpeedMs: Int32 = KeyboardBrightnessClient.defaultFadeSpeedMs
    ) {
        self.brightnessClient = brightnessClient
        self.fadeSpeedMs = fadeSpeedMs
    }

    // MARK: - KeyboardBacklightKeyHandling

    func handle(_ key: MediaKeyMonitor.MediaKey, fineStep: Bool) -> MediaKeyHandlingResult {
        guard key == .keyboardBrightnessUp || key == .keyboardBrightnessDown else {
            return .passThrough
        }

        // Use in-flight pending target as base to avoid mid-fade readback errors.
        let base: Float
        if let pending = pendingTarget {
            base = pending
        } else {
            guard let live = brightnessClient.currentBrightness() else {
                Self.logger.info("currentBrightness returned nil — passing event through")
                return .passThrough
            }
            base = live
        }

        let stepsPerUnit = fineStep ? HUDCalculation.fineSteps : HUDCalculation.standardSteps
        let currentStep = Int(round(base * Float(stepsPerUnit)))
        let targetStep  = max(0, min(stepsPerUnit,
                                     currentStep + (key == .keyboardBrightnessUp ? 1 : -1)))
        let target = Float(targetStep) / Float(stepsPerUnit)

        if targetStep == currentStep {
            // Already at bound — consume without changing brightness.
            currentState = KeyboardBacklightState(brightness: target)
            return .consumed(didChange: false)
        }

        guard brightnessClient.setBrightness(target, fadeSpeed: fadeSpeedMs) else {
            Self.logger.error("setBrightness(\(target, format: .fixed(precision: 3))) failed — passing event through")
            return .passThrough
        }

        // Track in-flight target; cancel any previous clear task.
        pendingTarget = target
        fadeClearTask?.cancel()
        let clearDelay = Duration.milliseconds(Int(fadeSpeedMs) + Self.clearanceMs)
        fadeClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: clearDelay)
            guard !Task.isCancelled else { return }
            self?.pendingTarget = nil
        }

        currentState = KeyboardBacklightState(brightness: target)
        return .consumed(didChange: true)
    }

    deinit {
        fadeClearTask?.cancel()
    }
}

// Returned by init when CoreBrightness is unavailable — all calls passThrough.
private final class NoKeyboardBacklight: KeyboardBrightnessControlling {
    func currentBrightness() -> Float? { nil }
    func setBrightness(_: Float, fadeSpeed _: Int32) -> Bool { false }
}
