//
//  HIDUtilRemapper.swift
//  BetterOSD
//

import Foundation

// Applies / removes a hidutil UserKeyMapping that redirects the physical
// keyboard-brightness keys (F5/F6) to Dictation and Do Not Disturb at the
// keyDown level, while leaving the NX systemDefined illumination events (21/22)
// intact so BetterOSD can intercept them for the brightness OSD.
//
// The mapping is volatile — it resets on reboot.  BetterOSD re-applies it at
// every launch when the keyboard-backlight OSD is enabled with the standard
// F5/F6 assignment, so no separate LaunchAgent is needed.
enum HIDUtilRemapper {

    // MARK: - HID usage codes

    // Src: Consumer page (0x0C) usage 0xCF  — Keyboard Brightness Down (F5)
    // Dst: Vendor page  (0xFF) usage 0x09   — Dictation
    // Src: Generic Desktop (0x01) usage 0x9B — Keyboard Brightness Up (F6)
    // Dst: Vendor page  (0xFF) usage 0x08   — Do Not Disturb
    private static let mapping = """
    {"UserKeyMapping":[\
    {"HIDKeyboardModifierMappingSrc":0xC000000CF,"HIDKeyboardModifierMappingDst":0xFF00000009},\
    {"HIDKeyboardModifierMappingSrc":0x10000009B,"HIDKeyboardModifierMappingDst":0xFF00000008}\
    ]}
    """

    // MARK: - Public API

    /// Redirects F5 → Dictation and F6 → DND at the keyDown level.
    /// Dispatched to a background queue — does not block the main thread.
    static func applyF5F6Remapping() {
        run(args: ["property", "--set", mapping])
    }

    /// Removes all user key remapping, restoring system defaults.
    /// Dispatched to a background queue — does not block the main thread.
    static func clearRemapping() {
        run(args: ["property", "--set", #"{"UserKeyMapping":[]}"#])
    }

    // MARK: - Private

    private static func run(args: [String]) {
        // hidutil typically completes in < 50 ms; fire-and-forget on a background queue.
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
            task.arguments = args
            task.standardOutput = FileHandle.nullDevice
            task.standardError  = FileHandle.nullDevice
            try? task.run()
            task.waitUntilExit()
        }
    }
}
