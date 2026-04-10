//
//  HUDDisplayStateTests.swift
//  BetterOSDTests
//
//  Created by yu on 2026/4/11.
//

import Testing
@testable import BetterOSD

struct HUDDisplayStateTests {
    @Test
    func usesSafeVolumePlaceholder() {
        #expect(
            HUDDisplayState.defaultVolumePlaceholder ==
                HUDDisplayState(iconName: "speaker.fill", level: 0, isMuted: false)
        )
    }

    @Test @MainActor
    func convertsVolumeStateToDisplayState() {
        let state = VolumeState(volume: 0.5, isMuted: true, outputDeviceID: 42)

        #expect(
            state.displayState ==
                HUDDisplayState(iconName: "speaker.slash.fill", level: 0.5, isMuted: true)
        )
    }

    @Test
    func convertsBrightnessStateToDisplayState() {
        let state = BrightnessState(brightness: 0.75)

        #expect(
            state.displayState ==
                HUDDisplayState(iconName: "sun.max.fill", level: 0.75, isMuted: false)
        )
    }
}
