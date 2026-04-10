//
//  DisplayServicesBrightnessClient.swift
//  BetterOSD
//
//  Created by yu on 2026/4/11.
//

import ApplicationServices
import Darwin
import Foundation

protocol DisplayServicesBrightnessControlling: AnyObject {
    func currentBrightness() -> Float?
    func setBrightness(_ brightness: Float) -> Bool
}

final class DisplayServicesBrightnessClient: DisplayServicesBrightnessControlling {
    private typealias CanChangeBrightness = @convention(c) (CGDirectDisplayID) -> Bool
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let frameworkPath = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
    private nonisolated(unsafe) var handle: UnsafeMutableRawPointer?
    private var canChangeBrightness: CanChangeBrightness?
    private var getBrightnessFn: GetBrightness?
    private var setBrightnessFn: SetBrightness?

    func currentBrightness() -> Float? {
        guard let displayID = firstControllableDisplayID(),
              let getBrightnessFn else {
            return nil
        }

        var value: Float = 0
        guard getBrightnessFn(displayID, &value) == 0 else { return nil }
        return max(0, min(1, value))
    }

    func setBrightness(_ brightness: Float) -> Bool {
        guard let displayID = firstControllableDisplayID(),
              let setBrightnessFn else {
            return false
        }

        return setBrightnessFn(displayID, max(0, min(1, brightness))) == 0
    }

    private func firstControllableDisplayID() -> CGDirectDisplayID? {
        guard resolveSymbolsIfNeeded(),
              let canChangeBrightness else {
            return nil
        }

        var activeCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &activeCount)
        var displays = Array(repeating: CGDirectDisplayID(), count: Int(activeCount))
        let status = CGGetActiveDisplayList(activeCount, &displays, &activeCount)

        guard status == .success else { return nil }
        return displays.first(where: { canChangeBrightness($0) })
    }

    private func resolveSymbolsIfNeeded() -> Bool {
        if getBrightnessFn != nil, setBrightnessFn != nil, canChangeBrightness != nil {
            return true
        }

        guard handle == nil else { return false }
        handle = dlopen(frameworkPath, RTLD_NOW)

        guard let handle else { return false }

        canChangeBrightness = load(handle: handle, symbol: "DisplayServicesCanChangeBrightness")
        getBrightnessFn = load(handle: handle, symbol: "DisplayServicesGetBrightness")
        setBrightnessFn = load(handle: handle, symbol: "DisplayServicesSetBrightness")

        return canChangeBrightness != nil && getBrightnessFn != nil && setBrightnessFn != nil
    }

    private func load<T>(handle: UnsafeMutableRawPointer, symbol: String) -> T? {
        guard let pointer = dlsym(handle, symbol) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    deinit {
        if let handle {
            dlclose(handle)
        }
    }
}
