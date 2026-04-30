//
//  KeyboardBrightnessClient.swift
//  BetterOSD
//

import Darwin
import Foundation
import ObjectiveC
import os

protocol KeyboardBrightnessControlling: AnyObject {
    func currentBrightness() -> Float?
    func setBrightness(_ brightness: Float, fadeSpeed: Int32) -> Bool
}

extension KeyboardBrightnessControlling {
    func setBrightness(_ brightness: Float) -> Bool {
        setBrightness(brightness, fadeSpeed: KeyboardBrightnessClient.defaultFadeSpeedMs)
    }
}

// Reads and writes keyboard backlight brightness via CoreBrightness.framework's
// KeyboardBrightnessClient ObjC class.
//
// Private API access strategy:
//   1. dlopen the framework (no-op when already in dyld shared cache, but ensures linkage)
//   2. Resolve the ObjC class at runtime — never import the header
//   3. Cast IMPs to explicit @convention(c) types — no raw UnsafeRawPointer juggling
//   4. Discover the built-in keyboard ID dynamically via copyKeyboardBacklightIDs /
//      isKeyboardBuiltIn: instead of assuming ID = 1
//
// Fails fast (init? returns nil) when:
//   - CoreBrightness is unavailable (non-Mac platforms, Simulator)
//   - Required selectors are missing (private API changed)
//   - No keyboard with backlight is found (Mac Mini, external-only setup)
final class KeyboardBrightnessClient: KeyboardBrightnessControlling {

    // MARK: - Private API constants

    private static let frameworkPath =
        "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"
    private static let className = "KeyboardBrightnessClient"

    static let defaultFadeSpeedMs: Int32 = 350   // matches native manual-control fade

    // MARK: - Function pointer types

    private typealias GetFn     = @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias SetFn     = @convention(c) (AnyObject, Selector, Float, Int32, Bool, UInt64) -> Void
    private typealias CopyIDsFn = @convention(c) (AnyObject, Selector) -> NSArray?
    private typealias BuiltInFn = @convention(c) (AnyObject, Selector, UInt64) -> Bool

    // MARK: - State

    private let client: NSObject
    private let getFn: GetFn
    private let setFn: SetFn
    private let getSel: Selector
    private let setSel: Selector
    let keyboardID: UInt64   // internal(set) exposed for diagnostics

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "dev.zhangyu.volume-hud",
        category: "KeyboardBrightness"
    )

    // MARK: - Init

    init?() {
        // dlopen: CoreBrightness lives in the dyld shared cache on macOS 12+.
        // The call may return a non-nil handle even when the path points to a stub.
        // We continue regardless — NSClassFromString is the authoritative check.
        let handle = dlopen(Self.frameworkPath, RTLD_NOW | RTLD_LOCAL)
        if handle == nil {
            let err = dlerror().map { String(cString: $0) } ?? "unknown"
            Self.logger.error("dlopen CoreBrightness failed: \(err, privacy: .public) — relying on dyld cache")
        }

        guard let cls = NSClassFromString(Self.className) as? NSObject.Type else {
            Self.logger.error("Class \(Self.className, privacy: .public) not found")
            return nil
        }

        let obj = cls.init()
        let objClass = type(of: obj)

        let get = NSSelectorFromString("brightnessForKeyboard:")
        let set = NSSelectorFromString("setBrightness:fadeSpeed:commit:forKeyboard:")

        guard let getImp = class_getMethodImplementation(objClass, get) else {
            Self.logger.error("IMP for brightnessForKeyboard: not found")
            return nil
        }
        guard let setImp = class_getMethodImplementation(objClass, set) else {
            Self.logger.error("IMP for setBrightness:fadeSpeed:commit:forKeyboard: not found")
            return nil
        }

        client = obj
        getFn = unsafeBitCast(getImp, to: GetFn.self)
        setFn = unsafeBitCast(setImp, to: SetFn.self)
        getSel = get
        setSel = set

        // Resolve built-in keyboard ID; fall back to 1 if discovery APIs are absent.
        let resolved = Self.discoverBuiltInID(client: obj, objClass: objClass)
        let candidateID = resolved ?? 1

        // Probe: a return value < 0 means this ID has no backlight.
        let probe = unsafeBitCast(getImp, to: GetFn.self)(obj, get, candidateID)
        guard probe >= 0 else {
            Self.logger.info("No keyboard backlight on ID \(candidateID) (probe=\(probe, format: .fixed(precision: 3))) — passthrough mode")
            return nil
        }

        keyboardID = candidateID
        Self.logger.info("Initialized: keyboard ID=\(candidateID) brightness=\(probe, format: .fixed(precision: 3))")
    }

    // MARK: - KeyboardBrightnessControlling

    func currentBrightness() -> Float? {
        let raw = getFn(client, getSel, keyboardID)
        guard raw >= 0 else {
            Self.logger.debug("currentBrightness: invalid \(raw, format: .fixed(precision: 3)) for ID \(self.keyboardID)")
            return nil
        }
        return max(0, min(1, raw))
    }

    @discardableResult
    func setBrightness(_ brightness: Float) -> Bool {
        setBrightness(brightness, fadeSpeed: Self.defaultFadeSpeedMs)
    }

    @discardableResult
    func setBrightness(_ brightness: Float, fadeSpeed: Int32) -> Bool {
        setFn(client, setSel, max(0, min(1, brightness)), fadeSpeed, true, keyboardID)
        return true
    }

    // MARK: - Keyboard ID discovery

    private static func discoverBuiltInID(client: NSObject, objClass: AnyClass) -> UInt64? {
        let copyIDsSel   = NSSelectorFromString("copyKeyboardBacklightIDs")
        let isBuiltInSel = NSSelectorFromString("isKeyboardBuiltIn:")

        guard let copyImp    = class_getMethodImplementation(objClass, copyIDsSel),
              let builtInImp = class_getMethodImplementation(objClass, isBuiltInSel)
        else {
            Self.logger.info("Discovery selectors unavailable — falling back to ID 1")
            return nil
        }

        let copyFn    = unsafeBitCast(copyImp,    to: CopyIDsFn.self)
        let builtInFn = unsafeBitCast(builtInImp, to: BuiltInFn.self)

        guard let ids = copyFn(client, copyIDsSel), ids.count > 0 else {
            Self.logger.info("copyKeyboardBacklightIDs returned empty")
            return nil
        }

        // Prefer the first ID marked as built-in.
        for case let id as UInt64 in ids where builtInFn(client, isBuiltInSel, id) {
            Self.logger.info("Discovered built-in keyboard ID \(id)")
            return id
        }

        // No built-in flag found; use first ID as best-effort.
        if let first = ids.firstObject as? UInt64 {
            Self.logger.info("No built-in flag found; using first ID \(first)")
            return first
        }

        return nil
    }
}
