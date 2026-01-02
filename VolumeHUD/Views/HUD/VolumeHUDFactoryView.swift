//
//  VolumeHUDFactoryView.swift
//  VolumeHUD
//
//  Created by yu on 2025/9/23.
//

@preconcurrency import Combine
import SwiftUI

/// A SwiftUI view that automatically switches between different HUD styles based on user settings
struct VolumeHUDFactoryView: View {
    @AppStorage(AppStorageKeys.hudStyle) private var hudStyle: HUDStyle = .modern

    @State private var volumeState: VolumeState = .init()
    @State private var cancellable: AnyCancellable?

    init() {
        let initialVolumeState = VolumeMonitor.shared.currentVolumeState
        _volumeState = State(initialValue: initialVolumeState)
    }

    var body: some View {
        ZStack {
            switch hudStyle {
            case .classic:
                ClassicVolumeHUDView(volumeState: volumeState)
            case .modern:
                ModernVolumeHUDView(volumeState: volumeState)
            }
        }
        .frame(width: 280, height: 200)
        .onAppear {
            cancellable = VolumeMonitor.shared.volumeChangePublisher
                .receive(on: RunLoop.main)
                .sink {
                    volumeState = $0
                }
        }
        .onDisappear {
            cancellable?.cancel()
        }
    }
}
