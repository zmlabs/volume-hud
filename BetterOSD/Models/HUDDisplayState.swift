//
//  HUDDisplayState.swift
//  BetterOSD
//
//  Created by yu on 2026/4/11.
//

import Foundation

nonisolated struct HUDDisplayState: Equatable, Sendable {
    let iconName: String
    let level: Float
    let isMuted: Bool

    static let defaultVolumePlaceholder = HUDDisplayState(
        iconName: "speaker.fill",
        level: 0,
        isMuted: false
    )
}
