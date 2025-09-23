//
//  SettingsView.swift
//  VolumeHUD
//
//  Created by yu on 2025/9/23.
//

import Combine
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(AppStorageKeys.hudStyle) private var hudStyle: HUDStyle = .modern
    @AppStorage(AppStorageKeys.launchAtLogin) private var launchAtLogin: Bool = false

    @State var volumeState: VolumeState = VolumeMonitor.shared.currentVolumeState
    @State var cancellabel: AnyCancellable?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(24)

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
                        .padding(8)
                    }
                }

                // General Section
                SettingsSection(title: NSLocalizedString("General", comment: "General")) {
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
                        Text("VolumeHUD is an")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Link("open-source", destination: URL(string: "https://github.com/zmlabs/volume-hud")!)
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
        .frame(width: 580, height: 520)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled

            cancellabel = VolumeMonitor.shared.volumeChangePublisher
                .receive(on: RunLoop.main)
                .sink {
                    volumeState = $0
                }
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
                .overlay {
                    preview
                        .scaleEffect(0.7)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
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
