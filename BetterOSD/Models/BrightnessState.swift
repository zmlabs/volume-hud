//
//  BrightnessState.swift
//  BetterOSD
//
//  Created by yu on 2026/4/11.
//

import Foundation

nonisolated struct BrightnessState: Equatable, Sendable {
    let brightness: Float

    init(brightness: Float) {
        self.brightness = max(0, min(1, brightness))
    }

    var iconName: String {
        brightness > 0 ? "sun.max.fill" : "sun.min.fill"
    }

    var displayState: HUDDisplayState {
        HUDDisplayState(iconName: iconName, level: brightness, isMuted: false)
    }
}
