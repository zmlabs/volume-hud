//
//  KeyboardBacklightState.swift
//  BetterOSD
//

import Foundation

nonisolated struct KeyboardBacklightState: Equatable {
    let brightness: Float

    init(brightness: Float) {
        self.brightness = max(0, min(1, brightness))
    }

    var iconName: String {
        brightness > 0 ? "light.max" : "light.min"
    }

    var displayState: HUDDisplayState {
        HUDDisplayState(iconName: iconName, level: brightness, isMuted: false)
    }
}
