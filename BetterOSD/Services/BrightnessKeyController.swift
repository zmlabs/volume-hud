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

    init(displayController: DisplayServicesBrightnessControlling = DisplayServicesBrightnessClient()) {
        self.displayController = displayController
    }

    func handle(_ key: MediaKeyMonitor.MediaKey, fineStep: Bool) -> MediaKeyHandlingResult {
        guard key == .brightnessUp || key == .brightnessDown else {
            return .passThrough
        }

        guard let currentBrightness = displayController.currentBrightness() else {
            return .passThrough
        }

        let step = fineStep ? HUDCalculation.fineStep : HUDCalculation.coarseStep
        let delta: Float = key == .brightnessUp ? step : -step
        let targetBrightness = max(0, min(1, currentBrightness + delta))

        if targetBrightness == currentBrightness {
            currentState = BrightnessState(brightness: currentBrightness)
            return .consumed(didChange: false)
        }

        guard displayController.setBrightness(targetBrightness) else {
            return .passThrough
        }

        let actualBrightness = displayController.currentBrightness() ?? targetBrightness

        currentState = BrightnessState(brightness: actualBrightness)
        return .consumed(didChange: actualBrightness != currentBrightness)
    }
}
