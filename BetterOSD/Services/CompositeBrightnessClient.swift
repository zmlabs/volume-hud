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

import Foundation

/// Lets the composite probe DisplayServices availability without going
/// through a full brightness read.
protocol DisplayServicesAvailabilityReporting: AnyObject {
    func hasControllableDisplay() -> Bool
}

extension DisplayServicesBrightnessClient: DisplayServicesAvailabilityReporting {}

final class CompositeBrightnessClient: DisplayServicesBrightnessControlling {
    private let displayServices: any DisplayServicesBrightnessControlling & DisplayServicesAvailabilityReporting
    private let ddc: DDCBrightnessClient

    init(
        displayServices: any DisplayServicesBrightnessControlling & DisplayServicesAvailabilityReporting = DisplayServicesBrightnessClient(),
        ddc: DDCBrightnessClient = DDCBrightnessClient()
    ) {
        self.displayServices = displayServices
        self.ddc = ddc
    }

    func currentBrightness() -> Float? {
        displayServices.hasControllableDisplay()
            ? displayServices.currentBrightness()
            : ddc.currentBrightness()
    }

    func setBrightness(_ brightness: Float) -> Bool {
        displayServices.hasControllableDisplay()
            ? displayServices.setBrightness(brightness)
            : ddc.setBrightness(brightness)
    }
}
