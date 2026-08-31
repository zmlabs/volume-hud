//
//  BrightnessKeyController.swift
//  BetterOSD
//
//  Created by yu on 2026/4/11.
//

import Foundation

final class BrightnessKeyController {
    private let displayController: DisplayServicesBrightnessControlling
    private(set) var currentState = BrightnessState(brightness: 0)

    init(displayController: DisplayServicesBrightnessControlling = CompositeBrightnessClient()) {
        self.displayController = displayController
    }

    func handle(_ key: MediaKeyMonitor.MediaKey, fineStep: Bool) -> MediaKeyHandlingResult {
        guard key == .brightnessUp || key == .brightnessDown else {
            return .passThrough
        }

        guard let currentBrightness = displayController.currentBrightness() else {
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

        guard displayController.setBrightness(targetBrightness) else {
            return .passThrough
        }

        let actualBrightness = displayController.currentBrightness() ?? targetBrightness

        currentState = BrightnessState(brightness: actualBrightness)
        return .consumed(didChange: true)
    }
}
