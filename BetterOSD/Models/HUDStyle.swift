//
//  HUDStyle.swift
//  BetterOSD
//
//  Created by yu on 2025/9/23.
//

import Foundation

/// Available HUD styles
enum HUDStyle: String, CaseIterable, Identifiable {
    case classic
    case modern

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .classic:
            NSLocalizedString("Classic", comment: "Classic")
        case .modern:
            NSLocalizedString("Modern", comment: "Modern")
        }
    }
}

/// AppStorage keys for user preferences
enum AppStorageKeys {
    static let hudStyle = "hudStyle"
    static let showInMenuBar = "showInMenuBar"
    static let liquidGlassEnable = "liquidGlassEnable"
    static let bottomOffset = "bottomOffset"
    static let glassVariant = "glassVariant"
    static let accessibilityPrompted = "accessibilityPrompted"

    // External display brightness via DDC/CI ("ddcBrightness.<vendor>:<model>:<serial>")
    static let ddcBrightnessCachePrefix = "ddcBrightness."

    // Keyboard backlight OSD
    static let keyboardBacklightEnabled = "keyboardBacklightEnabled"
    static let keyboardBrightnessUpCode = "keyboardBrightnessUpCode"
    static let keyboardBrightnessDownCode = "keyboardBrightnessDownCode"
    // "f5f6" | "cmdF1F2" | "" (not configured)
    static let keyboardBrightnessKeyMode = "keyboardBrightnessKeyMode"
}
