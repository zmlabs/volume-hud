//
//  HUDDisplayStateStoreTests.swift
//  BetterOSDTests
//
//  Created by yu on 2026/4/11.
//

import Combine
import Testing
@testable import BetterOSD

@MainActor
struct HUDDisplayStateStoreTests {
    @Test
    func bootstrapSetsCurrentWithoutPublishing() {
        let store = HUDDisplayStateStore(initialState: .defaultVolumePlaceholder)
        var published: [HUDDisplayState] = []
        let cancellable = store.publisher.sink { published.append($0) }
        let state = HUDDisplayState(iconName: "speaker.wave.2.fill", level: 0.4, isMuted: false)

        store.bootstrap(with: state)

        #expect(store.current == state)
        #expect(published.isEmpty)
        _ = cancellable
    }

    @Test
    func updatePublishesAfterCurrentChanges() {
        let store = HUDDisplayStateStore(initialState: .defaultVolumePlaceholder)

        var stateSeenInsideSink: HUDDisplayState?
        let expected = HUDDisplayState(iconName: "sun.max.fill", level: 0.8, isMuted: false)
        let cancellable = store.publisher.sink { value in
            stateSeenInsideSink = store.current
            #expect(value == expected)
        }

        store.update(expected)

        #expect(stateSeenInsideSink == expected)
        _ = cancellable
    }
}
