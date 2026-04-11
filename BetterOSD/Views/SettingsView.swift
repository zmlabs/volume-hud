//
//  SettingsView.swift
//  BetterOSD
//
//  Created by yu on 2025/9/23.
//

import AppKit
import Combine
import LaunchAtLogin
import SwiftUI

enum SettingsPreviewType: String, CaseIterable, Identifiable {
    case volume
    case brightness

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .volume: NSLocalizedString("Volume", comment: "Volume")
        case .brightness: NSLocalizedString("Brightness", comment: "Brightness")
        }
    }

    var placeholderState: HUDDisplayState {
        switch self {
        case .volume:
            HUDDisplayState(iconName: "speaker.wave.2.fill", level: 0.5, isMuted: false)
        case .brightness:
            HUDDisplayState(iconName: "sun.max.fill", level: 0.7, isMuted: false)
        }
    }
}

enum GlassVariantOption: Int, CaseIterable, Identifiable {
    case regular = 0
    case clear = 1
    case dock = 2
    case appIcons = 3
    case notificationCenter = 9
    case bubbles = 11
    case focusBorder = 12

    var id: Int {
        rawValue
    }

    var displayName: String {
        switch self {
        case .regular: "Regular"
        case .clear: "Clear"
        case .dock: "Dock"
        case .appIcons: "AppIcons"
        case .notificationCenter: "NotificationCenter"
        case .bubbles: "Bubbles"
        case .focusBorder: "FocusBorder"
        }
    }
}

struct SettingsView: View {
    @AppStorage(AppStorageKeys.hudStyle) private var hudStyle: HUDStyle = .modern
    @AppStorage(AppStorageKeys.showInMenuBar) private var showInMenuBar: Bool = true
    @AppStorage(AppStorageKeys.liquidGlassEnable) private var liquidGlassEnable: Bool = true
    @AppStorage(AppStorageKeys.bottomOffset) private var bottomOffset: Double = 120
    @AppStorage(AppStorageKeys.glassVariant) private var glassVariant: Int = 0

    @State private var previewType: SettingsPreviewType = .volume
    @State private var accessibilityGranted = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !accessibilityGranted {
                    AccessibilityPermissionBanner {
                        MediaKeyMonitor.shared.requestAccessibilityPermission()
                        MediaKeyMonitor.shared.startAccessibilityPolling()
                        refreshAccessibilityStatus()
                    }
                }

                previewSection
                appearanceSection
                generalSection
            }
            .padding(24)
        }
        .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        .safeAreaBar(edge: .bottom) {
            footerBar
        }
        .frame(width: 520)
        .onAppear { refreshAccessibilityStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAccessibilityStatus()
        }
    }

    private var previewSection: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.gray.opacity(0.1))

                previewHUD
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Picker("Preview", selection: $previewType) {
                ForEach(SettingsPreviewType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private var previewHUD: some View {
        let state = previewType.placeholderState
        switch hudStyle {
        case .classic:
            ClassicHUDView(
                displayState: state,
                liquidGlassEnable: liquidGlassEnable,
                glassVariant: glassVariant
            )
            .scaleEffect(0.72)
        case .modern:
            ModernHUDView(
                displayState: state,
                liquidGlassEnable: liquidGlassEnable,
                glassVariant: glassVariant
            )
            .scaleEffect(0.85)
        }
    }

    private var appearanceSection: some View {
        SettingsSection(title: NSLocalizedString("Appearance", comment: "Appearance")) {
            VStack(spacing: 0) {
                SettingsRow {
                    Text("HUD Style")
                    Spacer()
                    Picker("HUD Style", selection: $hudStyle) {
                        ForEach(HUDStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                SettingsDivider()

                SettingsRow {
                    Text("Liquid Glass")
                    Spacer()
                    Toggle("", isOn: $liquidGlassEnable)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.small)
                        .onChange(of: liquidGlassEnable) { _, _ in
                            HUDPreviewManager.shared.isPreviewActive = true
                            HUDPreviewManager.shared.isPreviewActive = false
                        }
                }

                if liquidGlassEnable {
                    SettingsDivider()

                    SettingsRow {
                        Text("Glass Variant")
                        Spacer()
                        Picker("", selection: $glassVariant) {
                            ForEach(GlassVariantOption.allCases) { option in
                                Text(option.displayName).tag(option.rawValue)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: glassVariant) { _, _ in
                            HUDPreviewManager.shared.isPreviewActive = true
                            HUDPreviewManager.shared.isPreviewActive = false
                        }
                    }
                }

                SettingsDivider()

                SettingsRow {
                    Text("Bottom Offset")
                    Spacer()
                    Slider(value: $bottomOffset, in: 50 ... 220, onEditingChanged: { editing in
                        HUDPreviewManager.shared.isPreviewActive = editing
                    })
                    .frame(width: 160)
                    .onChange(of: bottomOffset) { _, newValue in
                        HUDPreviewManager.shared.bottomOffset = newValue
                    }
                }
            }
        }
    }

    private var generalSection: some View {
        SettingsSection(title: NSLocalizedString("General", comment: "General")) {
            VStack(spacing: 0) {
                SettingsRow {
                    Text("Launch at Login")
                    Spacer()
                    LaunchAtLogin.Toggle()
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.small)
                }

                SettingsDivider()

                SettingsRow {
                    Text("Show in Menu Bar")
                    Spacer()
                    Toggle("", isOn: $showInMenuBar)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.small)
                        .onChange(of: showInMenuBar) { _, newValue in
                            if let delegate = NSApplication.shared.delegate as? AppDelegate {
                                delegate.updateMenuBarVisibility(visible: newValue)
                            }
                        }
                }
            }
        }
    }

    private var footerBar: some View {
        HStack(spacing: 5) {
            Link("Open Source", destination: URL(string: "https://github.com/zmlabs/better-osd")!)
            Text("·")
            Link("Privacy", destination: URL(string: "https://zmlabs.app/volume-hud/privacy")!)
            Text("·")
            Link("Terms", destination: URL(string: "https://zmlabs.app/volume-hud/terms")!)
            Text("·")
            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
        }
        .font(.caption)
        .foregroundStyle(.secondary.opacity(0.5))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private func refreshAccessibilityStatus() {
        let trusted = MediaKeyMonitor.shared.hasAccessibilityPermission()
        accessibilityGranted = trusted
        if trusted {
            _ = MediaKeyMonitor.shared.start()
        }
    }
}

struct AccessibilityPermissionBanner: View {
    let onRequest: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.orange)

            VStack(alignment: .leading, spacing: 6) {
                Text("Accessibility Permission Needed")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Enable access so BetterOSD can listen for media keys.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Open Settings") {
                onRequest()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            content
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.controlBackgroundColor))
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

struct SettingsRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            content
        }
        .font(.body)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 16)
    }
}

#Preview {
    SettingsView()
}
