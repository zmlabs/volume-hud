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

    var id: String { rawValue }

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
    static let launchAtLogin = "launchAtLogin"
    static let showInMenuBar = "showInMenuBar"
    static let liquidGlassEnable = "liquidGlassEnable"
    static let bottomOffset = "bottomOffset"
    static let glassVariant = "glassVariant"
}
