//
//  SettingsView.swift
//  BetterOSD
//
//  Created by yu on 2025/9/23.
//

import AppKit
import Combine
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(AppStorageKeys.hudStyle) private var hudStyle: HUDStyle = .modern
    @AppStorage(AppStorageKeys.launchAtLogin) private var launchAtLogin: Bool = false
    @AppStorage(AppStorageKeys.showInMenuBar) private var showInMenuBar: Bool = true
    @AppStorage(AppStorageKeys.liquidGlassEnable) private var liquidGlassEnable: Bool = true
    @AppStorage(AppStorageKeys.bottomOffset) private var bottomOffset: Double = 120
    @AppStorage(AppStorageKeys.glassVariant) private var glassVariant: Int = 0

    @State private var volumeState: VolumeState = .init()
    @State private var accessibilityGranted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(24)

            if !accessibilityGranted {
                AccessibilityPermissionBanner {
                    MediaKeyMonitor.shared.requestAccessibilityPermission()
                    MediaKeyMonitor.shared.startAccessibilityPolling()
                    refreshAccessibilityStatus()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            VStack(spacing: 24) {
                // Appearance Section
                SettingsSection(title: NSLocalizedString("Appearance", comment: "Appearance")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(HUDStyle.allCases) { style in
                                HUDStyleCard(
                                    style: style,
                                    isSelected: hudStyle == style,
                                    onSelect: {
                                        hudStyle = style
                                    }
                                ) {
                                    previewForStyle(style)
                                }
                            }
                        }
                        .frame(height: 200)
                        .padding(8)
                    }
                }

                // General Section
                SettingsSection(title: NSLocalizedString("General", comment: "General")) {
                    Group {
                        HStack {
                            Text("Launch at Login")
                                .font(.body)
                                .foregroundStyle(.primary)

                            Spacer()

                            Toggle("Launch at Login", isOn: $launchAtLogin)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .controlSize(.small)
                                .onChange(of: launchAtLogin) { _, newValue in
                                    setLaunchAtLogin(enabled: newValue)
                                }
                        }
                        HStack {
                            Text("Show in Menu Bar")
                                .font(.body)
                                .foregroundStyle(.primary)

                            Spacer()

                            Toggle("Show in Menu Bar", isOn: $showInMenuBar)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .controlSize(.small)
                                .onChange(of: showInMenuBar) { _, newValue in
                                    if let delegate = NSApplication.shared.delegate as? AppDelegate {
                                        delegate.updateMenuBarVisibility(visible: newValue)
                                    }
                                }
                        }
                        HStack {
                            Text("Liquid Glass Enable")
                                .font(.body)
                                .foregroundStyle(.primary)

                            Spacer()

                            Toggle("Liquid Glass Enable", isOn: $liquidGlassEnable)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .controlSize(.small)
                                .onChange(of: liquidGlassEnable) { _, _ in
                                    HUDPreviewManager.shared.isPreviewActive = true
                                    HUDPreviewManager.shared.isPreviewActive = false
                                }
                        }

                        HStack {
                            Text("Bottom Offset")
                                .font(.body)
                                .foregroundStyle(.primary)

                            Spacer()

                            Slider(value: $bottomOffset, in: 50 ... 220, onEditingChanged: { editing in
                                HUDPreviewManager.shared.isPreviewActive = editing
                            })
                            .frame(width: 150)
                            .onChange(of: bottomOffset) { _, newValue in
                                HUDPreviewManager.shared.bottomOffset = newValue
                            }
                        }

                        if liquidGlassEnable {
                            HStack {
                                Text("Glass Variant")
                                    .font(.body)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Picker("Glass Variant", selection: $glassVariant) {
                                    ForEach([0, 1, 3, 9, 11, 12], id: \.self) { value in
                                        Text("\(value)")
                                            .tag(value)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.automatic)
                                .onChange(of: glassVariant) { _, _ in
                                    HUDPreviewManager.shared.isPreviewActive = true
                                    HUDPreviewManager.shared.isPreviewActive = false
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Divider()

            // Footer
            HStack {
                HStack(spacing: 12) {
                    Link("Privacy", destination: URL(string: "https://zmlabs.app/volume-hud/privacy")!)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .underline()
                    Text("•")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("Terms", destination: URL(string: "https://zmlabs.app/volume-hud/terms")!)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .underline()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text("BetterOSD is an")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Link("open-source", destination: URL(string: "https://github.com/zmlabs/better-osd")!)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .underline()
                        Text("application")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 580)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            volumeState = VolumeMonitor.shared.currentVolumeState
            refreshAccessibilityStatus()
        }
        .onReceive(VolumeMonitor.shared.volumeChangePublisher.receive(on: RunLoop.main)) {
            volumeState = $0
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAccessibilityStatus()
        }
    }

    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }

    private func refreshAccessibilityStatus() {
        let trusted = MediaKeyMonitor.shared.hasAccessibilityPermission()
        accessibilityGranted = trusted

        if trusted {
            _ = MediaKeyMonitor.shared.start()
        }
    }

    @ViewBuilder
    private func previewForStyle(_ style: HUDStyle) -> some View {
        switch style {
        case .classic:
            ClassicVolumeHUDView(
                volumeState: volumeState
            )
        case .modern:
            ModernVolumeHUDView(
                volumeState: volumeState
            )
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content
            }
        }
    }
}

struct HUDStyleCard<PreviewContent: View>: View {
    let style: HUDStyle
    let isSelected: Bool
    let onSelect: () -> Void
    let preview: PreviewContent

    init(
        style: HUDStyle,
        isSelected: Bool,
        onSelect: @escaping () -> Void,
        @ViewBuilder preview: () -> PreviewContent
    ) {
        self.style = style
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.preview = preview()
    }

    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
                .padding()
                .overlay {
                    preview
                        .scaleEffect(0.7)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color.clear,
                            lineWidth: 2
                        )
                }

            Text(style.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
        .frame(width: 220)
        .onTapGesture {
            onSelect()
        }
    }
}

#Preview {
    SettingsView()
}
