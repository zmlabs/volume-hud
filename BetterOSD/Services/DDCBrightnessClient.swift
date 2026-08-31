//
//  DDCBrightnessClient.swift
//  BetterOSD
//
//  Controls brightness of external displays over DDC/CI (VCP code 0x10) via
//  IOKit's IOAVService transport — the same channel macOS itself uses on
//  Apple Silicon. Needed because DisplayServices.framework only supports
//  built-in panels: with the lid closed (clamshell) it reports no controllable
//  display, which used to make F1/F2 fall through to the system OSD.
//
//  Byte format follows m1ddc (waydabber/m1ddc), field-proven across monitors:
//    write: [0x84, 0x03, vcp, valueHi, valueLo, checksum]  checksum = 0x6e ^ 0x51 ^ b0..b4
//    read:  [0x82, 0x01, vcp, checksum] → reply[6..7] = max, reply[8..9] = current
//
//  DDC reads are unreliable on some setups (e.g. Dell monitors while Dell
//  Display Manager is running answer with garbage), so the client keeps a
//  per-display cache of the last written value, persisted in UserDefaults.
//
//  NOTE: all methods must be called on the main thread (they are invoked from
//  the CGEventTap on the main run loop). DDC I/O includes ~10 ms pacing sleeps.
//

import ApplicationServices
import CoreGraphics
import Darwin
import Foundation
import IOKit

// MARK: - Transport

/// Raw I2C read/write against a display's DCPAVServiceProxy.
/// Abstracted so unit tests can fake the wire.
protocol DDCI2CTransport: AnyObject {
    /// Last known VCP 0x10 reply, sanity-checked. Nil when the display
    /// never answered a sane read (e.g. Dell Display Manager locks reads).
    var lastReadLuminance: (current: Int, max: Int)? { get }
    func write(value: UInt16) -> Bool
}

/// Resolves the transport for a given display. Returns nil when the display
/// has no external DCPAVServiceProxy (built-in panel, virtual display, …).
typealias DDCTransportProvider = (CGDirectDisplayID) -> DDCI2CTransport?

/// Picks the external display to control. Injectable for tests.
typealias DDCDisplayCandidateProvider = () -> (displayID: CGDirectDisplayID, displayKey: String)?

// MARK: - Client

final class DDCBrightnessClient: DisplayServicesBrightnessControlling {
    /// Assumed brightness when nothing is cached and the display won't answer
    /// reads. The very first key press steps from here; every successful write
    /// afterwards re-seeds the cache with the real value.
    private static let assumedBrightness: Float = 0.75
    private static let vcpLuminance: UInt8 = 0x10

    private let transportProvider: DDCTransportProvider
    private let displayCandidateProvider: DDCDisplayCandidateProvider
    private let defaults: UserDefaults

    private var cachedTransport: DDCI2CTransport?
    private var cachedDisplayID: CGDirectDisplayID?
    private var cachedBrightness: Float?

    init(
        transportProvider: @escaping DDCTransportProvider = IOKitDDCTransport.resolve,
        displayCandidateProvider: @escaping DDCDisplayCandidateProvider = DDCBrightnessClient.externalDisplayCandidate,
        defaults: UserDefaults = .standard
    ) {
        self.transportProvider = transportProvider
        self.displayCandidateProvider = displayCandidateProvider
        self.defaults = defaults
    }

    func currentBrightness() -> Float? {
        guard let (displayID, key) = displayCandidateProvider() else {
            return nil
        }

        if let cached = storedBrightness(for: key, displayID: displayID) {
            return cached
        }

        guard let transport = transport(for: displayID) else { return nil }

        if let read = transport.lastReadLuminance, read.max > 0 {
            let normalized = max(0, min(1, Float(read.current) / Float(read.max)))
            cache(normalized, for: key, displayID: displayID)
            return normalized
        }

        // Reads are best-effort: on displays that answer with garbage
        // (DDM-locked Dells, some KVMs) step from an assumed level instead.
        // It is deliberately NOT cached — the next successful write replaces
        // it with the real level.
        return Self.assumedBrightness
    }

    func setBrightness(_ brightness: Float) -> Bool {
        guard let (displayID, key) = displayCandidateProvider(),
              let transport = transport(for: displayID)
        else {
            return false
        }

        let clamped = max(0, min(1, brightness))
        let maxValue = transport.lastReadLuminance?.max ?? 100
        let value = UInt16((Float(maxValue) * clamped).rounded())

        guard transport.write(value: value) else {
            invalidateTransport()
            return false
        }

        cache(clamped, for: key, displayID: displayID)
        return true
    }

    // MARK: - Transport caching

    private func transport(for displayID: CGDirectDisplayID) -> DDCI2CTransport? {
        if let cachedTransport, cachedDisplayID == displayID {
            return cachedTransport
        }

        guard let resolved = transportProvider(displayID) else {
            invalidateTransport()
            return nil
        }

        cachedTransport = resolved
        cachedDisplayID = displayID
        return resolved
    }

    private func invalidateTransport() {
        cachedTransport = nil
        cachedDisplayID = nil
    }

    // MARK: - Brightness cache

    private static func cacheKey(displayKey: String) -> String {
        AppStorageKeys.ddcBrightnessCachePrefix + displayKey
    }

    private func storedBrightness(for displayKey: String, displayID: CGDirectDisplayID) -> Float? {
        if let cachedBrightness, cachedDisplayID == displayID {
            return cachedBrightness
        }
        let key = Self.cacheKey(displayKey: displayKey)
        guard let stored = defaults.object(forKey: key) as? Float else { return nil }
        cachedBrightness = stored
        return stored
    }

    private func cache(_ brightness: Float, for displayKey: String, displayID: CGDirectDisplayID) {
        cachedBrightness = brightness
        defaults.set(brightness, forKey: Self.cacheKey(displayKey: displayKey))
    }

    // MARK: - Display selection

    /// The external display brightness keys should target: the main display
    /// when it is external (the clamshell case), otherwise the first
    /// non-builtin active display.
    nonisolated static func externalDisplayCandidate() -> (displayID: CGDirectDisplayID, displayKey: String)? {
        var activeCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &activeCount)
        var displays = Array(repeating: CGDirectDisplayID(), count: Int(activeCount))
        guard CGGetActiveDisplayList(activeCount, &displays, &activeCount) == .success else {
            return nil
        }

        let mainID = CGMainDisplayID()
        let candidate = (displays.contains(mainID) && CGDisplayIsBuiltin(mainID) == 0)
            ? mainID
            : displays.first { CGDisplayIsBuiltin($0) == 0 }

        guard let id = candidate else { return nil }
        let key = "\(CGDisplayVendorNumber(id)):\(CGDisplayModelNumber(id)):\(CGDisplaySerialNumber(id))"
        return (id, key)
    }
}

// MARK: - IOKit implementation

/// DDC/CI over IOAVService, mirroring m1ddc's registry matching:
/// display → IODisplayLocation → IOMobileFramebuffer → its DCPAVServiceProxy
/// with Location == "External" → IOAVServiceCreateWithService.
nonisolated final class IOKitDDCTransport: DDCI2CTransport {
    private typealias AVServiceCreateWithService = @convention(c) (CFAllocator?, io_service_t) -> CFTypeRef?
    private typealias ReadI2C = @convention(c) (UnsafeMutableRawPointer, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> Int32
    private typealias WriteI2C = @convention(c) (UnsafeMutableRawPointer, UInt32, UInt32, UnsafeRawPointer, UInt32) -> Int32
    private typealias CreateInfoDictionary = @convention(c) (CGDirectDisplayID) -> CFDictionary?

    private static let chipAddressDefault: UInt32 = 0x37
    private static let chipAddressMCDP29XX: UInt32 = 0xB7
    private static let inputAddress: UInt32 = 0x51
    private static let writeIterations = 2
    private static let settleMicroseconds: useconds_t = 10_000

    private let service: CFTypeRef
    private let chipAddress: UInt32
    let lastReadLuminance: (current: Int, max: Int)?

    private static let createWithService: AVServiceCreateWithService? = {
        guard let iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) else { return nil }
        return load(handle: iokit, symbol: "IOAVServiceCreateWithService")
    }()

    private static func load<T>(handle: UnsafeMutableRawPointer, symbol: String) -> T? {
        guard let pointer = dlsym(handle, symbol) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    private init(service: CFTypeRef, chipAddress: UInt32, lastReadLuminance: (current: Int, max: Int)?) {
        self.service = service
        self.chipAddress = chipAddress
        self.lastReadLuminance = lastReadLuminance
    }

    static func resolve(displayID: CGDirectDisplayID) -> DDCI2CTransport? {
        guard let create = createWithService,
              let adapter = adapterEntry(for: displayID)
        else { return nil }

        var iterator = io_iterator_t()
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        guard IORegistryEntryCreateIterator(root, kIOServicePlane, IOOptionBits(1), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var framebufferMatches = false
        while true {
            let entry = IOIteratorNext(iterator)
            guard entry != IO_OBJECT_NULL else { break }
            defer { IOObjectRelease(entry) }

            if IOObjectConformsTo(entry, "IOMobileFramebuffer") != 0 {
                var entryID: UInt64 = 0
                framebufferMatches = IORegistryEntryGetRegistryEntryID(entry, &entryID) == KERN_SUCCESS
                    && entryID == adapter.registryEntryID
                continue
            }

            guard framebufferMatches, registryEntryName(entry) == "DCPAVServiceProxy" else { continue }
            guard registryStringProperty(entry, "Location") == "External" else { continue }

            let chipAddress = isMCDP29XX(entry) ? chipAddressMCDP29XX : chipAddressDefault
            guard let service = create(kCFAllocatorDefault, entry) else { continue }

            let read = readLuminance(service: service, chipAddress: chipAddress)
            return IOKitDDCTransport(service: service, chipAddress: chipAddress, lastReadLuminance: read)
        }

        return nil
    }

    // MARK: - Registry matching

    private struct AdapterEntry {
        var registryEntryID: UInt64
    }

    private static func adapterEntry(for displayID: CGDirectDisplayID) -> AdapterEntry? {
        guard let coreDisplay = dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_NOW),
              let createInfo: CreateInfoDictionary = load(handle: coreDisplay, symbol: "CoreDisplay_DisplayCreateInfoDictionary"),
              let info = createInfo(displayID),
              let location = (info as NSDictionary)["IODisplayLocation"] as? String
        else { return nil }

        let entry = IORegistryEntryCopyFromPath(kIOMainPortDefault, location as CFString)
        guard entry != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(entry) }

        var entryID: UInt64 = 0
        guard IORegistryEntryGetRegistryEntryID(entry, &entryID) == KERN_SUCCESS else { return nil }
        return AdapterEntry(registryEntryID: entryID)
    }

    private static func registryEntryName(_ entry: io_object_t) -> String {
        var buffer = [CChar](repeating: 0, count: 128)
        return buffer.withUnsafeMutableBufferPointer { buf -> String in
            IORegistryEntryGetName(entry, buf.baseAddress)
            return String(cString: buf.baseAddress!)
        }
    }

    private static func registryStringProperty(_ entry: io_object_t, _ key: String) -> String? {
        IORegistryEntrySearchCFProperty(entry, kIOServicePlane, key as CFString, kCFAllocatorDefault, 0) as? String
    }

    private static func isMCDP29XX(_ entry: io_object_t) -> Bool {
        var parent = io_registry_entry_t()
        guard IORegistryEntryGetParentEntry(entry, kIOServicePlane, &parent) == KERN_SUCCESS else { return false }
        defer { IOObjectRelease(parent) }

        return registryStringProperty(parent, "EPICProviderClass") == "AppleDCPMCDP29XX"
    }

    // MARK: - DDC/CI

    /// One-shot luminance read performed while resolving. Sanity-checked:
    /// garbage replies (Dell Display Manager locks reads) return nil.
    private static func readLuminance(service: CFTypeRef, chipAddress: UInt32) -> (current: Int, max: Int)? {
        guard let iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW),
              let read: ReadI2C = load(handle: iokit, symbol: "IOAVServiceReadI2C")
        else { return nil }

        var request = [UInt8](repeating: 0, count: 4)
        request[0] = 0x82
        request[1] = 0x01
        request[2] = 0x10
        request[3] = 0x6e ^ request[0] ^ request[1] ^ request[2]

        var reply = [UInt8](repeating: 0, count: 12)
        usleep(settleMicroseconds)
        let pointer = Unmanaged.passUnretained(service).toOpaque()
        guard read(pointer, chipAddress, inputAddress, &reply, 12) == 0 else { return nil }

        let maxValue = (Int(reply[6]) << 8) | Int(reply[7])
        let currentValue = (Int(reply[8]) << 8) | Int(reply[9])
        guard maxValue > 0, maxValue <= 1000, currentValue >= 0, currentValue <= maxValue else { return nil }
        return (currentValue, maxValue)
    }

    func write(value: UInt16) -> Bool {
        guard let iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW),
              let write: WriteI2C = Self.load(handle: iokit, symbol: "IOAVServiceWriteI2C")
        else { return false }

        var packet: [UInt8] = [0x84, 0x03, 0x10, UInt8(value >> 8), UInt8(value & 0xFF), 0]
        packet[5] = 0x6e ^ 0x51 ^ packet[0] ^ packet[1] ^ packet[2] ^ packet[3] ^ packet[4]

        let pointer = Unmanaged.passUnretained(service).toOpaque()
        // Two iterations, as in m1ddc: some panels silently drop single writes.
        for _ in 0 ..< Self.writeIterations {
            usleep(Self.settleMicroseconds)
            if write(pointer, chipAddress, Self.inputAddress, packet, 6) != 0 {
                return false
            }
        }
        return true
    }
}
