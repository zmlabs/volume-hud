//
//  HUDDisplayStateStore.swift
//  BetterOSD
//
//  Created by yu on 2026/4/11.
//

import Combine
import Foundation

final class HUDDisplayStateStore {
    static let shared = HUDDisplayStateStore()

    let publisher = PassthroughSubject<HUDDisplayState, Never>()
    private(set) var current: HUDDisplayState

    init(initialState: HUDDisplayState = .defaultVolumePlaceholder) {
        current = initialState
    }

    func bootstrap(with state: HUDDisplayState) {
        current = state
    }

    func update(_ state: HUDDisplayState) {
        current = state
        publisher.send(state)
    }
}
