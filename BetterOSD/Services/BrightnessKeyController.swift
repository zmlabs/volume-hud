//
//  BrightnessKeyController.swift
//  BetterOSD
//
//  Created by yu on 2026/4/11.
//

import CoreGraphics
import Foundation

final class BrightnessKeyController {
    private let displayController: any DisplayServicesBrightnessControlling & TargetedBrightnessControlling
    private(set) var currentState = BrightnessState(brightness: 0)

    init(
        displayController: any DisplayServicesBrightnessControlling & TargetedBrightnessControlling = CompositeBrightnessClient()
    ) {
        self.displayController = displayController
    }

    func handle(_ key: MediaKeyMonitor.MediaKey, fineStep: Bool) -> MediaKeyHandlingResult {
        step(key: key, fineStep: fineStep) {
            self.displayController.currentBrightness()
        } write: { brightness in
            self.displayController.setBrightness(brightness)
        }
    }

    /// ⇧+brightness: adjust only the given display (the one under the
    /// pointer) instead of the all-displays sweep of a bare press.
    func handle(_ key: MediaKeyMonitor.MediaKey, fineStep: Bool, targetDisplayID: CGDirectDisplayID) -> MediaKeyHandlingResult {
        step(key: key, fineStep: fineStep) {
            self.displayController.currentBrightness(ofDisplay: targetDisplayID)
        } write: { brightness in
            self.displayController.setBrightness(brightness, ofDisplay: targetDisplayID)
        }
    }

    private func step(
        key: MediaKeyMonitor.MediaKey,
        fineStep: Bool,
        read: () -> Float?,
        write: (Float) -> Bool
    ) -> MediaKeyHandlingResult {
        guard key == .brightnessUp || key == .brightnessDown else {
            return .passThrough
        }

        guard let currentBrightness = read() else {
            return .passThrough
        }

        let stepsPerUnit = fineStep ? HUDCalculation.fineSteps : HUDCalculation.standardSteps
        let currentStep = Int(round(currentBrightness * Float(stepsPerUnit)))
        let targetStep = max(0, min(stepsPerUnit, currentStep + (key == .brightnessUp ? 1 : -1)))
        let targetBrightness = Float(targetStep) / Float(stepsPerUnit)

        if targetStep == currentStep {
            currentState = BrightnessState(brightness: targetBrightness)
            return .consumed(didChange: false)
        }

        guard write(targetBrightness) else {
            return .passThrough
        }

        let actualBrightness = read() ?? targetBrightness

        currentState = BrightnessState(brightness: actualBrightness)
        return .consumed(didChange: true)
    }
}
