//
//  MediaKeyMonitor.swift
//  BetterOSD
//
//  Created by yu on 2026/1/6.
//

import AppKit
import ApplicationServices
import Combine

final class MediaKeyMonitor {
    enum MediaKey: Int {
        case soundUp = 0
        case soundDown = 1
        case brightnessUp = 2
        case brightnessDown = 3
        case mute = 7
    }

    static let shared = MediaKeyMonitor()

    let mediaKeyPublisher = PassthroughSubject<MediaKey, Never>()

    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var eventTapRunLoop: CFRunLoop?
    private let volumeKeyController = VolumeKeyController()
    private var accessibilityPollTask: Task<Void, Never>?

    private init() {}

    func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        guard !hasAccessibilityPermission() else { return }
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true as CFBoolean] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func startAccessibilityPolling(interval: TimeInterval = 1.0, maxAttempts: Int = 60) {
        guard maxAttempts > 0 else { return }

        accessibilityPollTask?.cancel()
        accessibilityPollTask = Task { [weak self] in
            guard let self else { return }

            for _ in 0 ..< maxAttempts {
                if hasAccessibilityPermission() {
                    _ = start(promptAccessibility: false)
                    break
                }

                if Task.isCancelled { break }
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    @discardableResult
    func start(promptAccessibility: Bool = false) -> Bool {
        if eventTap != nil {
            return true
        }

        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: promptAccessibility as CFBoolean] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { return false }

        let mask = CGEventMask(1 << UInt64(NSEvent.EventType.systemDefined.rawValue))
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.eventTapCallback,
            userInfo: refcon
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        let runLoop = CFRunLoopGetMain()
        CFRunLoopAddSource(runLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        eventTapSource = source
        eventTapRunLoop = runLoop

        return true
    }

    func stop() {
        accessibilityPollTask?.cancel()
        let source = eventTapSource
        let runLoop = eventTapRunLoop
        let tap = eventTap
        eventTap = nil
        eventTapSource = nil
        eventTapRunLoop = nil

        if let source, let runLoop {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
            CFRunLoopSourceInvalidate(source)
        }
        if let tap {
            CFMachPortInvalidate(tap)
        }
    }

    private func enableEventTap() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else {
            return Unmanaged.passRetained(event)
        }

        let monitor = Unmanaged<MediaKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            monitor.enableEventTap()
            return Unmanaged.passRetained(event)
        }

        return monitor.handle(event)
    }

    private func handle(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passRetained(event)
        }

        guard nsEvent.type == .systemDefined, nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passRetained(event)
        }

        let data1 = nsEvent.data1
        let keyCode = Int((data1 & 0xFFFF_0000) >> 16)
        let flags = Int(data1 & 0x0000_FFFF)

        let keyState = (flags & 0xFF00) >> 8
        let isDown = (keyState == 0x0A)
        guard isDown else { return Unmanaged.passRetained(event) }

        guard let mk = MediaKey(rawValue: keyCode) else {
            return Unmanaged.passRetained(event)
        }

        let modifiers = nsEvent.modifierFlags
        let handlingResult = handleMediaKey(mk, modifiers: modifiers)

        switch handlingResult {
        case .passThrough:
            return Unmanaged.passRetained(event)
        case let .consumed(didChange):
            if !didChange {
                mediaKeyPublisher.send(mk)
            }
            return nil
        }
    }

    private func handleMediaKey(_ key: MediaKey, modifiers: NSEvent.ModifierFlags) -> MediaKeyHandlingResult {
        switch key {
        case .soundUp, .soundDown, .mute:
            let fineStep = modifiers.contains(.shift) && modifiers.contains(.option)
            return volumeKeyController.handle(key, fineStep: fineStep)
        case .brightnessUp, .brightnessDown:
            return .passThrough
        }
    }
}
