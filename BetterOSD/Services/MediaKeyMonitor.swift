//
//  MediaKeyMonitor.swift
//  BetterOSD
//
//  Created by yu on 2026/1/6.
//

import AppKit
import ApplicationServices

protocol BrightnessKeyHandling: AnyObject {
    var currentState: BrightnessState { get }
    func handle(_ key: MediaKeyMonitor.MediaKey, fineStep: Bool) -> MediaKeyHandlingResult
}

extension BrightnessKeyController: BrightnessKeyHandling {}

final class MediaKeyMonitor {
    enum MediaKey: Int {
        case soundUp = 0
        case soundDown = 1
        case brightnessUp = 2
        case brightnessDown = 3
        case mute = 7
    }

    static let shared = MediaKeyMonitor()

    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var eventTapRunLoop: CFRunLoop?
    private let volumeKeyController: VolumeKeyHandling
    private let brightnessKeyController: BrightnessKeyHandling
    private let hudStore: HUDDisplayStateStore
    private var accessibilityPollTask: Task<Void, Never>?

    private static let brightnessUpKeyCode: Int64 = 144
    private static let brightnessDownKeyCode: Int64 = 145

    init(
        volumeKeyController: VolumeKeyHandling = VolumeKeyController(),
        brightnessKeyController: BrightnessKeyHandling = BrightnessKeyController(),
        hudStore: HUDDisplayStateStore = .shared
    ) {
        self.volumeKeyController = volumeKeyController
        self.brightnessKeyController = brightnessKeyController
        self.hudStore = hudStore
    }

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

        let mask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
                (1 << UInt64(NSEvent.EventType.systemDefined.rawValue))
        )
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
            return Unmanaged.passUnretained(event)
        }

        let monitor = Unmanaged<MediaKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            monitor.enableEventTap()
            return Unmanaged.passUnretained(event)
        }

        return monitor.handle(event)
    }

    private func handle(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        if event.type == .keyDown {
            return handleBrightnessKeyDown(event)
        }
        return handleSystemDefinedMediaKey(event)
    }

    private func handleBrightnessKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        let mediaKey: MediaKey
        switch keyCode {
        case Self.brightnessUpKeyCode:
            mediaKey = .brightnessUp
        case Self.brightnessDownKeyCode:
            mediaKey = .brightnessDown
        default:
            return Unmanaged.passUnretained(event)
        }

        let modifiers = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
        return applyResult(handleMediaKey(mediaKey, modifiers: modifiers), event: event)
    }

    private func handleSystemDefinedMediaKey(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passUnretained(event)
        }

        guard nsEvent.type == .systemDefined, nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passUnretained(event)
        }

        let data1 = nsEvent.data1
        let keyCode = Int((data1 & 0xFFFF_0000) >> 16)
        let flags = Int(data1 & 0x0000_FFFF)

        let keyState = (flags & 0xFF00) >> 8
        guard keyState == 0x0A else { return Unmanaged.passUnretained(event) }

        guard let mk = MediaKey(rawValue: keyCode) else {
            return Unmanaged.passUnretained(event)
        }

        return applyResult(handleMediaKey(mk, modifiers: nsEvent.modifierFlags), event: event)
    }

    private func applyResult(_ result: MediaKeyHandlingResult, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch result {
        case .passThrough:
            Unmanaged.passUnretained(event)
        case .consumed:
            nil
        }
    }

    func handleMediaKeyForTesting(_ key: MediaKey, modifiers: NSEvent.ModifierFlags) -> MediaKeyHandlingResult {
        handleMediaKey(key, modifiers: modifiers)
    }

    private func handleMediaKey(_ key: MediaKey, modifiers: NSEvent.ModifierFlags) -> MediaKeyHandlingResult {
        let fineStep = modifiers.contains(.shift) && modifiers.contains(.option)

        switch key {
        case .soundUp, .soundDown, .mute:
            return volumeKeyController.handle(key, fineStep: fineStep)

        case .brightnessUp, .brightnessDown:
            let result = brightnessKeyController.handle(key, fineStep: fineStep)
            if case .consumed = result {
                hudStore.update(brightnessKeyController.currentState.displayState)
            }
            return result
        }
    }
}
