//
//  HUDDisplayStateStore.swift
//  BetterOSD
//
//  Created by yu on 2026/4/11.
//

import Combine
import CoreGraphics
import Foundation

final class HUDDisplayStateStore {
    static let shared = HUDDisplayStateStore()

    let publisher = PassthroughSubject<HUDDisplayState, Never>()
    private(set) var current: HUDDisplayState

    /// Display the HUD should appear on — the ⇧+brightness target the update
    /// was triggered for. Nil means the main screen (volume keys, sweeps, …).
    private(set) var displayIDForHUD: CGDirectDisplayID?

    init(initialState: HUDDisplayState = .defaultVolumePlaceholder) {
        current = initialState
    }

    func bootstrap(with state: HUDDisplayState) {
        current = state
    }

    func update(_ state: HUDDisplayState, onDisplay displayID: CGDirectDisplayID? = nil) {
        current = state
        displayIDForHUD = displayID
        publisher.send(state)
    }
}
