//
//  MediaKeyMonitor.swift
//  BetterOSD
//
//  Created by yu on 2026/1/6.
//

import AppKit
import ApplicationServices
@preconcurrency import Combine

final class MediaKeyMonitor {
    enum MediaKey: Int {
        case soundUp = 0
        case soundDown = 1
        case brightnessUp = 2
        case brightnessDown = 3
    }

    static let shared = MediaKeyMonitor()

    let mediaKeyPublisher = PassthroughSubject<MediaKey, Never>()

    private var globalMonitor: Any?
    private var localMonitor: Any?

    private init() {}

    func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    @MainActor
    func requestAccessibilityPermission() {
        guard !hasAccessibilityPermission() else { return }

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Allow Accessibility Access"
        alert.informativeText = "BetterOSD needs this to listen for media keys. Open System Settings and enable BetterOSD."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Not Now")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }

        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true as CFBoolean] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    func start() -> Bool {
        if globalMonitor != nil || localMonitor != nil {
            return true
        }

        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true as CFBoolean] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { return false }

        let mask: NSEvent.EventTypeMask = [.systemDefined]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
            return event
        }

        return true
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        guard event.type == .systemDefined, event.subtype.rawValue == 8 else { return }

        let data1 = event.data1
        let keyCode = Int((data1 & 0xFFFF_0000) >> 16)
        let flags = Int(data1 & 0x0000_FFFF)

        let keyState = (flags & 0xFF00) >> 8
        let isDown = (keyState == 0x0A)
        guard isDown else { return }

        guard let mk = MediaKey(rawValue: keyCode) else { return }
        mediaKeyPublisher.send(mk)
    }
}
