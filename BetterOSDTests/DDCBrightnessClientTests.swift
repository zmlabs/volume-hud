//
//  DDCBrightnessClientTests.swift
//  BetterOSD
//
//  Created by yu on 2026/8/31.
//

import Foundation
@testable import BetterOSD
import Testing

@MainActor
struct DDCBrightnessClientTests {
    /// Fixed fake display so tests don't depend on the host's monitor layout.
    private static let candidate: DDCDisplayCandidateProvider = {
        (displayID: 42, displayKey: "0x10ac:0x437d:1112950348")
    }

    private let noDisplay: DDCDisplayCandidateProvider = { nil }

    @Test
    func returnsNilWhenNoExternalDisplay() {
        let client = DDCBrightnessClient(
            transportProvider: { _ in nil },
            displayCandidateProvider: noDisplay,
            defaults: makeDefaults()
        )

        #expect(client.currentBrightness() == nil)
        #expect(client.setBrightness(0.5) == false)
    }

    @Test
    func readsSaneLuminanceAndCachesIt() {
        let defaults = makeDefaults()
        let transport = FakeDDCTransport(lastReadLuminance: (current: 40, max: 100))
        var resolveCount = 0
        let client = DDCBrightnessClient(
            transportProvider: { _ in
                resolveCount += 1
                return transport
            },
            displayCandidateProvider: Self.candidate,
            defaults: defaults
        )

        #expect(client.currentBrightness() == 0.4)
        #expect(client.currentBrightness() == 0.4)
        #expect(resolveCount == 1)

        // Cache survives a fresh client instance (persisted per display).
        let revived = DDCBrightnessClient(
            transportProvider: { _ in FakeDDCTransport(lastReadLuminance: nil) },
            displayCandidateProvider: Self.candidate,
            defaults: defaults
        )
        #expect(revived.currentBrightness() == 0.4)
    }

    @Test
    func fallsBackToAssumedBrightnessWhenReadIsGarbage() {
        // Dell Display Manager-style garbage reply: sanity check rejects it.
        let transport = FakeDDCTransport(lastReadLuminance: nil)
        let defaults = makeDefaults()
        let client = DDCBrightnessClient(
            transportProvider: { _ in transport },
            displayCandidateProvider: Self.candidate,
            defaults: defaults
        )

        #expect(client.currentBrightness() == 0.75)
    }

    @Test
    func writesScaledValueAndCachesResult() {
        let transport = FakeDDCTransport(lastReadLuminance: (current: 40, max: 100))
        let defaults = makeDefaults()
        let client = DDCBrightnessClient(
            transportProvider: { _ in transport },
            displayCandidateProvider: Self.candidate,
            defaults: defaults
        )

        #expect(client.setBrightness(0.625) == true)
        #expect(transport.writtenValues == [63])

        // No sane read available anymore → cached written value wins.
        #expect(client.currentBrightness() == 0.625)
        #expect(transport.writeCallCount == 1)
    }

    @Test
    func assumesHundredScaleWhenMaxUnknown() {
        let transport = FakeDDCTransport(lastReadLuminance: nil)
        let client = DDCBrightnessClient(
            transportProvider: { _ in transport },
            displayCandidateProvider: Self.candidate,
            defaults: makeDefaults()
        )

        #expect(client.setBrightness(0.5) == true)
        #expect(transport.writtenValues == [50])
    }

    @Test
    func writeFailureInvalidatesTransportForReResolve() {
        let failing = FakeDDCTransport(lastReadLuminance: nil)
        failing.writeResult = false
        let fresh = FakeDDCTransport(lastReadLuminance: nil)
        var provided: [FakeDDCTransport] = [failing, fresh]
        let client = DDCBrightnessClient(
            transportProvider: { _ in provided.removeFirst() },
            displayCandidateProvider: Self.candidate,
            defaults: makeDefaults()
        )

        #expect(client.setBrightness(0.5) == false)
        #expect(failing.writeCallCount == 1)
        #expect(fresh.writeCallCount == 0)

        #expect(client.setBrightness(0.5) == true)
        #expect(fresh.writtenValues == [50])
    }

    // MARK: - Helpers

    private func makeDefaults() -> UserDefaults {
        let suite = "ddc-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}

@MainActor
private final class FakeDDCTransport: DDCI2CTransport {
    let lastReadLuminance: (current: Int, max: Int)?
    var writeResult = true
    var writeCallCount = 0
    var writtenValues: [UInt16] = []

    init(lastReadLuminance: (current: Int, max: Int)?) {
        self.lastReadLuminance = lastReadLuminance
    }

    func write(value: UInt16) -> Bool {
        writeCallCount += 1
        writtenValues.append(value)
        return writeResult
    }
}

// MARK: - Composite

@MainActor
struct CompositeBrightnessClientTests {
    @Test
    func prefersDisplayServicesWhenControllableDisplayExists() {
        let displayServices = FakeCompositeDisplayServices(hasControllable: true)
        let ddc = DDCBrightnessClient(
            transportProvider: { _ in FakeDDCTransport(lastReadLuminance: (current: 30, max: 100)) },
            displayCandidateProvider: { (displayID: 42, displayKey: "fake") },
            defaults: UserDefaults(suiteName: "composite-tests-\(UUID().uuidString)")!
        )
        let composite = CompositeBrightnessClient(displayServices: displayServices, ddc: ddc)

        #expect(composite.currentBrightness() == 0.5)
        #expect(composite.setBrightness(0.9) == true)
        #expect(displayServices.setArguments == [0.9])
    }

    @Test
    func fallsBackToDDCWhenDisplayServicesHasNothing() {
        // The clamshell case: no built-in panel, DisplayServices refuses externals.
        let displayServices = FakeCompositeDisplayServices(hasControllable: false)
        let transport = FakeDDCTransport(lastReadLuminance: (current: 40, max: 100))
        let ddc = DDCBrightnessClient(
            transportProvider: { _ in transport },
            displayCandidateProvider: { (displayID: 42, displayKey: "fake") },
            defaults: UserDefaults(suiteName: "composite-tests-\(UUID().uuidString)")!
        )
        let composite = CompositeBrightnessClient(displayServices: displayServices, ddc: ddc)

        #expect(composite.currentBrightness() == 0.4)
        #expect(composite.setBrightness(0.5) == true)
        #expect(transport.writtenValues == [50])
        #expect(displayServices.setArguments.isEmpty)
    }
}

@MainActor
private final class FakeCompositeDisplayServices: DisplayServicesBrightnessControlling, DisplayServicesAvailabilityReporting {
    let hasControllable: Bool
    var setArguments: [Float] = []

    init(hasControllable: Bool) {
        self.hasControllable = hasControllable
    }

    func currentBrightness() -> Float? {
        hasControllable ? 0.5 : nil
    }

    func setBrightness(_ brightness: Float) -> Bool {
        setArguments.append(brightness)
        return hasControllable
    }

    func hasControllableDisplay() -> Bool {
        hasControllable
    }
}
