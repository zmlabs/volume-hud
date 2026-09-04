//
//  CompositeBrightnessClient.swift
//  BetterOSD
//
//  Picks the brightness backend per call, so lid state changes (clamshell)
//  are handled without restarts:
//    1. DisplayServices.framework — built-in panel (present whenever the lid
//       is open); also any external display macOS natively supports.
//    2. DDC/CI over IOAVService — external monitors DisplayServices can't
//       control (the common clamshell case, verified against a Dell monitor
//       on macOS 26: CanChangeBrightness = false, SetBrightness is a no-op).
//

import CoreGraphics
import Foundation

/// Lets the composite probe DisplayServices availability without going
/// through a full brightness read.
protocol DisplayServicesAvailabilityReporting: AnyObject {
    func hasControllableDisplay() -> Bool
    func canControl(displayID: CGDirectDisplayID) -> Bool
}

extension DisplayServicesBrightnessClient: DisplayServicesAvailabilityReporting {}

final class CompositeBrightnessClient: DisplayServicesBrightnessControlling, TargetedBrightnessControlling {
    private let displayServices: any DisplayServicesBrightnessControlling & DisplayServicesAvailabilityReporting & TargetedBrightnessControlling
    private let ddc: DDCBrightnessClient
    /// Every display the bare (no-⇧) sweep should drive. Injectable for tests.
    private let activeDisplays: () -> [CGDirectDisplayID]

    init(
        displayServices: any DisplayServicesBrightnessControlling & DisplayServicesAvailabilityReporting & TargetedBrightnessControlling = DisplayServicesBrightnessClient(),
        ddc: DDCBrightnessClient = DDCBrightnessClient(),
        activeDisplays: @escaping () -> [CGDirectDisplayID] = { CompositeBrightnessClient.systemActiveDisplayIDs() }
    ) {
        self.displayServices = displayServices
        self.ddc = ddc
        self.activeDisplays = activeDisplays
    }

    func currentBrightness() -> Float? {
        displayServices.hasControllableDisplay()
            ? displayServices.currentBrightness()
            : ddc.currentBrightness()
    }

    /// Bare brightness keys sweep every display at once, like the system
    /// OSD: DisplayServices where macOS can drive the panel, DDC for the rest.
    func setBrightness(_ brightness: Float) -> Bool {
        var anySuccess = false
        for displayID in activeDisplays() {
            let success = displayServices.canControl(displayID: displayID)
                ? displayServices.setBrightness(brightness, ofDisplay: displayID)
                : ddc.setBrightness(brightness, ofDisplay: displayID)
            anySuccess = anySuccess || success
        }
        return anySuccess
    }

    private static func systemActiveDisplayIDs() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = Array(repeating: CGDirectDisplayID(), count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids
    }

    // MARK: - Per-display routing (⇧+brightness path)
    //
    // DisplayServices when macOS can drive that specific display (built-in
    // panel, natively supported or AirPlay/Sidecar virtual), DDC otherwise.

    func currentBrightness(ofDisplay displayID: CGDirectDisplayID) -> Float? {
        displayServices.canControl(displayID: displayID)
            ? displayServices.currentBrightness(ofDisplay: displayID)
            : ddc.currentBrightness(ofDisplay: displayID)
    }

    func setBrightness(_ brightness: Float, ofDisplay displayID: CGDirectDisplayID) -> Bool {
        displayServices.canControl(displayID: displayID)
            ? displayServices.setBrightness(brightness, ofDisplay: displayID)
            : ddc.setBrightness(brightness, ofDisplay: displayID)
    }
}
