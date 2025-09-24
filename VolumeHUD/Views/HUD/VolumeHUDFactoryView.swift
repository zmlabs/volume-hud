//
//  VolumeHUDFactoryView.swift
//  VolumeHUD
//
//  Created by yu on 2025/9/23.
//

import Combine
import SwiftUI

/// A SwiftUI view that automatically switches between different HUD styles based on user settings
struct VolumeHUDFactoryView: View {
    @AppStorage(AppStorageKeys.hudStyle) private var hudStyle: HUDStyle = .modern

    @State var volumeState: VolumeState = .init()
    @State var cancellabel: AnyCancellable?

    init() {
        let initialVolumeState = VolumeMonitor.shared.currentVolumeState
        _volumeState = State(initialValue: initialVolumeState)
    }

    var body: some View {
        HStack {
            switch hudStyle {
            case .classic:
                ClassicVolumeHUDView(volumeState: volumeState)
            case .modern:
                ModernVolumeHUDView(volumeState: volumeState)
            }
        }
        .frame(width: 280, height: 200)
        .onAppear {
            cancellabel = VolumeMonitor.shared.volumeChangePublisher
                .receive(on: RunLoop.main)
                .sink {
                    volumeState = $0
                }
        }
    }
}
